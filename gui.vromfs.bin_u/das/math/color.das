module color shared
require DagorRandom
require DagorMath

[generic]
def rnd_color(var seed : int&)
  let r1 = uint(_rnd(seed))
  let r2 = uint(_rnd(seed))
  let rgbValue = (r1 << 8u) | (r2 >> 8u)
  let forceBits = (0xC0 << (8u * (r2 % 3u))) | 0xFF000000
  return E3DCOLOR(rgbValue | forceBits)

[generic]
def rnd_color()
  var seed = grnd()
  return rnd_color(seed)
