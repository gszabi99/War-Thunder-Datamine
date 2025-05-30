options indenting = 2
module easing shared
require math
require math.base

[generic]
def linear(p : float)
  return p


[generic]
def inQuad(p : float)
  return p * p


[generic]
def outQuad(p : float)
  return -(p * (p - 2.f))




[generic]
def inOutQuad(p : float)
  if (p < 0.5f)
    return 2.f * p * p
  else
    return (-2.f * p * p) + (4.f * p) - 1.f


[generic]
def inCubic(p : float)
  return p * p * p


[generic]
def outCubic(p : float)
  let f = (p - 1.f)
  return f * f * f + 1.f




[generic]
def inOutCubic(p : float)
  if (p < 0.5f)
    return 4.f * p * p * p
  else
    let f = ((2.f * p) - 2.f)
    return 0.5f * f * f * f + 1.f
 


[generic]
def inQuart(p : float)
  return p * p * p * p


[generic]
def outQuart(p : float)
  let f = (p - 1.f)
  return f * f * f * (1.f - p) + 1.f




[generic]
def inOutQuart(p : float)
  if (p < 0.5f)
    return 8.f * p * p * p * p
  else
    let f = (p - 1.f)
    return -8.f * f * f * f * f + 1.f







[generic]
def inQuintic(p : float)
  return p * p * p * p * p


[generic]
def outQuintic(p : float)
  let f = (p - 1.f)
  return f * f * f * f * f + 1.f




[generic]
def inOutQuintic(p : float)
  if (p < 0.5f)
    return 16.f * p * p * p * p * p
  else
    let f = ((2.f * p) - 2.f)
    return 0.5f * f * f * f * f * f + 1.f
  






[generic]
def inSine(p : float)
  return sin((p - 1.f) * TWOPI) + 1.f


[generic]
def outSine(p : float)
  return sin(p * TWOPI)


[generic]
def inOutSine(p : float)
  return 0.5f * (1.f - cos(p * PI))







[generic]
def inCirc(p : float)
  return 1.f - sqrt(1.f - (p * p))


[generic]
def outCirc(p : float)
  return sqrt((2.f - p) * p)




[generic]
def inOutCirc(p : float)
  if (p < 0.5f)
    return 0.5f * (1.f - sqrt(1.f - 4.f * (p * p)))
  else
    return 0.5f * (sqrt(-((2.f * p) - 3.f) * ((2.f * p) - 1.f)) + 1.f)







[generic]
def inExp(p : float)
  return (p == 0.f) ? p : pow(2.f, 10.f * (p - 1.f))


[generic]
def outExp(p : float)
  return (p == 1.f) ? p : 1.f - pow(2.f, -10.f * p)




[generic]
def inOutExp(p : float)
  if (p == 0.f || p == 1.f)
    return p

  if (p < 0.5f)
    return 0.5f * pow(2.f, (20.f * p) - 10.f)
  else
    return -0.5f * pow(2.f, (-20.f * p) + 10.f) + 1.f





[generic]
def inElastic(p : float)
  return sin(13.f * TWOPI * p) * pow(2.f, 10.f * (p - 1.f))


[generic]
def outElastic(p : float)
  return sin(-13.f * TWOPI * (p + 1.f)) * pow(2.f, -10.f * p) + 1.f




[generic]
def inOutElastic(p : float)
  if (p < 0.5f)
    return 0.5f * sin(13.f * TWOPI * (2.f * p)) * pow(2.f, 10.f * ((2.f * p) - 1.f))
  else
    return 0.5f * (sin(-13.f * TWOPI * ((2.f * p - 1.f) + 1.f)) * pow(2.f, -10.f * (2.f * p - 1.f)) + 2.f)





[generic]
def inBack(p : float)
  return p * p * p - p * sin(p * PI)


[generic]
def outBack(p : float)
  let f = (1.f - p)
  return 1.f - (f * f * f - f * sin(f * PI))





[generic]
def inOutBack(p : float)
  if (p < 0.5f)
    let f = 2.f * p
    return 0.5f * (f * f * f - f * sin(f * PI))
  else
    let f = (1.f - (2.f * p - 1.f))
    return 0.5f * (1.f - (f * f * f - f * sin(f * PI))) + 0.5f





[generic]
def outBounce(p : float)
  if (p < 4.f / 11.f)
    return (121.f * p * p) / 16.f
  elif (p < 8.f / 11.f)
    return (363.f / 40.f * p * p) - (99.f / 10.f * p) + 17.f / 5.f
  elif (p < 9.f / 10.f)
    return (4356.f / 361.f * p * p) - (35442.f / 1805.f * p) + 16061.f / 1805.f
  else
    return (54.f / 5.f * p * p) - (513.f / 25.f * p) + 268.f / 25.f

[generic]
def inBounce(p : float)
  return 1.f - outBounce(1.f - p)

[generic]
def inOutBounce(p : float)
  if (p < 0.5f)
    return 0.5f * inBounce(p * 2.f)
  else
    return 0.5f * outBounce(p * 2.f - 1.f) + 0.5f




[generic]
def inOutBezier(p : float)
  return p * p * (3.f - 2.f * p)


[generic]
def smoothstep(edge0 : float;
               edge1 : float;
               p : float)
  let t = clamp((p - edge0) / (edge1 - edge0), 0.0, 1.0)
  return inOutBezier(t)


[generic]
def cosineFull(p : float)
  return 0.5f - cos(p * TWOPI) * 0.5f

[generic]
def inStep(p : float)
  return p > 0.5f ? 1.f : 0.f

[generic]
def outStep(p : float)
  return p < 0.5f ? 1.f : 0.f

[generic]
def blinkSin(p : float)
  var val = (p < 0.1) ? 10.0 * p : 1.0 - (p - 0.1) / 0.9
  if (p < 0.5)
    val *= 0.75 + 0.25 * sin((p * 80.0 - 0.5) * PI)
  return val

[generic]
def blinkCos(p : float)
  var val = (p < 0.1) ? 10.0 * p : 1.0 - (p - 0.1) / 0.9
  if (p < 0.5)
    val *= 0.75 + 0.25 * cos((p * 40.0 - 0.5) * PI)
  return val

[generic]
def smoothStartArch3(p : float)
  return p * p * (1. - p) * 3.375

[generic]
def smoothStopArch3(p : float)
  let a = 1. - p
  return p * a * a * 6.75