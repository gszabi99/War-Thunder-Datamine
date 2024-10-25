from "%rGui/globals/ui_library.nut" import *

let { atan, PI } = require("math")

function calcAngleBetweenVectors(point1, point2 = {}) {
  let { x = 0, y = 0 } = point2
  let deltaX = point1.x - x
  let deltaY = point1.y - y

  let signK = deltaY >= 0 ? 1 : -1
  local res = deltaX == 0 ? signK * PI / 2 : atan(deltaY / deltaX)
  if (deltaX < 0)
    res -= PI
  return {
    rad = res
    deg = 180 * res / PI
  }
}

return {
  calcAngleBetweenVectors
  even = @(px) (px / 2.0).tointeger() * 2
}