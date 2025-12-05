module capzones_common shared

require math
require math.base

def is_pos_inside_capture_point(pos; margin_distance; transform; capzone__approximateRadius; sphere_zone__radius)
  let distanceSq = length_sq(transform[3] - pos)
  if capzone__approximateRadius >= 0.f
    return distanceSq < square(margin_distance + capzone__approximateRadius)
  if sphere_zone__radius > 0.0
    let zoneToPoint = pos - transform[3]
    if length_sq(zoneToPoint) < square(margin_distance)
      return true
    
    
    let reducedZoneToPoint = zoneToPoint - normalize(zoneToPoint) * margin_distance
    let scaledDistanceSq = length_sq(rotate(inverse(transform), reducedZoneToPoint))
    return scaledDistanceSq < square(sphere_zone__radius)
  let halfDiag = length(transform[0] + transform[2]) * 0.5
  return distanceSq < square(margin_distance + halfDiag)
