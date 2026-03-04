from "%rGui/globals/ui_library.nut" import *

let { round } = require("math")
let { damageIndicatorScale } = require("%rGui/options/options.nut")
let { actionBarSize, isActionBarVisible } = require("%rGui/hud/actionBarState.nut")
let { safeAreaSizeHud } = require("%rGui/style/screenState.nut")

let maxDmgIndicatorWidth = Computed(@() round((safeAreaSizeHud.get().size[0] - (isActionBarVisible.get() ? actionBarSize.get()[0] : 0)) / 2 - shHud(0.3)))
let dmgIndicatorWidth = Computed(@() min(round(shHud(30) * damageIndicatorScale.get()), maxDmgIndicatorWidth.get()))

return {
  dmgIndicatorWidth
}