module linear shared
require math
require %dasGameLibs.math.base

[generic]
def closest_pt_on_seg(point, a, b)
  let abVec = b - a
  let abLen = length(abVec)
  let dir = abVec * rcp(abLen)
  let t = dot(point - a, dir)
  return a + dir * clamp(t, 0.0, abLen);

[generic]
def distance_sq_to_seg(point, a, b) : float
  let pt = closest_pt_on_seg(point, a, b)
  return length_sq(point - pt)

[generic]
def distance_to_line(point, a, dir) : float
  let t = dot(point - a, dir)
  let pt = a + dir * float3(t)
  return distance(point, pt)

def is_2d_lines_crossed(startL1, endL1, startL2, endL2 : float2) : bool
  let den = (endL2.y - startL2.y)* (endL1.x - startL1.x) - (endL2.x - startL2.x) * (endL1.y - startL1.y)
  if den == 0.0
    return false
  let ua = ((endL2.x - startL2.x)* (startL1.y - startL2.y) - (endL2.y - startL2.y) * (startL1.x - startL2.x)) / den
  let ub = ((endL1.x - startL1.x)* (startL1.y - startL2.y) - (endL1.y - startL1.y) * (startL1.x - startL2.x)) / den
  return ua >= 0.0 && ua <=1.0 && ub >= 0.0 && ub <= 1.0
