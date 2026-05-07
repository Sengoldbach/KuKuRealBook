# iReal Pro 文件格式规范

> 基于 pianosnake/ireal-reader 源码 + 多首歌曲实测（Autumn Leaves、好不容易、TestIreal 系列、Happy Birthday）验证。

---

## 1. 文件结构

`.ireal` 文件是 HTML，包含一个 `irealb://` 超链接：

```html
<a href="irealb://...">Song Title</a>
```

---

## 2. URL 字段解析

URL decode 后按 `/=+/`（一个或多个等号）切割，过滤空字符串。  
识别 `music` 字段：含有前缀 `1r34LbKcu7` 的那个字段。

| parts 数量 | 字段顺序 |
|-----------|---------|
| 7 | title, composer, style, key, music, bpm, repeats |
| 8 (music 在 [4]) | title, composer, style, key, music, compStyle, bpm, repeats |
| 8 (music 在 [5]) | title, composer, style, key, transpose, music, bpm, repeats |
| 9 | title, composer, style, key, transpose, music, compStyle, bpm, repeats |

---

## 3. 解密算法

**第一步**：从 music 字段去掉前缀 `1r34LbKcu7`，剩余部分为加密数据。

**第二步**：对加密数据进行分块解密（`obfusc50`）。  
算法为对称操作（加密=解密），每 50 字符一块做特定位置的镜像交换：

```js
function obfusc50(s) {
  const a = s.split('')
  // 第一组：位置 0-4 与 49-45 互换
  for (let i = 0; i < 5; i++) {
    [a[i], a[49 - i]] = [a[49 - i], a[i]]
  }
  // 第二组：位置 10-23 与 39-26 互换
  for (let i = 10; i < 24; i++) {
    [a[i], a[49 - i]] = [a[49 - i], a[i]]
  }
  return a.join('')
}

function unscramble(s) {
  let r = '', rest = s
  while (rest.length > 50) {
    const chunk = rest.slice(0, 50)
    rest = rest.slice(50)
    r += rest.length < 2 ? chunk : obfusc50(chunk)
  }
  return r + rest
}

function decodeMusic(musicField) {
  const PREFIX = '1r34LbKcu7'
  return unscramble(musicField.slice(musicField.indexOf(PREFIX) + PREFIX.length))
}
```

> **注意**：未交换的位置（5-9、24-25、40-44）保持不变。解密结果是完美还原，无损。

---

## 4. 解密后 DSL 格式

### 4.1 基本概念

iReal Pro **不是真正的 measure-based 格式**，而是一个平铺的 token 流。  
小节线是流中的标记，"小节"只是视觉约定。每个 token 产生 0 个或若干个视觉 cell。

### 4.2 Token 完整规则（按优先级）

解析器从左到右扫描，按以下顺序匹配：

| 优先级 | Token | 类型 | cells | 含义 |
|--------|-------|------|-------|------|
| 1 | `XyQ` | space | 3 | 3格空白 |
| 2 | `LZ` | lz | 1 + barline | 1格空白 + 右侧单小节线 |
| 3 | `\|` | barline | 0 | 普通小节线 |
| 4 | `[` | barline | 0 | 双纵线（段落开始）|
| 5 | `]` | barline | 0 | 双纵线（段落结束）|
| 6 | `{` | barline | 0 | 反复开始线 |
| 7 | `}` | barline | 0 | 反复结束线 |
| 8 | `Z` | barline | 0 | 终止线 |
| 9 | ` `（空格）| space | 1 | 1格空白 |
| 10 | `T\d+` | timesig | 0 | 拍号（T44=4/4, T34=3/4, T68=6/8）|
| 11 | `*X` | mark | 0 | 段落标记（\*A \*B \*i \*v 等）|
| 12 | `<...>` | annotation | 0 | 注释/歌词（iReal 的 annotation 功能即歌词系统）|
| 13 | `Kcl` | — | 2 | 展开为：单小节线 + 1格空白 + 1格`/` |
| 14 | `r` | chord | 1 | 重复前两小节（显示 `//`）|
| 15 | `x` | chord | 1 | 重复前一小节（显示 `%`）|
| 16 | `Y+` | layout | 0 | 纵向偏移（Y=1行, YY=2行, YYY=3行）|
| 17 | `p` | chord | 1 | 暂停斜线（显示 `/`）|
| 18 | `n` | chord | 1 | No Chord（显示 `N.C.`）|
| 19 | `N\d` | mark | 0 | 反复括号（N1=第一括, N2=第二括）|
| 20 | `Q` | mark | 0 | Coda 标记 |
| 21 | `S` | mark | 0 | Segno 标记 |
| 22 | `U` | mark | 0 | 播放器结尾标记 |
| 23 | `f` | mark | 0 | Fermata（无限延长符 𝄐）|
| 24 | `,` | sep | 0 | 和弦分隔符（纯语法，无视觉效果）|
| 25 | `l` | size | 0 | 全局切换为 large（廓形）字体，持续到下一次重置 |
| 26 | `s`（不在 `su` 前）| size | 0 | 全局切换为 small（瘦型）字体 |
| 27 | 和弦 regex | chord | 1 | 和弦符号（见下）|
| — | 其他字符 | unknown | 0 | 加密块边界的注释溢出碎片，忽略 |

#### `Kcl` 展开说明

`Kcl` 不是单一 token，等价于：
```
| (小节线)  +  · (1格空白)  +  / (1格暂停)
```
即：左侧小节线 + 空格 + 斜线占位，共 2 个视觉 cell。

#### `l` / `s` 说明

- **全局状态切换**，不是每个和弦的属性
- 影响其后所有和弦的显示，直到遇到另一个 `l`/`s` 才重置
- `,`（逗号）与 `l`/`s` 无关，仅作和弦分隔符使用
- `l` 从和弦 quality regex 中排除，始终到达此优先级
- `s` 只在**不跟 `u`** 时才识别为 size（`su` 是 `sus` 的一部分）

#### `<...>` 说明

iReal Pro 的 annotation 功能即其歌词系统，无独立 lyric token。  
解密后 `<>` 之外出现的裸字符（如中文）是加密块边界处的注释溢出，不是解密错误。

### 4.3 和弦符号

**格式：`[A-GW][quality][/bass]`**

```
regex：/[A-GW][\+\-\^\dhob#suadt]*(\/[A-G][#b]?)?/
```

> `l` 已从 quality 字符集移除，防止被和弦 regex 消费。

- 根音：`A-G`（`W` = **不可见的根音占位符**，只显示 `/bass` 部分，根音本身不渲染）
- 升降号：`b`/`#` 跟在根音后，表示升降根音（如 `Eb^7` = E♭∆7，`F#7` = F#7）
- 分数和弦：`/[A-G][#b]?`（如 `C-7/G`）

| 写法 | 含义 |
|------|------|
| `-7` | minor 7 |
| `-` | minor |
| `^7` 或 `^` | major 7 |
| `7` | dominant 7 |
| `7b9` | dom7♭9 |
| `h7` 或 `h` | half-dim (ø7) |
| `o7` 或 `o` | diminished |
| `sus` / `sus4` | sus4 |
| `6` | major 6 |
| `-6` | minor 6 |
| `69` | 6/9 |
| `add9` | add9 |
| `+` | augmented |

### 4.4 小节线类型

| Token | barlineType | 视觉 |
|-------|-------------|------|
| `\|` | single | 单竖线 |
| `[` / `]` | double | 双竖线 |
| `{` | rep-open | 反复开始（\|:）|
| `}` | rep-close | 反复结束（:\|）|
| `Z` | final | 终止线 |
| `LZ`（Z 部分）| single | 单竖线（在 LZ cell 右侧）|

所有 0-cell 小节线 token 均存入 `pendingBarlineLeft`，在下一个有 cell 的 token 的第一个 cell 左侧渲染。  
`LZ` 自带右侧小节线；若其前已有 pending 左侧线，则自身右侧线不再重复渲染（防止双线）。  
`LZ|` 不是三字符原子 token，解析为 `LZ` + `|` 两个独立 token。

### 4.5 拍号解析

`T44` → 上 `4` 下 `4`（4/4拍）  
解析时按字符索引取 `raw[1]` 和 `raw[2]`，而非 `match(/\d+/g)`（后者对 `T44` 会返回 `['44']` 导致显示错误）。

---

## 5. 解析流程

```js
const html   = fs.readFileSync('song.ireal', 'utf8')
const url    = html.match(/href="(irealb:\/\/[^"]+)"/)[1]
const body   = decodeURIComponent(url.replace(/^irealb:\/\//, ''))
const songs  = body.split('===')           // 多首歌以 === 分隔
songs.forEach(song => {
  const parts      = song.split(/=+/).filter(x => x !== '')
  const musicField = parts.find(p => p.includes('1r34LbKcu7'))
  const dsl        = decodeMusic(musicField)   // 解密后的 token 流字符串
  // → 按上述优先级规则从左到右解析 dsl
})
```

---

## 6. 暂未确认

- `Y` 的实际像素偏移量（相对单位已知，具体像素未对照）

## 7. 暂不实现的特性

- Segno / DC al Coda / DS al Fine 跳转展开
- 多声部
