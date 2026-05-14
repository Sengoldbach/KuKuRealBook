const router = require('express').Router()
const db     = require('../db')
const { requireAuth, optionalAuth } = require('../middleware/auth')

// 获取谱子列表（首页），支持搜索
router.get('/', optionalAuth, (req, res) => {
  const { q, style, composer, sort = 'new', page = 1 } = req.query
  const limit  = 20
  const offset = (Number(page) - 1) * limit

  let where  = []
  let params = []

  if (q)        { where.push("LOWER(s.title) LIKE ?");    params.push(`%${q.toLowerCase()}%`) }
  if (composer) { where.push("LOWER(s.composer) LIKE ?"); params.push(`%${composer.toLowerCase()}%`) }
  if (style)    { where.push("LOWER(v.style) LIKE ?");    params.push(`%${style.toLowerCase()}%`) }

  const whereClause = where.length ? 'WHERE ' + where.join(' AND ') : ''
  const orderBy = sort === 'hot'
    ? 'total_likes DESC, s.created_at DESC'
    : 's.created_at DESC'

  const rows = db.prepare(`
    SELECT
      s.id, s.title, s.composer, s.created_at,
      COUNT(DISTINCT v.id)   AS version_count,
      COALESCE(SUM(lk.cnt), 0) AS total_likes
    FROM songs s
    LEFT JOIN versions v ON v.song_id = s.id
    LEFT JOIN (
      SELECT version_id, COUNT(*) AS cnt FROM likes GROUP BY version_id
    ) lk ON lk.version_id = v.id
    ${whereClause}
    GROUP BY s.id
    ORDER BY ${orderBy}
    LIMIT ? OFFSET ?
  `).all(...params, limit, offset)

  res.json(rows)
})

// 获取预览用的 ireal_url（仅服务器渲染需要，不在页面上直接显示）
router.get('/:songId/versions/:versionId/preview-url', (req, res) => {
  const version = db.prepare(
    'SELECT ireal_url FROM versions WHERE id = ? AND song_id = ?'
  ).get(req.params.versionId, req.params.songId)
  if (!version) return res.status(404).json({ error: '版本不存在' })
  res.json({ ireal_url: version.ireal_url })
})

// 下载某个版本（只需返回 HTML 文件，移至此处统一管理）
router.get('/:songId/versions/:versionId/download', (req, res) => {
  const version = db.prepare(
    'SELECT v.*, s.title, s.composer FROM versions v JOIN songs s ON s.id = v.song_id WHERE v.id = ? AND v.song_id = ?'
  ).get(req.params.versionId, req.params.songId)
  if (!version) return res.status(404).json({ error: '版本不存在' })
  const title    = (version.title||'').replace(/"/g, '&quot;')
  const url      = version.ireal_url.replace(/"/g, '&quot;')
  const filename = (version.title||'Untitled').replace(/[^\w\s-]/g, '').trim() + '.html'
  const html = `<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head><meta charset="UTF-8"><title>iReal Pro</title></head>
<body>
<h3><a href="${url}">${title}</a> - ${version.composer}</h3>
<br/>Shared via iReal Forum
</body>
</html>`
  res.setHeader('Content-Type', 'text/html; charset=utf-8')
  res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(filename)}"`)
  res.send(html)
})

// 获取单个帖子详情（含所有版本，不含 ireal_url）
router.get('/:id', optionalAuth, (req, res) => {
  const song = db.prepare('SELECT * FROM songs WHERE id = ?').get(req.params.id)
  if (!song) return res.status(404).json({ error: '帖子不存在' })

  const versions = db.prepare(`
    SELECT
      v.id, v.user_id, u.username, v.style, v.key_sig,
      v.created_at, v.updated_at,
      COUNT(l.user_id) AS likes
    FROM versions v
    JOIN users u ON u.id = v.user_id
    LEFT JOIN likes l ON l.version_id = v.id
    WHERE v.song_id = ?
    GROUP BY v.id
    ORDER BY likes DESC, v.created_at ASC
  `).all(song.id)

  const comments = db.prepare(`
    SELECT c.id, c.content, c.created_at, u.username
    FROM comments c JOIN users u ON u.id = c.user_id
    WHERE c.song_id = ?
    ORDER BY c.created_at ASC
  `).all(song.id)

  const myLikes = req.user
    ? db.prepare('SELECT version_id FROM likes WHERE user_id = ?').all(req.user.id).map(r => r.version_id)
    : []
  const isFavorited = req.user
    ? !!db.prepare('SELECT 1 FROM favorites WHERE song_id = ? AND user_id = ?').get(song.id, req.user.id)
    : false

  res.json({ song, versions, comments, myLikes, isFavorited })
})

// 发布谱子（新建或覆盖自己的版本）
router.post('/', requireAuth, (req, res) => {
  const { title, composer = '', style = '', key_sig = 'C', ireal_url, overwrite = false } = req.body
  if (!title || !ireal_url) return res.status(400).json({ error: '缺少必填字段' })
  if (title.length > 200)     return res.status(400).json({ error: '曲名过长（最多200字符）' })
  if (composer.length > 200)  return res.status(400).json({ error: '作曲者过长（最多200字符）' })
  if (style.length > 100)     return res.status(400).json({ error: '风格过长（最多100字符）' })
  if (ireal_url.length > 60000) return res.status(400).json({ error: '谱子数据过大' })

  // 找或创建 song 记录
  let song = db.prepare(
    'SELECT * FROM songs WHERE LOWER(title) = LOWER(?) AND LOWER(composer) = LOWER(?)'
  ).get(title, composer)

  if (!song) {
    const r = db.prepare('INSERT INTO songs (title, composer) VALUES (?, ?)').run(title, composer)
    song = db.prepare('SELECT * FROM songs WHERE id = ?').get(r.lastInsertRowid)
  }

  // 检查用户是否已有版本
  const existing = db.prepare(
    'SELECT * FROM versions WHERE song_id = ? AND user_id = ?'
  ).get(song.id, req.user.id)

  if (existing) {
    if (!overwrite) {
      return res.json({ conflict: true, song_id: song.id, version_id: existing.id })
    }
    db.prepare(
      "UPDATE versions SET style=?, key_sig=?, ireal_url=?, updated_at=datetime('now') WHERE id=?"
    ).run(style, key_sig, ireal_url, existing.id)
    return res.json({ song_id: song.id, version_id: existing.id, updated: true })
  }

  const r = db.prepare(
    'INSERT INTO versions (song_id, user_id, style, key_sig, ireal_url) VALUES (?,?,?,?,?)'
  ).run(song.id, req.user.id, style, key_sig, ireal_url)

  res.json({ song_id: song.id, version_id: r.lastInsertRowid, created: true })
})

// 点赞 / 取消点赞
router.post('/:songId/versions/:versionId/like', requireAuth, (req, res) => {
  const versionId = Number(req.params.versionId)
  const userId    = req.user.id
  const existing  = db.prepare('SELECT 1 FROM likes WHERE version_id=? AND user_id=?').get(versionId, userId)
  if (existing) {
    db.prepare('DELETE FROM likes WHERE version_id=? AND user_id=?').run(versionId, userId)
    res.json({ liked: false })
  } else {
    db.prepare('INSERT INTO likes (version_id, user_id) VALUES (?,?)').run(versionId, userId)
    res.json({ liked: true })
  }
})

// 收藏 / 取消收藏
router.post('/:id/favorite', requireAuth, (req, res) => {
  const songId = Number(req.params.id)
  const userId = req.user.id
  const existing = db.prepare('SELECT 1 FROM favorites WHERE song_id=? AND user_id=?').get(songId, userId)
  if (existing) {
    db.prepare('DELETE FROM favorites WHERE song_id=? AND user_id=?').run(songId, userId)
    res.json({ favorited: false })
  } else {
    db.prepare('INSERT INTO favorites (song_id, user_id) VALUES (?,?)').run(songId, userId)
    res.json({ favorited: true })
  }
})

// 删除自己的版本（若是最后一版则连 song 一起删）
router.delete('/:songId/versions/:versionId', requireAuth, (req, res) => {
  const version = db.prepare(
    'SELECT * FROM versions WHERE id = ? AND song_id = ?'
  ).get(req.params.versionId, req.params.songId)
  if (!version) return res.status(404).json({ error: '版本不存在' })
  if (version.user_id !== req.user.id) return res.status(403).json({ error: '无权删除' })

  db.prepare('DELETE FROM likes    WHERE version_id = ?').run(version.id)
  db.prepare('DELETE FROM versions WHERE id = ?').run(version.id)

  const remaining = db.prepare('SELECT COUNT(*) as n FROM versions WHERE song_id = ?').get(req.params.songId)
  if (remaining.n === 0) {
    db.prepare('DELETE FROM favorites WHERE song_id = ?').run(req.params.songId)
    db.prepare('DELETE FROM comments  WHERE song_id = ?').run(req.params.songId)
    db.prepare('DELETE FROM songs     WHERE id = ?').run(req.params.songId)
    return res.json({ deleted: true, songDeleted: true })
  }
  res.json({ deleted: true, songDeleted: false })
})

// 发评论
router.post('/:id/comments', requireAuth, (req, res) => {
  const { content } = req.body
  if (!content?.trim()) return res.status(400).json({ error: '评论不能为空' })
  if (content.length > 500) return res.status(400).json({ error: '评论过长（最多500字符）' })
  const r = db.prepare(
    'INSERT INTO comments (song_id, user_id, content) VALUES (?,?,?)'
  ).run(req.params.id, req.user.id, content.trim())
  res.json({ id: r.lastInsertRowid, content: content.trim(), username: req.user.username })
})

module.exports = router
