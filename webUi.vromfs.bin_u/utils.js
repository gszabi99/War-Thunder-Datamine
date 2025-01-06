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

// IE support
if (!Array.indexOf) {
  Array.prototype.indexOf = function(obj) {
    for (var i=0; i<this.length; i++) {
      if (this[i]==obj)
         return i;
    }
    return -1;
  }
}
