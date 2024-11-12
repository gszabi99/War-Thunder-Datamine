from "%rGui/globals/ui_library.nut" import *

let { createRwrMark, createGrid, rwrTargetsComponent } = require("rwrAri23333Components.nut")

function scope(scale, style) {
  return {
    size = [pw(scale), ph(scale)]
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = [
      createRwrMark(style.grid),
      {
        size = [pw(85), ph(85)]
        children = [
          createGrid(style.grid),
          rwrTargetsComponent(style.object)
        ]
      }
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