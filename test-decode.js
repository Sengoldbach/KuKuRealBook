const fs = require('fs')

const html = fs.readFileSync('15 11-好不容易.html', 'utf8')

// 1. 提取 irealb:// URL
const match = html.match(/href="(irealb:\/\/[^"]+)"/)
if (!match) { console.log('找不到 irealb:// URL'); process.exit(1) }

// 2. URL decode
const raw = decodeURIComponent(match[1].replace('irealb://', ''))
console.log('=== 字段分割 ===')
const parts = raw.split('=')
parts.forEach((p, i) => console.log(`[${i}] ${p.slice(0, 80)}${p.length > 80 ? '...' : ''}`))

// 3. 解密函数
function decode(s) {
  let resellult = ''
  for (let i = 0; i < s.length; i += 50) {
    const chunk = s.slice(i, i + 50)
    result += chunk.length === 50 ? chunk.slice(25) + chunk.slice(0, 25) : chunk
  }
  return result
}

// 4. 解密和弦字符串（最长的那个字段）
const chordField = parts.reduce((a, b) => b.length > a.length ? b : a)
const decoded = decode(chordField)
console.log('\n=== 解密后和弦字符串（前500字符）===')
console.log(decoded.slice(0, 500))
console.log('\n=== 全文 ===')
console.log(decoded)
