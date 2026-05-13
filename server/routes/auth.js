const router  = require('express').Router()
const bcrypt  = require('bcryptjs')
const jwt     = require('jsonwebtoken')
const db      = require('../db')
const { SECRET } = require('../middleware/auth')

router.post('/register', async (req, res) => {
  const { username, email, password } = req.body
  if (!username || !email || !password)
    return res.status(400).json({ error: '请填写所有字段' })
  if (password.length < 6)
    return res.status(400).json({ error: '密码至少6位' })

  try {
    const hash = await bcrypt.hash(password, 10)
    const stmt = db.prepare(
      'INSERT INTO users (username, email, password_hash) VALUES (?, ?, ?)'
    )
    const result = stmt.run(username, email, hash)
    const token  = jwt.sign({ id: result.lastInsertRowid, username }, SECRET, { expiresIn: '30d' })
    res.cookie('token', token, { httpOnly: true, maxAge: 30 * 24 * 3600 * 1000 })
    res.json({ username })
  } catch (e) {
    if (e.message.includes('UNIQUE'))
      return res.status(409).json({ error: '用户名或邮箱已被使用' })
    res.status(500).json({ error: '服务器错误' })
  }
})

router.post('/login', async (req, res) => {
  const { email, password } = req.body
  if (!email || !password)
    return res.status(400).json({ error: '请填写邮箱和密码' })

  const user = db.prepare('SELECT * FROM users WHERE email = ?').get(email)
  if (!user) return res.status(401).json({ error: '邮箱或密码错误' })

  const ok = await bcrypt.compare(password, user.password_hash)
  if (!ok) return res.status(401).json({ error: '邮箱或密码错误' })

  const token = jwt.sign({ id: user.id, username: user.username }, SECRET, { expiresIn: '30d' })
  res.cookie('token', token, { httpOnly: true, maxAge: 30 * 24 * 3600 * 1000 })
  res.json({ username: user.username })
})

router.post('/logout', (req, res) => {
  res.clearCookie('token')
  res.json({ ok: true })
})

router.get('/me', (req, res) => {
  const token = req.cookies?.token
  if (!token) return res.json({ user: null })
  try {
    const payload = jwt.verify(token, SECRET)
    res.json({ user: { id: payload.id, username: payload.username } })
  } catch {
    res.json({ user: null })
  }
})

module.exports = router
