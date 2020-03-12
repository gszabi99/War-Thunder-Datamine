local frp = require("std/frp.nut")

local debugRowHeight = 14 /* Height of on-screen debug text (fps, build, etc) */

local resolution = persist("resolution",
  @() Watched(::cross_call.sysopt.getGuiValue("resolution", "1024 x 768")))

local mode = persist("mode",
  @() Watched(::cross_call.sysopt.getGuiValue("mode", "fullscreen")))

local safeAreaHud = persist("safeAreaHud",
  @() Watched(::cross_call.getHudSafearea() ?? [ 1.0, 1.0 ]))

local recalculateHudSize = function(safeArea) {
  local borders = [
    ::max((sh((1.0 - safeArea[1]) *100) / 2).tointeger(), debugRowHeight),
    ::max((sw((1.0 - safeArea[0]) *100) / 2).tointeger(), debugRowHeight)
  ]
  local size = [sw(100) - 2 * borders[1], sh(100) - 2 * borders[0]]
  return {
    size = size
    borders = borders
  }
}

local safeAreaSizeHud = frp.map(safeAreaHud, @(val) recalculateHudSize(val))

local function rw(percent) {
  return (percent / 100.0 * safeAreaSizeHud.value.size[0]).tointeger()
}

frp.subscribe([resolution, mode], function(new_val){
  ::gui_scene.setInterval(0.5,
    function() {
      ::gui_scene.clearTimer(callee())
      safeAreaHud(::cross_call.getHudSafearea() ?? [ 1.0, 1.0 ])
      safeAreaSizeHud.trigger()
  })
})

::interop.updateHudSafeArea <- function (config = {}) {
  local newSafeAreaHud = config?.safeAreaHud
  if(newSafeAreaHud)
    safeAreaHud.update(newSafeAreaHud)
}

::interop.updateScreenOptions <- function (config = {}) {
  local newResolution = config?.resolution
  if(newResolution)
    resolution.update(newResolution)

  local newMode = config?.mode
  if(newMode)
    mode.update(newMode)
}


return {
  safeAreaSizeHud = safeAreaSizeHud
  rw = rw
}
