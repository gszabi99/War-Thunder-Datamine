from "%rGui/globals/ui_library.nut" import *

let math = require("math")
let { degToRad } = require("%sqstd/math_ex.nut")

let { color, outerCircle,  middleCircle, innerCircle } = require("rwrAnAlr67Parameters.nut")

function makeGridCommands() {
  let commands = [
    [VECTOR_ELLIPSE, 0, 0, 100.0, 100.0],
    [VECTOR_ELLIPSE, 0, 0, outerCircle  * 100.0, outerCircle  * 100.0],
    [VECTOR_ELLIPSE, 0, 0, middleCircle * 100.0, middleCircle * 100.0],
    [VECTOR_ELLIPSE, 0, 0, innerCircle  * 100.0, innerCircle  * 100.0] ]
  for (local az = 0.0; az < 360.0; az += 30)
    commands.append([ VECTOR_LINE,
                      math.sin(degToRad(az)) * 100.0, math.cos(degToRad(az)) * 100.0,
                      math.sin(degToRad(az)) * 0.85 * 100.0, math.cos(degToRad(az)) * 0.85 * 100.0])
  return commands
}

let gridCommands = makeGridCommands()

function createGrid() {
  return {
    pos = [pw(50), ph(50)]
    size = flex()
    color = color
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(4)
    fillColor = 0
    commands = gridCommands
  }
}

return {
 createGrid
}