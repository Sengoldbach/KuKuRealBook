// ── iReal Chart Renderer ──────────────────────────────────────
// Self-contained module extracted from ireal_editor.html.
// Usage: renderChart(containerEl, irealUrl, { scale: 0.5 })

;(function(global) {

// ── Constants ──────────────────────────────────────────────────
const MUSIC_PREFIX = '1r34LbKcu7'

// ── Crypto / Encoding ──────────────────────────────────────────
function obfusc50(s) {
  const a = s.split('')
  for (let i = 0; i < 5; i++)   [a[i], a[49-i]] = [a[49-i], a[i]]
  for (let i = 10; i < 24; i++) [a[i], a[49-i]] = [a[49-i], a[i]]
  return a.join('')
}
function unscramble(s) {
  let r = '', rest = s
  while (rest.length > 50) {
    const chunk = rest.slice(0, 50); rest = rest.slice(50)
    r += rest.length < 2 ? chunk : obfusc50(chunk)
  }
  return r + rest
}
function decodeMusic(field) {
  const idx = field.indexOf(MUSIC_PREFIX)
  if (idx === -1) return field
  return unscramble(field.slice(idx + MUSIC_PREFIX.length))
}

// ── URL Parser ─────────────────────────────────────────────────
function parseIrealUrl(rawUrl) {
  const body  = rawUrl.replace(/^irealb:\/\//, '')
  const songs = body.split('===')
  const parts = songs[0].split(/=+/).filter(x => x !== '')
  const mIdx  = parts.findIndex(p => p.includes(MUSIC_PREFIX))
  if (mIdx < 0) return null
  return {
    title:    decodeURIComponent(parts[0] || 'Untitled'),
    composer: decodeURIComponent(parts[1] || ''),
    style:    decodeURIComponent(mIdx >= 3 ? parts[mIdx-2] || '' : ''),
    key:      decodeURIComponent(mIdx >= 2 ? parts[mIdx-1] || 'C' : 'C'),
    tokens:   tokenize(decodeMusic(parts[mIdx])),
  }
}

// ── Tokenizer ──────────────────────────────────────────────────
function tokenize(s) {
  const tokens = []
  let i = 0
  while (i < s.length) {
    if (s.slice(i,i+3) === 'XyQ') {
      tokens.push({raw:' ', type:'space', cells:1}, {raw:' ', type:'space', cells:1}, {raw:' ', type:'space', cells:1})
      i+=3; continue
    }
    if (s.slice(i,i+2) === 'LZ') {
      tokens.push({raw:' ', type:'space', cells:1}, {raw:'|', type:'barline', cells:0, barline:true, barlineType:'single'})
      i+=2; continue
    }
    if (s[i]==='|')  { tokens.push({raw:'|', type:'barline', cells:0, barline:true, barlineType:'single'});  i++; continue }
    if (s[i]==='[')  { tokens.push({raw:'[', type:'barline', cells:0, barline:true, barlineType:'double'});  i++; continue }
    if (s[i]===']')  { tokens.push({raw:']', type:'barline', cells:0, barline:true, barlineType:'double'});  i++; continue }
    if (s[i]==='{')  { tokens.push({raw:'{', type:'barline', cells:0, barline:true, barlineType:'rep-open'}); i++; continue }
    if (s[i]==='}')  { tokens.push({raw:'}', type:'barline', cells:0, barline:true, barlineType:'rep-close'}); i++; continue }
    if (s[i]==='Z')  { tokens.push({raw:'Z', type:'barline', cells:0, barline:true, barlineType:'final'});   i++; continue }
    if (s[i]===' ')  { tokens.push({raw:' ', type:'space', cells:1, barline:false}); i++; continue }
    if (s[i]==='T' && /\d/.test(s[i+1]||'')) {
      let j=i+1; while(j<s.length&&/\d/.test(s[j]))j++
      tokens.push({raw:s.slice(i,j), type:'timesig', cells:0}); i=j; continue
    }
    if (s[i]==='*' && i+1<s.length) { tokens.push({raw:'*'+s[i+1], type:'mark', cells:0}); i+=2; continue }
    if (s[i]==='<') {
      const e=s.indexOf('>',i); if(e>i){ tokens.push({raw:s.slice(i,e+1), type:'annotation', cells:0}); i=e+1; continue }
    }
    if (s.slice(i,i+3)==='Kcl') {
      tokens.push({raw:'|', type:'barline', cells:0, barline:true, barlineType:'single'}, {raw:' ', type:'space', cells:1}, {raw:'p', type:'chord', cells:1, extra:'/'})
      i+=3; continue
    }
    if (s[i]==='r') { tokens.push({raw:'r', type:'chord', cells:1, extra:'//'}); i++; continue }
    if (s[i]==='x') { tokens.push({raw:'x', type:'chord', cells:1, extra:'%'});  i++; continue }
    if (s[i]==='Y') { let j=i; while(j<s.length&&s[j]==='Y')j++; tokens.push({raw:s.slice(i,j), type:'layout', cells:0}); i=j; continue }
    if (s[i]==='p') { tokens.push({raw:'p', type:'chord', cells:1, extra:'/'}); i++; continue }
    if (s[i]==='n') { tokens.push({raw:'n', type:'chord', cells:1, extra:'N.C.'}); i++; continue }
    if (s[i]==='N'&&/\d/.test(s[i+1]||'')) { tokens.push({raw:'N'+s[i+1], type:'mark', cells:0}); i+=2; continue }
    if (s[i]==='Q') { tokens.push({raw:'Q', type:'mark', cells:0, extra:'Coda'});  i++; continue }
    if (s[i]==='S') { tokens.push({raw:'S', type:'mark', cells:0, extra:'Segno'}); i++; continue }
    if (s[i]==='U') { tokens.push({raw:'U', type:'mark', cells:0, extra:'End'});   i++; continue }
    if (s[i]==='f') { tokens.push({raw:'f', type:'mark', cells:0, extra:'𝄐'});   i++; continue }
    if (s[i]===',') { tokens.push({raw:',', type:'sep', cells:0}); i++; continue }
    if (s[i]==='l') { tokens.push({raw:'l', type:'size', cells:0, extra:'normal'}); i++; continue }
    if (s[i]==='s' && s[i+1]!=='u') { tokens.push({raw:'s', type:'size', cells:0, extra:'small'}); i++; continue }
    const cm = s.slice(i).match(/^[A-GW][\+\-\^\dhob#suadt]*(\/[A-G][#b]?)?/)
    if (cm) { tokens.push({raw:cm[0], type:'chord', cells:1}); i+=cm[0].length; continue }
    i++
  }
  return tokens
}

// ── Render helpers ─────────────────────────────────────────────
function esc(s) { return (s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;') }
function monoW(fs) { return fs * 0.603 }

const REP_W = 7, FIN_W = 4

function repBarlineSVG(type) {
  const H=52, r=1.25, cy1=17, cy2=35
  const col='var(--rc-bl-r)', cold='var(--rc-bl-d)'
  const st=`position:absolute;left:0;top:0;overflow:visible;pointer-events:none`
  if (type==='rep-open')  return `<svg width="${REP_W}" height="${H}" style="${st}"><rect x="0" y="0" width="1.5" height="${H}" fill="${col}"/><rect x="2.75" y="0" width="0.75" height="${H}" fill="${col}"/><circle cx="5.5" cy="${cy1}" r="${r}" fill="${col}"/><circle cx="5.5" cy="${cy2}" r="${r}" fill="${col}"/></svg>`
  if (type==='rep-close') return `<svg width="${REP_W}" height="${H}" style="${st}"><circle cx="1" cy="${cy1}" r="${r}" fill="${col}"/><circle cx="1" cy="${cy2}" r="${r}" fill="${col}"/><rect x="3" y="0" width="0.75" height="${H}" fill="${col}"/><rect x="5" y="0" width="1.5" height="${H}" fill="${col}"/></svg>`
  if (type==='final')     return `<svg width="${FIN_W}" height="${H}" style="${st}"><rect x="0" y="0" width="0.75" height="${H}" fill="${cold}"/><rect x="2.25" y="0" width="1.75" height="${H}" fill="${cold}"/></svg>`
  return ''
}

function repeatSVG(type) {
  const H=40, sw=2.5, r=3.5
  const base=`<svg width="40" height="${H}" style="display:block;overflow:visible">`
  if (type==='%') return base+`<circle cx="8" cy="9" r="${r}" fill="currentColor"/><line x1="7" y1="${H-4}" x2="31" y2="4" stroke="currentColor" stroke-width="${sw}" stroke-linecap="round"/><circle cx="30" cy="${H-9}" r="${r}" fill="currentColor"/></svg>`
  return base+`<circle cx="5" cy="9" r="${r-.5}" fill="currentColor"/><line x1="4" y1="${H-4}" x2="17" y2="4" stroke="currentColor" stroke-width="${sw}" stroke-linecap="round"/><line x1="19" y1="${H-4}" x2="32" y2="4" stroke="currentColor" stroke-width="${sw}" stroke-linecap="round"/><circle cx="34" cy="${H-9}" r="${r-.5}" fill="currentColor"/></svg>`
}

function parseRoot(raw) {
  const m = raw.match(/^([A-G][#b]?)(.*?)(?:\/(([A-G][#b]?)))?$/)
  if (!m) return null
  return { root: m[1], quality: m[2], bass: m[4] || null }
}

function renderChordSVG(raw) {
  if (raw.startsWith('W')) {
    return `<svg class="rc-csym" height="42"><text x="2" y="34" class="rc-csym-b">${esc(raw.slice(1))}</text></svg>`
  }
  const p = parseRoot(raw)
  if (!p) return `<svg class="rc-csym" height="42"><text x="2" y="34" class="rc-csym-r">${esc(raw)}</text></svg>`
  const letter = p.root[0], acc = p.root.slice(1)
  const accD  = acc==='b' ? '♭' : acc==='#' ? '♯' : ''
  const qualD = esc(p.quality.replace(/\^/g,'Δ').replace(/h/g,'ø').replace(/o/g,'°'))
  const bassD = p.bass ? esc('/'+p.bass) : ''
  const RF=36, AF=16, QF=18, BF=16
  const rx=4, ry=34, mx=rx+monoW(RF)+1, ay=ry-RF*0.58, by=ry+QF
  const svgH = bassD ? by+4 : ry+10
  let s=`<text x="${rx}" y="${ry}" class="rc-csym-r">${letter}</text>`
  if (accD)  s+=`<text x="${mx.toFixed(1)}" y="${ay.toFixed(1)}" class="rc-csym-a">${accD}</text>`
  if (qualD) s+=`<text x="${mx.toFixed(1)}" y="${ry}"            class="rc-csym-q">${qualD}</text>`
  if (bassD) s+=`<text x="${mx.toFixed(1)}" y="${by}"            class="rc-csym-b">${bassD}</text>`
  return `<svg class="rc-csym" height="${svgH}" overflow="visible">${s}</svg>`
}

// ── CSS injection (once) ───────────────────────────────────────
function injectCSS() {
  if (document.getElementById('rc-styles')) return
  const s = document.createElement('style')
  s.id = 'rc-styles'
  s.textContent = `
.rc-wrap { --rc-bl-s:#668; --rc-bl-d:#bbb; --rc-bl-r:#e53; --rc-chord:#7fffb2;
           --rc-space:#1e3040; --rc-repeat:#94d5ff; --rc-nc:#ffd700; --rc-pause:#888;
           --rc-mark-bg:#c0392b; --rc-mark-txt:#fff; --rc-volta:#e53;
           --rc-ts:#ffd700; --rc-annot:#87ceeb; --rc-cell-bd:#1e3040; }
.rc-wrap.rc-light { --rc-bl-s:#555; --rc-bl-d:#222; --rc-bl-r:#c0392b; --rc-chord:#111;
           --rc-space:#ccc; --rc-repeat:#2a5a8a; --rc-nc:#8a6600; --rc-pause:#999;
           --rc-mark-bg:#c0392b; --rc-mark-txt:#fff; --rc-volta:#c0392b;
           --rc-ts:#8a6600; --rc-annot:#2a6a9a; --rc-cell-bd:rgba(0,0,0,.07); }
.rc-grid { display:grid; grid-template-columns:repeat(16,1fr); row-gap:22px; padding-top:16px; }
.rc-cell { height:52px; border:1px solid var(--rc-cell-bd); display:flex; align-items:center;
           justify-content:center; font-size:16px; position:relative; min-width:0; overflow:visible; }
.rc-cell.rc-chord  { color:var(--rc-chord); font-weight:bold; justify-content:flex-start;
                      align-items:flex-start; padding-left:4px; padding-top:4px; overflow:visible; z-index:2; }
.rc-cell.rc-space  { color:var(--rc-space); }
.rc-cell.rc-nc     { color:var(--rc-nc); font-style:italic; font-size:20px; }
.rc-cell.rc-pause  { color:var(--rc-pause); font-size:18px; }
.rc-cell.rc-repeat { color:var(--rc-repeat); width:calc(200% + 2px); z-index:3; }
.rc-cell.rc-repeat2{ color:var(--rc-repeat); width:calc(200% + 2px); z-index:3; }
.rc-cell.rc-sz-sm svg.rc-csym { transform:scaleX(0.62); transform-origin:left center; }
.rc-cell .rc-bl    { position:absolute; left:0; top:0; bottom:0; z-index:4; pointer-events:none; }
.rc-cell .rc-br    { position:absolute; left:100%; top:0; bottom:0; z-index:4; pointer-events:none; }
.rc-bl.rc-single   { border-left:2px solid var(--rc-bl-s); left:-2px; }
.rc-br.rc-single   { border-left:2px solid var(--rc-bl-s); }
.rc-bl.rc-double   { border-left:4px double var(--rc-bl-d); left:-2px; }
.rc-br.rc-double   { border-left:4px double var(--rc-bl-d); }
.rc-cell .rc-mark  { position:absolute; bottom:100%; left:0; margin-bottom:2px;
                      font-size:8px; font-weight:bold; background:var(--rc-mark-bg);
                      color:var(--rc-mark-txt); padding:1px 4px; border-radius:2px; white-space:nowrap; z-index:5; }
.rc-cell .rc-volta { position:absolute; bottom:100%; left:0; margin-bottom:2px;
                      font-size:10px; font-weight:bold; color:var(--rc-volta);
                      border-left:2px solid currentColor; border-top:2px solid currentColor;
                      padding:0 4px; white-space:nowrap; z-index:5; }
.rc-cell .rc-ts    { position:absolute; right:calc(100% + 4px); top:50%; transform:translateY(-50%);
                      font-size:16px; font-weight:bold; color:var(--rc-ts); line-height:1; text-align:center; }
.rc-cell .rc-ts span { display:block; line-height:1.5; }
.rc-cell .rc-ts span:first-child { border-bottom:1.5px solid currentColor; }
.rc-cell .rc-annot { position:absolute; top:100%; left:0; margin-top:3px;
                      font-size:14px; color:var(--rc-annot); white-space:nowrap; z-index:5; }
svg.rc-csym { overflow:visible; display:block; pointer-events:none; }
svg.rc-csym text { font-family:monospace; fill:currentColor; }
.rc-csym-r { font-size:36px; font-weight:bold; }
.rc-csym-a { font-size:16px; font-weight:bold; }
.rc-csym-q { font-size:18px; }
.rc-csym-b { font-size:16px; font-weight:bold; }
`
  document.head.appendChild(s)
}

// ── Main render function ───────────────────────────────────────
// container : DOM element to render into
// irealUrl  : irealb:// string
// opts      : { scale: 0.5, light: false }
function renderChart(container, irealUrl, opts) {
  injectCSS()
  const { scale = 1, light = false } = opts || {}

  const songData = parseIrealUrl(irealUrl)
  if (!songData) { container.textContent = '无效的谱面数据'; return }

  const tokens = songData.tokens
  let pendingBarlineLeft = null, pendingMark = null, pendingTimeSig = null
  let pendingVolta = null, pendingAnnot = null, currentSize = 'normal'
  const parts = []

  function findLastCell() {
    for (let i = parts.length-1; i >= 0; i--)
      if (parts[i].type === 'cell') return parts[i]
    return null
  }

  const TS_MAP = {
    '22':['2','2'],'24':['2','4'],'34':['3','4'],'44':['4','4'],
    '54':['5','4'],'64':['6','4'],'74':['7','4'],
    '38':['3','8'],'68':['6','8'],'98':['9','8'],'128':['12','8']
  }

  tokens.forEach(t => {
    if (t.type === 'sep' || t.type === 'unknown') return
    if (t.type === 'size')   { currentSize = t.extra; return }
    if (t.type === 'layout') {
      const h = t.raw.length * 22
      parts.push({type:'layout', html:`<div style="grid-column:1/-1;height:${h}px"></div>`})
      return
    }
    if (t.type === 'timesig')    { pendingTimeSig = t.raw.slice(1); return }
    if (t.type === 'annotation') { pendingAnnot = t.raw.slice(1,-1); return }
    if (t.type === 'mark') {
      if (t.raw.startsWith('*')) pendingMark = t.raw.slice(1)
      else if (t.raw.startsWith('N')) pendingVolta = t.raw.slice(1)
      return
    }
    if (t.barline && t.cells === 0) {
      const prev = findLastCell()
      if (prev) {
        const bt = t.barlineType
        if (bt==='single') prev.brHtml = '<span class="rc-br rc-single"></span>'
        else if (bt==='double') prev.brHtml = '<span class="rc-br rc-double"></span>'
      }
      pendingBarlineLeft = t.barlineType; return
    }

    for (let c = 0; c < t.cells; c++) {
      const isFirst = c === 0
      let cls = 'rc-cell', inner = '', blHtml = '', brHtml = ''
      let markHtml = '', voltaHtml = '', tsHtml = '', annotHtml = ''

      if (t.type === 'chord') {
        if      (t.extra === '%')    { cls += ' rc-repeat';  inner = repeatSVG('%') }
        else if (t.extra === '//')   { cls += ' rc-repeat2'; inner = repeatSVG('//') }
        else if (t.extra === '/')    { cls += ' rc-pause';   inner = '/' }
        else if (t.extra === 'N.C.') { cls += ' rc-nc';      inner = 'N.C.' }
        else                         { cls += ' rc-chord';   inner = renderChordSVG(t.raw) }
      } else {
        cls += ' rc-space'
      }
      if (currentSize === 'small' && t.type === 'chord') cls += ' rc-sz-sm'

      if (isFirst && pendingBarlineLeft) {
        const btype = pendingBarlineLeft
        const rightAligned = btype === 'rep-close' || btype === 'final'
        const w = btype === 'final' ? FIN_W : REP_W
        const bstyle = rightAligned ? ` style="left:${-w}px"` : ''
        blHtml = `<span class="rc-bl rc-${btype}"${bstyle}>${repBarlineSVG(btype)}</span>`
        pendingBarlineLeft = null
      }
      if (isFirst && pendingMark) {
        markHtml = `<span class="rc-mark">${esc(pendingMark)}</span>`; pendingMark = null
      }
      if (isFirst && pendingVolta) {
        voltaHtml = `<span class="rc-volta">${esc(pendingVolta)}.</span>`; pendingVolta = null
      }
      if (isFirst && pendingTimeSig) {
        const mapped = TS_MAP[pendingTimeSig]
        const top = mapped ? mapped[0] : pendingTimeSig.slice(0,-1)||'?'
        const bot = mapped ? mapped[1] : pendingTimeSig.slice(-1)||'?'
        tsHtml = `<span class="rc-ts"><span>${top}</span><span>${bot}</span></span>`
        pendingTimeSig = null
      }
      if (isFirst && pendingAnnot) {
        const am = pendingAnnot.match(/^\*(\d{2})(.*)/)
        const shift = am ? Math.min(parseInt(am[1]), 60) : 0
        const atext = am ? am[2] : pendingAnnot
        const astyle = shift ? ` style="transform:translateY(-${Math.round(shift*1.2)}px)"` : ''
        annotHtml = `<span class="rc-annot"${astyle}>${esc(atext).replace(/\/\//g,'<br>')}</span>`
        pendingAnnot = null
      }

      parts.push({type:'cell', cls, inner, blHtml, brHtml, markHtml, voltaHtml, tsHtml, annotHtml})
    }
  })

  let gridHtml = ''
  for (const p of parts) {
    if (p.type === 'layout') gridHtml += p.html
    else gridHtml += `<div class="${p.cls}">${p.blHtml}${p.brHtml}${p.markHtml}${p.voltaHtml}${p.tsHtml}${p.annotHtml}${p.inner}</div>`
  }

  const transformStyle = scale !== 1
    ? `style="transform:scale(${scale});transform-origin:top left;width:${(1/scale*100).toFixed(1)}%;"`
    : ''
  container.innerHTML = `<div class="rc-wrap${light?' rc-light':''}" ${transformStyle}><div class="rc-grid">${gridHtml}</div></div>`
}

// ── Exports ────────────────────────────────────────────────────
global.renderChart   = renderChart
global.parseIrealUrl = parseIrealUrl

})(window)
