module base shared
require math
require DagorMath

let
  DEG_TO_RAD = PI / 180.
  RAD_TO_DEG = 180. / PI
  TWOPI = 2. * PI
  HALF_PI = PI * 0.5
  SAFE_HALF_PI = HALF_PI - 1e-3f

[generic]
def get_indent_tm(): float3x4
  var tm: float3x4
  identity(tm)
  return <- tm

let
  IDENT_TM = get_indent_tm()
  VERY_SMALL_NUMBER = 4e-19

[generic]
def deg_to_rad(val)
  return val * DEG_TO_RAD

[generic]
def rad_to_deg(val)
  return val * RAD_TO_DEG

[generic]
def square(x)
  return x * x


[generic]
def approach(from, to:auto(algebraic); dt: float; viscosity: float)
  return viscosity < 1e-9 ? to : from + (1.0 - exp(-dt / viscosity)) * (to - from)

// move_to version for float
[generic]
def move_to_scalar(from, to, dt, vel: float)
  let d = vel * dt
  if abs(from - to) < d
    return to

  if to < from
    return from - d
  return from + d

// move_to version for vector types
[generic]
def move_to(from, to: auto(algebraic); dt, vel: float)
  let d = vel * dt
  let dir = to - from
  let dlen = length(dir)
  if dlen <= d
    return to
  return from + (dir / dlen) * d

[generic]
def invsqrt(x)
  return rcp(sqrt(x))

[generic]
def safeinvsqrt(x)
  return x > 0.0 ? invsqrt(x) : 1.0

[generic]
def safeinv(val: float3): float3
  return float3(safeinv(val.x), safeinv(val.y), safeinv(val.z))

[generic]
def normalize_default(vec, default_vec)
  let len = length(vec)
  return len > 1e-9 ? vec / len : default_vec

// das implementation of C++ function from dag_mathBase.h
[generic]
def is_relative_equal_float(a, b : float; max_diff : float = 1e-5; max_rel_diff : float = FLT_EPSILON)
  let diff = abs(a-b)
  if diff < max_diff
    return true
  let absA = abs(a)
  let absB = abs(b)
  return diff < (absA < absB ? absB : absA) * max_rel_diff

// das implementation of C++ function from dag_mathBase.h
[generic]
def is_equal_float(a, b : float; eps : float = 1e-5f)
  return is_relative_equal_float(a,b, eps, FLT_EPSILON)

// das implementation of C++ function from dag_mathBase.h
[generic]
def are_approximately_equal(a, b : float; epsilon : float = 8.0 * FLT_EPSILON) // Three bits precision by default.
  return is_relative_equal_float(a,b, epsilon, epsilon)

// returns signed magnitude of the vector that would result from a regular 3D cross product of the input vectors
[generic]
def cross2d(a, b : float2) : float
  return a.y * b.x - a.x * b.y


[generic]
def is_nan(a: float3)
  return is_nan(a.x) || is_nan(a.y) || is_nan(a.z)
