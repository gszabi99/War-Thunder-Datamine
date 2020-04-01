local { gameType, useDeathmatchHUD } = require("reactiveGui/missionState.nut")
local { safeAreaSizeHud } = require("reactiveGui/style/screenState.nut")
local football = require("football.ui.nut")
local deathmatch = require("deathmatch.ui.nut")

local scoreBoardChildren = ::Computed(function() {
  if ((gameType.value & GT_FOOTBALL) != 0)
    return football

  if (useDeathmatchHUD.value)
    return deathmatch

  return null
})

return @() {
  size = flex()
  margin = safeAreaSizeHud.value.borders
  halign = ALIGN_CENTER
  watch = [scoreBoardChildren]
  children = scoreBoardChildren.value
}
