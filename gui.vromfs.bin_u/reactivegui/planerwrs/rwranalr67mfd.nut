from "%rGui/globals/ui_library.nut" import *

let { rwrTargetsComponent, rwrPriorityTargetComponent } = require("rwrAnAlr67Components.nut")
let { createGrid } = require("rwrAnAlr67MfdGridComponent.nut")

function scope(scale, style) {
  return {
    size = [pw(scale * 0.85), ph(scale * 0.85)]
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
    children = scope(scale, style)
  }
}

return tws