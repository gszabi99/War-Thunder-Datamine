module random shared
require math
require %dasGameLibs.math.base
require DagorRandom

def rnd_point_on_disk(radius: float): float2
  return rnd_point_on_ring(0f, radius)

def rnd_point_on_ring(radius: float2): float2
  return rnd_point_on_ring(radius.x, radius.y)

def rnd_point_on_ring(radius_from, radius_to: float): float2
  if radius_from > radius_to
    return float2()

  let rndX = gfrnd()
  let rndY = gfrnd()
  let rndAngle = gfrnd()

  var radius: float
  if rndX * (radius_to - radius_from) + radius_from < rndY * (radius_to + radius_from)
    radius =         rndX * (radius_to - radius_from) + radius_from
  else
    radius = (1.0 - rndX) * (radius_to - radius_from) + radius_from

  var s, c : float
  sincos(2f * PI * rndAngle, s, c)
  return float2(radius * c, radius * s)