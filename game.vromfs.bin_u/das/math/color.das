module color shared
require DagorRandom
require DagorMath
require math

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

def lerp_color(c1, c2 : E3DCOLOR; t : float)
  return E3DCOLOR(uint4(lerp(float4(uint4(c1)), float4(uint4(c2)), float4(t))))