def rotate(vec : float2; sina : float; cosa : float)
  return float2(vec.x * cosa - vec.y * sina, vec.x * sina + vec.y * cosa)


def inv_x(v : float2) : float2
  return float2(-v.x, v.y)


def inv_y(v : float2) : float2
  return float2(v.x, -v.y)


def inv_x(var verts : float2[])
  for v in verts
    v = float2(-v.x, v.y)
  return <- verts


def inv_y(var verts : float2[])
  for v in verts
    v = float2(v.x, -v.y)
  return <- verts


def inv_x(var verts : array<float2>)
  for v in verts
    v = float2(-v.x, v.y)
  return <- verts


def inv_y(var verts : array<float2>)
  for v in verts
    v = float2(v.x, -v.y)
  return <- verts


def rotate(var verts : float2[]; sina : float; cosa : float)
  for v in verts
    v = float2(v.x * cosa - v.y * sina, v.x * sina + v.y * cosa)
  return <- verts


def scale(var verts : float2[]; scale : float2)
  for v in verts
    v *= scale
  return <- verts


def translate(var verts : float2[]; pos : float2)
  for v in verts
    v += pos
  return <- verts

def rotate(var verts : array<float2>; sina : float; cosa : float)
  for v in verts
    v = float2(v.x * cosa - v.y * sina, v.x * sina + v.y * cosa)
  return <- verts


def scale(var verts : array<float2>; scale : float2)
  for v in verts
    v *= scale
  return <- verts


def translate(var verts : array<float2>; pos : float2)
  for v in verts
    v += pos
  return <- verts