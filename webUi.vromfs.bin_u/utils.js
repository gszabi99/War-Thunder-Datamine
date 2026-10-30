function lerp(a, b, k) {
  return a*(1.0-k) + b*k
}


function clamp(x, lo, hi) {
  return Math.max(lo, Math.min(x, hi))
}


function approach(from, to, dt, viscosity) {
  if (viscosity < 1e-9)
    return to;
  else
    return from + (1.0 - Math.exp(-dt / viscosity)) * (to - from);
}


function rgb_to_hex(r, g, b) {
  var rr = r.toString(16)
  var gg = g.toString(16)
  var bb = b.toString(16)
  var str = "#" +
    (rr.length == 1 ? "0" + rr : rr) +
    (gg.length == 1 ? "0" + gg : gg) +
    (bb.length == 1 ? "0" + bb : bb);
  return str
}

const dagui_team_colors = {
  teamBlueColor: '#527AFF',
  teamRedColor: '#FF5A52'
}

const html_escapes = {
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;'
}

const dagui_markup_re = /<color=[^>]*>|<\/color>|[&<>]/gi

function dagui_color_tag_to_html(tag) {
  if (tag.startsWith('</'))
    return '</span>'
  const [, name] = /@(\w+)/.exec(tag) || []
  const color = dagui_team_colors[name]
  return color ? `<span style="color:${color}">` : '<span>'
}

const dagui_markup_to_html = (text) => (text || '')
  .replace(dagui_markup_re, (match) => html_escapes[match] || dagui_color_tag_to_html(match))

if (!Array.indexOf) {
  Array.prototype.indexOf = function(obj) {
    for (var i=0; i<this.length; i++) {
      if (this[i]==obj)
         return i;
    }
    return -1;
  }
}
