const express      = require('express')
const cookieParser = require('cookie-parser')
const path         = require('path')

const app = express()

app.use(express.json())
app.use(cookieParser())

app.use('/api/auth',  require('./routes/auth'))
app.use('/api/songs', require('./routes/songs'))
app.use('/api/users', require('./routes/users'))

app.use(express.static(path.join(__dirname, '..', 'public')))

// 所有未匹配路由返回前端页面（单页应用风格）
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, '..', 'public', 'index.html'))
})

const PORT = process.env.PORT || 3000
app.listen(PORT, () => console.log(`Server running on http://localhost:${PORT}`))
