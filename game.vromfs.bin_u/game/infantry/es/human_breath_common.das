module human_breath_common shared

require math


def private half_wave(t, p, q : float) : float
  let a = pow(t, p)
  let b = pow(1.f - t, q)
  return a / (a + b)

def private half_wave_velocity(t, p, q : float) : float
  let a = pow(t, p)
  let b = pow(1.f - t, q)
  let sum = a + b
  return (b * p * pow(t, p - 1.f) + a * q * pow(1.f - t, q - 1.f)) / (sum * sum)

def breath_wave(t, d, a, p1, q1, q2, p2 : float) : float
  if t <= d
    return 0.f
  elif t <= a
    return half_wave((t - d) / (a - d), p1, q1)
  else
    return half_wave((1.f - t) / (1.f - a), p2, q2)

def breath_wave_velocity(t, d, a, p1, q1, q2, p2 : float) : float
  if t <= d
    return 0.f
  elif t <= a
    return half_wave_velocity((t - d) / (a - d), p1, q1) / (a - d)
  else
    return -half_wave_velocity((1.f - t) / (1.f - a), p2, q2) / (1.f - a)
