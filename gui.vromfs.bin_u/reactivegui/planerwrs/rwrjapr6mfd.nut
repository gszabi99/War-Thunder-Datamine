from "%rGui/globals/ui_library.nut" import *

let { rwrTargetsComponent, rwrPriorityTargetComponent } = require("rwrAnAlr67Components.nut")
let { createGrid } = require("rwrAnAlr67MfdGridComponent.nut")

function scope(scale, fontSizeMult) {
  return {
    size = [pw(scale), ph(scale)]
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = [
      createGrid(),
      rwrTargetsComponent(1.0, fontSizeMult),
      rwrPriorityTargetComponent(1.0)
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