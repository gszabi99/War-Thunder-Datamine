require DagorMath
require math

[hint(alwaysinline)]
def rotate(vec : float2; sina : float; cosa : float)
  return float2(vec.x * cosa - vec.y * sina, vec.x * sina + vec.y * cosa)


[hint(alwaysinline)]
def inv_x(v : float2) : float2
  return float2(-v.x, v.y)


[hint(alwaysinline)]
def inv_y(v : float2) : float2
  return float2(v.x, -v.y)


def inv_x(var verts : float2[] | array<float2>)
  for v in verts
    v = float2(-v.x, v.y)
  return <- verts


def inv_y(var verts : float2[] | array<float2>)
  for v in verts
    v = float2(v.x, -v.y)
  return <- verts


def rotate(var verts : float2[] | array<float2>; sina : float; cosa : float)
  for v in verts
    v = float2(v.x * cosa - v.y * sina, v.x * sina + v.y * cosa)
  return <- verts


def scale(var verts : float2[] | array<float2>; scale : float2)
  for v in verts
    v *= scale
  return <- verts


def translate(var verts : float2[] | array<float2>; pos : float2)
  for v in verts
    v += pos
  return <- verts


def flip(var verts : float2[] | array<float2>)
  for i in 0 .. verts.length() / 2
    swap(verts[verts.length() - 1 - i], verts[i])
  return <- verts


[hint(alwaysinline)]
def private safediv_point2(p1 : float2; p2 : float2)
  return float2(safediv(p1.x, p2.x), safediv(p1.y, p2.y))


def is_out_of_ellipse(pos : float2; center : float2; radius : float2)
  let offset = pos - center
  let scaled = safediv_point2(offset, radius)
  return dot(scaled, scaled) > 1.0


def trace_ray_to_ellipse(pos : float2; dir : float2; center : float2; radius : float2)
  let scaledPos = safediv_point2(pos - center, radius)
  let scaledDir = safediv_point2(dir, radius)

  let a = dot(scaledDir, scaledDir)
  let b = 2.0 * dot(scaledPos, scaledDir)
  let c = dot(scaledPos, scaledPos) - 1.0 // 1.0 is radius^2

  let discriminant = b * b - 4.0 * a * c
  if discriminant < 0.0
    return 1e10
  let t = (-b + safe_sqrt(discriminant)) / (2.0 * a)
  return t

def color_mult4(col : E3DCOLOR; transparency : float)
  let col4 = float4(Color4(col)) * transparency
  return E3DCOLOR(Color4(col4))
