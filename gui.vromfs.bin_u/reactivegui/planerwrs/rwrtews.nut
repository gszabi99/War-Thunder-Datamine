import "math" as math
from "%rGui/planeRwrs/rwrAnAlr56Components.nut" import color, baseLineWidth, rwrTargetsComponent
from "%sqstd/math_ex.nut" import degToRad
from "%rGui/globals/ui_library.nut" import *

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
    pos = const [pw(50), ph(50)]
    size = FLEX
    color = color
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * gridStyle.lineWidthScale
    fillColor = color
    commands = gridCommands
  }
}

function scope(scale, style) {
  return {
    size = [pw(scale * style.grid.scale), ph(scale * style.grid.scale)]
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = [
      createGrid(style.grid),
      rwrTargetsComponent(style.object)
    ]
  }
}

function tws(posWatched, sizeWatched, scale, style) {
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