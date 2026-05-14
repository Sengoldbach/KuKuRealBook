// ── iReal Chart Renderer ──────────────────────────────────────
// Usage: renderChart(containerEl, irealUrl, { scale: 0.5 })

;(function(global) {

const _k = [49,114,51,52,76,98,75,99,117,55].map(c=>String.fromCharCode(c)).join('')

function _p(s){const a=s.split('');for(let i=0;i<5;i++){const t=a[i];a[i]=a[49-i];a[49-i]=t}for(let i=10;i<24;i++){const t=a[i];a[i]=a[49-i];a[49-i]=t}return a.join('')}
function _q(s){let r='',x=s;while(x.length>50){const c=x.slice(0,50);x=x.slice(50);r+=x.length<2?c:_p(c)}return r+x}
function _r(f){const i=f.indexOf(_k);return i<0?f:_q(f.slice(i+_k.length))}

// ── URL Parser ────────────────────────────────────────────────
function parseIrealUrl(rawUrl) {
  const body  = rawUrl.replace(/^irealb:\/\//, '')
  const parts = body.split('===')[0].split(/=+/).filter(x => x !== '')
  const mIdx  = parts.findIndex(p => p.includes(_k))
  if (mIdx < 0) return null
  return {
    title:    decodeURIComponent(parts[0] || 'Untitled'),
    composer: decodeURIComponent(parts[1] || ''),
    style:    decodeURIComponent(mIdx >= 3 ? parts[mIdx-2] || '' : ''),
    key:      decodeURIComponent(mIdx >= 2 ? parts[mIdx-1] || 'C' : 'C'),
    dsl:      _r(decodeURIComponent(parts[mIdx])),
  }
}

// ── Tokenizer (from ireal_decoder.html) ───────────────────────
function tokenize(s) {
  const tokens = []
  let i = 0
  while (i < s.length) {
    if (s.slice(i,i+3) === 'XyQ') { tokens.push({raw:'XyQ', type:'space',   cells:3, barline:false}); i+=3; continue }
    if (s.slice(i,i+2) === 'LZ')  { tokens.push({raw:'LZ',  type:'lz',      cells:1, barline:true,  barlineType:'single'}); i+=2; continue }
    if (s[i]==='|') { tokens.push({raw:'|', type:'barline', cells:0, barline:true,  barlineType:'single'});   i++; continue }
    if (s[i]==='[') { tokens.push({raw:'[', type:'barline', cells:0, barline:true,  barlineType:'double'});   i++; continue }
    if (s[i]===']') { tokens.push({raw:']', type:'barline', cells:0, barline:true,  barlineType:'double'});   i++; continue }
    if (s[i]==='{') { tokens.push({raw:'{', type:'barline', cells:0, barline:true,  barlineType:'rep-open'}); i++; continue }
    if (s[i]==='}') { tokens.push({raw:'}', type:'barline', cells:0, barline:true,  barlineType:'rep-close'}); i++; continue }
    if (s[i]==='Z') { tokens.push({raw:'Z', type:'barline', cells:0, barline:true,  barlineType:'final'});    i++; continue }
    if (s[i]===' ') { tokens.push({raw:' ', type:'space',   cells:1, barline:false}); i++; continue }
    if (s[i]==='T' && /\d/.test(s[i+1]||'')) {
      let j=i+1; while(j<s.length&&/\d/.test(s[j]))j++
      tokens.push({raw:s.slice(i,j), type:'timesig', cells:0, barline:false}); i=j; continue
    }
    if (s[i]==='*' && i+1<s.length) { tokens.push({raw:'*'+s[i+1], type:'mark', cells:0, barline:false}); i+=2; continue }
    if (s[i]==='<') {
      const e=s.indexOf('>',i); if(e>i){ tokens.push({raw:s.slice(i,e+1), type:'annotation', cells:0, barline:false}); i=e+1; continue }
    }
    if (s.slice(i,i+3)==='Kcl') {
      tokens.push({raw:'|',   type:'barline', cells:0, barline:true,  barlineType:'single'})
      tokens.push({raw:' ',   type:'space',   cells:1, barline:false})
      tokens.push({raw:'Kcl', type:'chord',   cells:1, barline:false, extra:'/'})
      i+=3; continue
    }
    if (s[i]==='r') { tokens.push({raw:'r', type:'chord', cells:1, barline:false, extra:'//'}); i++; continue }
    if (s[i]==='x') { tokens.push({raw:'x', type:'chord', cells:1, barline:false, extra:'%'});  i++; continue }
    if (s[i]==='Y') { let j=i; while(j<s.length&&s[j]==='Y')j++; tokens.push({raw:s.slice(i,j), type:'layout', cells:0, barline:false}); i=j; continue }
    if (s[i]==='p') { tokens.push({raw:'p', type:'chord', cells:1, barline:false, extra:'/'}); i++; continue }
    if (s[i]==='n') { tokens.push({raw:'n', type:'chord', cells:1, barline:false, extra:'N.C.'}); i++; continue }
    if (s[i]==='N'&&/\d/.test(s[i+1]||'')) { tokens.push({raw:'N'+s[i+1], type:'mark', cells:0, barline:false}); i+=2; continue }
    if (s[i]==='Q') { tokens.push({raw:'Q', type:'mark', cells:0, barline:false, extra:'Coda'});  i++; continue }
    if (s[i]==='S') { tokens.push({raw:'S', type:'mark', cells:0, barline:false, extra:'Segno'}); i++; continue }
    if (s[i]==='U') { tokens.push({raw:'U', type:'mark', cells:0, barline:false, extra:'End'});   i++; continue }
    if (s[i]==='f') { tokens.push({raw:'f', type:'mark', cells:0, barline:false, extra:'𝄐'});   i++; continue }
    if (s[i]===',') { tokens.push({raw:',', type:'sep',  cells:0, barline:false}); i++; continue }
    if (s[i]==='l') { tokens.push({raw:'l', type:'size', cells:0, barline:false, extra:'large'}); i++; continue }
    if (s[i]==='s' && s[i+1]!=='u') { tokens.push({raw:'s', type:'size', cells:0, barline:false, extra:'small'}); i++; continue }
    const cm = s.slice(i).match(/^[A-GW][\+\-\^\dhob#suadt]*(\/[A-G][#b]?)?/)
    if (cm) { tokens.push({raw:cm[0], type:'chord', cells:1, barline:false}); i+=cm[0].length; continue }
    tokens.push({raw:s[i], type:'unknown', cells:0, barline:false}); i++
  }
  const merged = []
  for (const t of tokens) {
    if (t.type==='unknown' && merged.length && merged[merged.length-1].type==='unknown')
      merged[merged.length-1].raw += t.raw
    else merged.push(t)
  }
  return merged
}

// ── CSS injection (once) ──────────────────────────────────────
function injectCSS() {
  if (document.getElementById('rc-styles')) return
  const s = document.createElement('style')
  s.id = 'rc-styles'
  s.textContent = `
.rc-wrap { font-family: monospace; }
.rc-grid { display:grid; grid-template-columns:repeat(16,1fr); padding-top:14px; }
.rc-cell {
  height:40px; border:1px solid #2a3a44; display:flex;
  align-items:center; justify-content:center; font-size:12px;
  position:relative; background:#0d1a22; min-width:0; overflow:visible;
}
.rc-cell.rc-chord  { color:#7fffb2; font-weight:bold; background:rgba(127,255,178,.07);
                      justify-content:flex-start; align-items:flex-start;
                      padding-left:3px; padding-top:3px; font-size:11px; }
.rc-cell.rc-space  { color:#333; }
.rc-cell.rc-nc     { color:#ffd700; font-style:italic; font-size:9px; }
.rc-cell.rc-pause  { color:#aaa; font-size:18px; }
.rc-cell.rc-repeat { color:#94d5ff; font-size:14px; }
.rc-cell.rc-repeat2{ color:#94d5ff; font-size:11px; letter-spacing:-1px; }
.rc-cell .rc-bl { position:absolute; left:0;   top:0; bottom:0; z-index:4; pointer-events:none; }
.rc-cell .rc-br { position:absolute; right:0;  top:0; bottom:0; z-index:4; pointer-events:none; }
.rc-bl.rc-single   { border-left:  2px solid #668; }
.rc-br.rc-single   { border-right: 2px solid #668; }
.rc-bl.rc-double   { border-left:  4px double #bbb; }
.rc-br.rc-double   { border-right: 4px double #bbb; }
.rc-bl.rc-rep-open  { border-left:3px solid #4af; box-shadow:3px 0 0 #4af; }
.rc-bl.rc-rep-close { border-left:5px solid #4af; box-shadow:3px 0 0 #4af; }
.rc-bl.rc-final     { border-left:5px solid #bbb; }
.rc-cell .rc-mark {
  position:absolute; bottom:100%; left:0; margin-bottom:2px;
  font-size:7px; font-weight:bold; background:#c0392b;
  color:#fff; padding:1px 3px; border-radius:2px; white-space:nowrap; z-index:5;
}
.rc-cell .rc-volta {
  position:absolute; bottom:100%; left:14px; margin-bottom:2px;
  font-size:7px; font-weight:bold; color:#87ceeb;
  border-bottom:2px solid #87ceeb; padding:0 2px; white-space:nowrap; z-index:5;
}
.rc-cell .rc-ts {
  position:absolute; right:calc(100% + 2px); top:50%; transform:translateY(-50%);
  font-size:10px; font-weight:bold; color:#ffd700;
  line-height:1; text-align:center; display:flex; flex-direction:column; z-index:5;
}
.rc-cell .rc-ts span { display:block; line-height:1.2; }
`
  document.head.appendChild(s)
}

// ── Main render function ──────────────────────────────────────
function renderChart(container, irealUrl, opts) {
  injectCSS()
  const { scale = 1 } = opts || {}

  const parsed = parseIrealUrl(irealUrl)
  if (!parsed) { container.textContent = '无效的谱面数据'; return }

  const tokens = tokenize(parsed.dsl)
  const esc = s => (s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')

  let pendingBarlineLeft = null, pendingMark = null
  let pendingTimeSig = null, pendingVolta = null

  let gridHtml = ''

  tokens.forEach(t => {
    if (t.type === 'size' || t.type === 'sep' || t.type === 'unknown' || t.type === 'annotation') return
    if (t.type === 'layout') {
      const h = t.raw.length * 18
      gridHtml += `<div style="grid-column:1/-1;height:${h}px"></div>`
      return
    }
    if (t.type === 'timesig')             { pendingTimeSig = t.raw.slice(1); return }
    if (t.type === 'mark' && t.raw.startsWith('*')) { pendingMark = t.raw.slice(1); return }
    if (t.type === 'mark' && t.raw.startsWith('N')) { pendingVolta = t.raw.slice(1); return }
    if (t.type === 'mark')                           { return }

    if (t.barline && t.cells === 0) { pendingBarlineLeft = t.barlineType; return }

    for (let c = 0; c < t.cells; c++) {
      const isFirst = c === 0
      let cls = 'rc-cell', inner = ''

      if (t.type === 'chord') {
        if      (t.extra === '%')    { cls += ' rc-repeat';  inner = '%' }
        else if (t.extra === '//')   { cls += ' rc-repeat2'; inner = '//' }
        else if (t.extra === '/')    { cls += ' rc-pause';   inner = '/' }
        else if (t.extra === 'N.C.') { cls += ' rc-nc';      inner = 'N.C.' }
        else {
          cls += ' rc-chord'
          const display = t.raw.startsWith('W') ? t.raw.slice(1) : t.raw
          inner = esc(display)
        }
      } else {
        cls += ' rc-space'
      }

      let blHtml = ''
      if (isFirst && pendingBarlineLeft) {
        blHtml = `<span class="rc-bl rc-${pendingBarlineLeft}"></span>`
        pendingBarlineLeft = null
      }
      let markHtml = ''
      if (isFirst && pendingMark) {
        markHtml = `<span class="rc-mark">${esc(pendingMark)}</span>`
        pendingMark = null
      }
      let voltaHtml = ''
      if (isFirst && pendingVolta) {
        voltaHtml = `<span class="rc-volta">${esc(pendingVolta)}.</span>`
        pendingVolta = null
      }
      let tsHtml = ''
      if (isFirst && pendingTimeSig) {
        const top = pendingTimeSig[0] || '?'
        const bot = pendingTimeSig[1] || '?'
        tsHtml = `<span class="rc-ts"><span>${top}</span><span>${bot}</span></span>`
        pendingTimeSig = null
      }

      gridHtml += `<div class="${cls}">${blHtml}${markHtml}${voltaHtml}${tsHtml}${inner}</div>`
    }

    if (t.barline && t.cells > 0) pendingBarlineLeft = t.barlineType
  })

  const scaleStyle = scale !== 1
    ? `transform:scale(${scale});transform-origin:top left;width:${(100/scale).toFixed(1)}%`
    : ''

  container.innerHTML =
    `<div class="rc-wrap" style="${scaleStyle}"><div class="rc-grid">${gridHtml}</div></div>`
}

// ── Exports ───────────────────────────────────────────────────
global.renderChart   = renderChart
global.parseIrealUrl = parseIrealUrl

})(window)
