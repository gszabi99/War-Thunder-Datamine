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

// Convert HSV colour specification to RGB intensities.
// H in [0, 360], S V R G B in [0,1]
[generic]
def hsv2rgb(hsv : float3)
  var i : int
  var f, p, q, t : float
  var rgb = float3(0.0)

  if hsv.y == 0.0
    rgb.x = hsv.z
    rgb.y = hsv.z
    rgb.z = hsv.z
  else
    var h = hsv
    if h.x == 360.0
      h.x = 0.0
    h.x /= 60.0

    i = int(h.x)
    f = h.x - float(i)
    p = h.z * (1.0 - h.y)
    q = h.z * (1.0 - (h.y * f))
    t = h.z * (1.0 - (h.y * (1.0 - f)))
    if i == 0
      rgb.x = h.z
      rgb.y = t
      rgb.z = p
    elif i == 1
      rgb.x = q
      rgb.y = h.z
      rgb.z = p
    elif i == 2
      rgb.x = p
      rgb.y = h.z
      rgb.z = t
    elif i == 3
      rgb.x = p
      rgb.y = q
      rgb.z = h.z
    elif i == 4
      rgb.x = t
      rgb.y = p
      rgb.z = h.z
    elif i == 5
      rgb.x = h.z
      rgb.y = p
      rgb.z = q
  return rgb