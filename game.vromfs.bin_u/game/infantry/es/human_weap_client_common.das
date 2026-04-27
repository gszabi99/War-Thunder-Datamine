options no_aot

require ecs
require math
require DagorMath




def param_curve(x, x_min, x_max, y_min, y_max, bias : float)
  if x <= x_min
    return 0.0
  if x >= x_max
    return y_max
  let t = safediv(x - x_min, x_max - x_min)
  if bias >= 0.9999
    return t >= 1.0 ? y_max : y_min
  if bias <= 0.0001
    return t > 0.0 ? y_max : y_min
  let exponent = bias / (1.0 - bias)
  return y_min + (y_max - y_min) * pow(t, exponent)

def param_curve(v : float2; x_min, x_max, y_min, y_max, bias : float) : float2
  return float2(param_curve(v.x, x_min, x_max, y_min, y_max, bias),
                param_curve(v.y, x_min, x_max, y_min, y_max, bias))






def private warp_frac(t : float; s : float) : float
  if s >= 0.9999
    return t < 0.5 ? 0.0 : 1.0
  let sC = s < 0. ? 0. : s
  let exponent = 1.0 / (1.0 - sC)
  if t < 0.5
    return 0.5 * pow(2.0 * t, exponent)
  return 1.0 - 0.5 * pow(2.0 * (1.0 - t), exponent)










[generic]
def lookup_lut_2d(lut; N : int; pN : float; vN : float; sharpness : float) : float
  let M = N > 0 ? length(lut) / N : 0
  if M < 1 || N < 1
    return 0.0
  let pC = clamp(pN, 0., 1.)
  let vC = clamp(vN, -1., 1.)
  let pIdx = pC * float(max(M - 1, 0))
  let vIdx = (vC + 1.) * 0.5 * float(max(N - 1, 0))
  
  
  
  let i0 = M >= 2 ? min(int(pIdx), M - 2) : 0
  let tr = M >= 2 ? warp_frac(pIdx - float(i0), sharpness) : 0.0
  let j0 = N >= 2 ? min(int(vIdx), N - 2) : 0
  let tc = N >= 2 ? warp_frac(vIdx - float(j0), sharpness) : 0.0
  let i1 = i0 + (M >= 2 ? 1 : 0)
  let j1 = j0 + (N >= 2 ? 1 : 0)
  let v00 = lut[i0 * N + j0]
  let v01 = lut[i0 * N + j1]
  let v10 = lut[i1 * N + j0]
  let v11 = lut[i1 * N + j1]
  let row0 = v00 + (v01 - v00) * tc
  let row1 = v10 + (v11 - v10) * tc
  return row0 + (row1 - row0) * tr
