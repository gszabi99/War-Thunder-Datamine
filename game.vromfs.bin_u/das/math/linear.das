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

[generic]
def distance_sq_to_line(point, a, dir) : float
  let t = dot(point - a, dir)
  let pt = a + dir * float3(t)
  return distance_sq(point, pt)

def is_2d_lines_crossed(startL1, endL1, startL2, endL2 : float2) : bool
  let den = (endL2.y - startL2.y) * (endL1.x - startL1.x) - (endL2.x - startL2.x) * (endL1.y - startL1.y)
  if den == 0.0
    return false
  let ua = ((endL2.x - startL2.x) * (startL1.y - startL2.y) - (endL2.y - startL2.y) * (startL1.x - startL2.x)) / den
  let ub = ((endL1.x - startL1.x) * (startL1.y - startL2.y) - (endL1.y - startL1.y) * (startL1.x - startL2.x)) / den
  return ua >= 0.0 && ua <= 1.0 && ub >= 0.0 && ub <= 1.0


//https ://en.wikipedia.org/wiki/Quickhull
def convex_hull(source : array<float2>) : array<float2>
  if length(source) <= 3
    return <- clone_to_move(source)

  var maxX = source[0].x
  var maxXIdx = 0
  var minX = source[0].x
  var minXIdx = 0
  for p, idx in source, iter_range(source)
    if maxX < p.x
      maxX = p.x
      maxXIdx = idx
    if minX > p.x
      minX = p.x
      minXIdx = idx

  var list : array<float2>
  push(list, source[maxXIdx])
  if minXIdx == maxXIdx
    return <- list
  push(list, source[minXIdx])
  var outside := source
  if minXIdx < maxXIdx
    maxXIdx--
  erase(outside, minXIdx)
  erase(outside, maxXIdx)

  while length(outside) > 0
    var i = 0
    while i < length(list)
      if !extend_hull(list, outside, i)
        i++
  return <- list


def private signed_point_to_line_distance(p, from, to : float2) : float
  if from.x == to.x
    if from.y == to.y
      return .0
    return from.x - p.x
  let a = from.y - to.y
  let b = to.x - from.x
  let c = from.x * to.y - to.x * from.y
  return (a * p.x + b * p.y + c) / sqrt(a * a + b * b)


def private test_point_in_2d_polygon(p : float2; polygon; dir : float = 1.0) : float
  for from, idx in polygon, iter_range(polygon)
    let to = polygon[(idx + 1) % length(polygon)]
    let relation = (from.x - p.x) * (to.y - p.y) - (from.y - p.y) * (to.x - p.x)
    if relation * dir >= 0.0
      return relation == 0.0 ? .0 : -1.0
  return 1.0


def private extend_hull(var hull : array<float2>; var outside : array<float2>; from : int) : bool
  let to = (from + 1) % length(hull)
  var maxP = 0
  var maxDst = -1.0
  for idx in iter_range(outside)
    let dst = signed_point_to_line_distance(outside[idx], hull[from], hull[to])
    if dst > maxDst
      maxDst = dst
      maxP = idx
  if maxDst > .0
    var newOutside : array<float2>
    let polygon = [[float2[3] hull[from]; outside[maxP]; hull[to]]]
    for p in outside
      if test_point_in_2d_polygon(p, polygon) < 0.0
        push(newOutside, p)
    push(hull, outside[maxP], to)
    outside := newOutside
  return maxDst > .0


