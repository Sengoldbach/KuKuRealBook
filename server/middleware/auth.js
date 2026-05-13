const jwt = require('jsonwebtoken')

const SECRET = process.env.JWT_SECRET || 'dev-secret-change-in-production'

function requireAuth(req, res, next) {
  const token = req.cookies?.token
  if (!token) return res.status(401).json({ error: '请先登录' })
  try {
    req.user = jwt.verify(token, SECRET)
    next()
  } catch {
    res.status(401).json({ error: '登录已过期，请重新登录' })
  }
}

function optionalAuth(req, res, next) {
  const token = req.cookies?.token
  if (token) {
    try { req.user = jwt.verify(token, SECRET) } catch {}
  }
  next()
}

module.exports = { requireAuth, optionalAuth, SECRET }
