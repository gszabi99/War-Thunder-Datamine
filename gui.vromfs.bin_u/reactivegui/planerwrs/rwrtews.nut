from "%rGui/globals/ui_library.nut" import *

let math = require("math")
let { degToRad } = require("%sqstd/math_ex.nut")

let { color, rwrTargetsComponent, rwrPriorityTargetComponent } = require("rwrAnAlr56Components.nut")

function makeGridCommands() {
  let commands = [
    [VECTOR_LINE, -10, 0, 10, 0],
    [VECTOR_LINE, 0, -10, 0, 10] ]
  for (local az = 0.0; az < 360.0; az += 30)
    commands.append([VECTOR_ELLIPSE, math.sin(degToRad(az)) * 90.0, math.cos(degToRad(az)) * 90.0, 2, 2])
  return commands
}

let gridCommands = makeGridCommands()

function createGrid(gridStyle) {
  return {
    pos = [pw(50), ph(50)]
    size = [pw(100 * gridStyle.scale), ph(100 * gridStyle.scale)]
    color = color
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(gridStyle.lineWidthScale)
    fillColor = color
    commands = gridCommands
  }
}

function scope(scale, style) {
  return {
    size = [pw(scale), ph(scale)]
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = [
      createGrid(style.grid),
      rwrTargetsComponent(style.object),
      rwrPriorityTargetComponent(style.object)
    ]
  }
}

let function tws(posWatched, sizeWatched, scale, style) {
  return @() {
    watch = [posWatched, sizeWatched]
    size = sizeWatched.get()
    pos = posWatched.get()
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = scope(scale, style.__merge( {object = style.object.__merge({ scale = style.object.scale * 0.50, fontScale = style.object.fontScale * 0.75 }) }))
  }
}

return tws