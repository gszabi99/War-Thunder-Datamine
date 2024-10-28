from "%rGui/globals/ui_library.nut" import *

let { color, rwrTargetsComponent, rwrPriorityTargetComponent } = require("rwrAnAlr56Components.nut")

let gridCommands = [
  [VECTOR_LINE, -10, 0, 10, 0],
  [VECTOR_LINE, 0, -10, 0, 10],
  [VECTOR_ELLIPSE, 0, 0, 0.5  * 100.0, 0.5  * 100.0]
]

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

function scope(scale, fontSizeMult) {
  return {
    size = [pw(scale), ph(scale)]
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = [
      createGrid(),
      rwrTargetsComponent(0.65, fontSizeMult * 0.9),
      rwrPriorityTargetComponent(0.65)
    ]
  }
}

let function tws(posWatched, sizeWatched, scale, fontSizeMult) {
  return @() {
    watch = [posWatched, sizeWatched]
    size = sizeWatched.get()
    pos = posWatched.get()
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = scope(scale, fontSizeMult)
  }
}

return tws