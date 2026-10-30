import "%rGui/globals/extWatched.nut" as extWatched
import "%appGlobals/style/cssConsts.nut" as cssConsts
from "%appGlobals/options/safeAreaMenuValue.nut" import getPreLoginSafearea
from "vr" import is_stereo_mode
from "%rGui/globals/ui_library.nut" import *

let debugRowHeight = cssConsts.debugRowHeight.tointeger()

let safeAreaHud = extWatched("safeAreaHud", [ 1.0, 1.0 ])

let safeAreaMenu = extWatched("safeAreaMenu", getPreLoginSafearea())

let isInVr = is_stereo_mode()

let recalculateHudSize = function(safeArea) {
  let borders = [
    max((sh((1.0 - safeArea[1]) * 100) / 2).tointeger(), debugRowHeight),
    max((sw((1.0 - safeArea[0]) * 100) / 2).tointeger(), debugRowHeight)
  ]
  let size = [sw(100) - 2 * borders[1], sh(100) - 2 * borders[0]]
  return {
    size = size
    borders = borders
  }
}

let safeAreaSizeHud = Computed(@() recalculateHudSize(safeAreaHud.get()))
let safeAreaSizeMenu = Computed(@() recalculateHudSize(safeAreaMenu.get()))

let rw = Computed(@() safeAreaSizeHud.get().size[0])
let rh = Computed(@() safeAreaSizeHud.get().size[1])
let bw = Computed(@() safeAreaSizeHud.get().borders[1])
let bh = Computed(@() safeAreaSizeHud.get().borders[0])

return freeze({
  safeAreaSizeHud
  safeAreaSizeMenu
  rw
  rh
  bw
  bh
  isInVr
  safeAreaHud
  safeAreaMenu
})
