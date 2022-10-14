from "%rGui/globals/ui_library.nut" import *
let { send } = require("eventbus")
let { is_stereo_mode } = require("vr")
let extWatched = require("%rGui/globals/extWatched.nut")

let debugRowHeight = 14 /* Height of on-screen debug text (fps, build, etc) */

let resolution = extWatched("resolution", "1024 x 768")

let mode = extWatched("screenMode", "fullscreen")

let safeAreaHud = extWatched("safeAreaHud", [ 1.0, 1.0 ])

let safeAreaMenu = extWatched("safeAreaMenu", [ 1.0, 1.0 ])

let isInVr = is_stereo_mode()

send("updateScreenStates", {})

send("updateSafeAreaStates", {})

let recalculateHudSize = function(safeArea) {
  let borders = [
    max((sh((1.0 - safeArea[1]) *100) / 2).tointeger(), debugRowHeight),
    max((sw((1.0 - safeArea[0]) *100) / 2).tointeger(), debugRowHeight)
  ]
  let size = [sw(100) - 2 * borders[1], sh(100) - 2 * borders[0]]
  return {
    size = size
    borders = borders
  }
}

let safeAreaSizeHud = Computed(@() recalculateHudSize(safeAreaHud.value))
let safeAreaSizeMenu = Computed(@() recalculateHudSize(safeAreaMenu.value))

let rw = Computed(@() safeAreaSizeHud.value.size[0])
let rh = Computed(@() safeAreaSizeHud.value.size[1])
let bw = Computed(@() safeAreaSizeHud.value.borders[1])
let bh = Computed(@() safeAreaSizeHud.value.borders[0])

let function setOnVideoMode(...){
  gui_scene.setInterval(0.5,
    function() {
      gui_scene.clearTimer(callee())
      send("updateSafeAreaStates", {})
  })
}
foreach (w in [resolution, mode])
  w.subscribe(setOnVideoMode)

return {
  safeAreaSizeHud
  safeAreaSizeMenu
  rw
  rh
  bw
  bh
  isInVr
}
