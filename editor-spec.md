# iReal Editor — 产品规格

## 概述

基于 `ireal_decoder.html` 的 token 流 + visual grid 基础，开发一个浏览器端的 iReal Pro 格式和弦谱编辑器。

**输入**：`.ireal` / `.html` 文件（irealb:// 格式），或从空白新建  
**输出**：导出为 `.html` 文件（含合法 irealb:// URL），可直接被 iReal Pro 导入

---

## 数据模型

沿用 decoder 的 **token 流**模型，不引入 measure 层：

```js
song = {
  title, composer, style, key, bpm,
  tokens: [ { raw, type, cells, barline, barlineType, extra }, ... ]
}
```

序列化（生成 irealb:// URL）：
```js
const dsl         = tokens.map(t => t.raw).join('')
const musicField  = '1r34LbKcu7' + unscramble(dsl)   // 加密=解密，同一函数
const url         = `irealb://${encodeURIComponent(buildUrl(song, musicField))}`
```

---

## 界面布局

```
┌─────────────────────────────────────────────────────┐
│  工具栏                                               │
│  [打开] [新建] [保存]  |  [和弦] [小节线] [标记] ...  │
├─────────────────────────────────────────────────────┤
│  曲目信息栏                                           │
│  Title: ___  Composer: ___  Key: C▼  Style: ___     │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Visual Grid（可编辑）                               │
│  每行 N 个 cell，小节线、标记、拍号均显示             │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## 功能模块

### 1. 文件 I/O

| 操作 | 行为 |
|------|------|
| 打开 | file input 读取 `.ireal`/`.html`，提取 irealb:// URL，解密并渲染 |
| 新建 | 创建空白 token 流（只有 `[`…`Z` 骨架），进入编辑模式 |
| 保存 | 序列化 token 流 → 加密 → 生成 irealb:// URL → 下载 `.html` 文件 |

---

### 2. 选区与焦点

- 点击 cell → 选中该 cell 对应的 token（高亮）
- 选中后显示上下文工具（改和弦、改小节线、加标记等）
- 支持 `←` `→` 键在 cell 间移动焦点
- 支持 `Shift+←/→` 多选

---

### 3. 和弦输入

选中 cell 后可直接键盘输入和弦，格式遵循 iReal DSL：

| 输入 | 含义 |
|------|------|
| `C` | C 大三 |
| `C-7` | Cm7 |
| `Bb^7` | B♭∆7 |
| `F#7b9` | F#7♭9 |
| `C-7/G` | Cm7/G（分数低音）|

**输入流程**：
1. 选中 cell，按任意字母键触发输入框（inline）
2. 实时预览，回车 / Tab 确认并移至下一 cell
3. `Esc` 取消

**特殊 cell 类型**（通过下拉或快捷键切换）：

| 类型 | token | 显示 |
|------|-------|------|
| 重复上一小节 | `x` | `%` |
| 重复前两小节 | `r` | `//` |
| 暂停斜线 | `p` | `/` |
| 无和弦 | `n` | `N.C.` |
| 空白 | ` ` | 空 |

---

### 4. 小节线

选中 cell 后，左/右侧小节线可独立切换：

| 类型 | token | 显示 |
|------|-------|------|
| 无 | — | — |
| 普通 | `\|` | 单竖线 |
| 双纵线 | `[` / `]` | 双竖线 |
| 反复开始 | `{` | `\|:` |
| 反复结束 | `}` | `:\|` |
| 终止线 | `Z` | 粗竖线 |

---

### 5. 段落标记（Rehearsal Marks）

在 cell 上方添加，存为 `*X` token（0 cell，挂在下一 cell 前）：

| 标记 | token |
|------|-------|
| A / B / C / D | `*A` `*B` `*C` `*D` |
| Intro | `*i` |
| Verse | `*v` |
| Chorus | (用 `*A` 惯例) |

---

### 6. 拍号

在任意位置插入 `T44` / `T34` / `T68` 等（0 cell），显示在左侧。  
支持选项：4/4、3/4、6/8、5/4、7/4。

---

### 7. 反复括号

`N1` / `N2` token（0 cell），在 cell 上方显示 `1.` / `2.` 方括号。  
通过工具栏按钮在选中 cell 前插入。

---

### 8. 注释 / Annotation

`<text>` token（0 cell），附加到下一 cell，显示为小字提示（D.C. al Coda、D.S. 等）。  
点击 cell 后通过弹窗输入文字。

---

### 9. 大小字体

`l` / `s` token（0 cell，全局状态），在选中位置插入，影响其后所有和弦的渲染尺寸。

---

### 10. 插入 / 删除

| 操作 | 行为 |
|------|------|
| `Insert` / 工具栏 | 在焦点前插入空白 cell（` ` token）|
| `Delete` / `Backspace` | 删除焦点 cell 对应的 token |
| 整行插入 | 在当前行末插入一行 `XyQ XyQ XyQ XyQ`（4 小节空白）|

---

### 11. 曲目信息

顶部栏内联编辑：
- **Title**、**Composer**：文本输入
- **Key**：下拉（C, Db, D … B，含 minor）
- **Style**：文本输入（Medium Swing、Bossa Nova 等）
- **BPM**：数字输入（可选）

---

### 12. 转调

全局转调：选择半音数（-6 ~ +6），对所有和弦根音 + 低音做枚举映射，更新对应 token 的 `raw`，Key 字段同步更新。

---

## 暂不实现

- DC al Coda / DS al Fine 播放跳转逻辑
- 多声部
- 音频播放
- `Y`（纵向偏移）的编辑 UI（解析展示，不允许手动插入）
- `W` 根音占位符的插入（解析展示，不允许手动插入）

---

## 技术方案

- 单 HTML 文件，无框架依赖，沿用 decoder 的结构
- token 流作为唯一 source of truth，所有编辑操作直接增删改 `tokens[]`
- 每次编辑后调用 `render()` 重绘 visual grid
- `render()` 完全复用 decoder 已有的渲染逻辑，仅在 cell 上叠加编辑交互层
