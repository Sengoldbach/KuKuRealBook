const router = require('express').Router()
const db     = require('../db')

// 用户主页：该用户发布的所有版本
router.get('/:username', (req, res) => {
  const user = db.prepare('SELECT id, username, created_at FROM users WHERE username = ?').get(req.params.username)
  if (!user) return res.status(404).json({ error: '用户不存在' })

  const versions = db.prepare(`
    SELECT
      v.id AS version_id, v.style, v.key_sig, v.created_at, v.updated_at,
      s.id AS song_id, s.title, s.composer,
      COUNT(l.user_id) AS likes
    FROM versions v
    JOIN songs s ON s.id = v.song_id
    LEFT JOIN likes l ON l.version_id = v.id
    WHERE v.user_id = ?
    GROUP BY v.id
    ORDER BY v.created_at DESC
  `).all(user.id)

  res.json({ user, versions })
})

module.exports = router
