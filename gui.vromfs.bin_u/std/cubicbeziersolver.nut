from "math" import fabs





function sampleCurveX(t: number, ax: number, bx: number, cx: number): number {
  return ((ax * t + bx) * t + cx) * t
}

function sampleCurveY(t: number, ay: number, by: number, cy: number): number {
  return ((ay * t + by) * t + cy) * t
}

function sampleCurveDerivativeX(t: number, ax: number, bx: number, cx) {
  return (3.0 * ax * t + 2.0 * bx) * t + cx
}

function solveCurveX(x: number, epsilon, ax, bx, cx): number {
  local t0
  local t1
  local t2 = x
  local x2
  local d2
  local i

  
  for (i = 0; i < 8; ++i) {
    x2 = sampleCurveX(t2, ax, bx, cx) - x;
    if (fabs(x2) < epsilon)
      return t2;
    d2 = sampleCurveDerivativeX(t2, ax, bx, cx)
    if (fabs(d2) < epsilon)
      break;
    t2 = t2 - x2 / d2;
  }

  
  t0 = 0.0
  t1 = 1.0
  t2 = x

  if (t2 < t0)
    return t0
  if (t2 > t1)
    return t1

  while (t0 < t1) {
    x2 = sampleCurveX(t2, ax, bx, cx);
    if (fabs(x2 - x) < epsilon)
      return t2
    if (x > x2)
      t0 = t2
    else
      t1 = t2
    t2 = (t1 - t0) * 0.5 + t0
  }

  
  return t2;
}


const epsilon = 0.000001 

function solveCubicBezier(t: number, p1x: number, p1y: number, p2x: number, p2y: number): number {
  
  
  let cx = 3.0 * p1x
  let bx = 3.0 * (p2x - p1x) - cx
  let ax = 1.0 - cx - bx

  let cy = 3.0 * p1y
  let by = 3.0 * (p2y - p1y) - cy
  let ay = 1.0 - cy - by

  return sampleCurveY(solveCurveX(t, epsilon, ax, bx, cx), ay, by, cy)
}


return freeze({
  solveCubicBezier
})
