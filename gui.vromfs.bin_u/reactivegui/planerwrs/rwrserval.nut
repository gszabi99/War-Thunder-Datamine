from "%rGui/globals/ui_library.nut" import *

let { color, rwrTargetsComponent, rwrPriorityTargetComponent } = require("rwrAnAlr56Components.nut")

let gridCommands = [
  [VECTOR_LINE, -10, 0, 10, 0],
  [VECTOR_LINE, 0, -10, 0, 10],
  [VECTOR_ELLIPSE, 0, 0, 0.5  * 100.0, 0.5  * 100.0]
]

function createGrid(gridStyle) {
  return {
    pos = [pw(50), ph(50)]
    size = [pw(100 * gridStyle.scale), ph(100 * gridStyle.scale)]
    color = color
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(gridStyle.lineWidthScale)
    fillColor = 0
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
    children = scope(scale, style.__merge( {object = style.object.__merge({ scale = style.object.scale * 0.65}) }))
  }
}

return tws