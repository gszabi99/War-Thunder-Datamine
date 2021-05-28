local extWatched = require("reactiveGui/globals/extWatched.nut")

local debugRowHeight = 14 /* Height of on-screen debug text (fps, build, etc) */

local resolution = extWatched("resolution",
  @() ::cross_call.sysopt.getGuiValue("resolution", "1024 x 768"))

local mode = extWatched("screenMode",
  @() ::cross_call.sysopt.getGuiValue("mode", "fullscreen"))

local safeAreaHud = extWatched("safeAreaHud",
  @() ::cross_call.getHudSafearea() ?? [ 1.0, 1.0 ])

local safeAreaMenu = extWatched("safeAreaMenu",
  @() ::cross_call.getMenuSafearea() ?? [ 1.0, 1.0 ])

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

local safeAreaSizeHud = ::Computed(@() recalculateHudSize(safeAreaHud.value))
local safeAreaSizeMenu = ::Computed(@() recalculateHudSize(safeAreaMenu.value))

local function rw(percent) {
  return (percent / 100.0 * safeAreaSizeHud.value.size[0]).tointeger()
}

local function setOnVideoMode(...){
  ::gui_scene.setInterval(0.5,
    function() {
      ::gui_scene.clearTimer(callee())
      ::interop.updateExtWatched({
        safeAreaHud = ::cross_call.getHudSafearea() ?? [ 1.0, 1.0 ]
        safeAreaMenu = ::cross_call.getMenuSafearea() ?? [ 1.0, 1.0 ]
      })
  })
}
foreach (w in [resolution, mode])
  w.subscribe(setOnVideoMode)

return {
  safeAreaSizeHud = safeAreaSizeHud
  safeAreaSizeMenu = safeAreaSizeMenu
  rw = rw
}
