options indenting = 2
module curve shared
require ecs
require DagorMath


def get_value_on_2d_pl_curve(t : float; curve : Array) : float
  let curveChunks = curve |> length() - 1
  let curvePoints = curve |> length()
  if curveChunks < 1
    return 0.0

  var firstPoint = curve[0] |> get_Point2()
  if firstPoint == null
    return 0.0
  for i in range(1, curveChunks + 1)
    let secondPoint = curve[i] |> get_Point2()
    if secondPoint == null
      return 0.0
    if t > (*secondPoint).x
      if i + 1 < curvePoints
        firstPoint = secondPoint
        continue
      else 
        return (*secondPoint).y
    elif t < (*firstPoint).x
      return (*firstPoint).y
    return cvt(t, (*firstPoint).x, (*secondPoint).x, (*firstPoint).y, (*secondPoint).y)

  return 0.0
