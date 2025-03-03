from "%rGui/globals/ui_library.nut" import *
let extWatched = require("%rGui/globals/extWatched.nut")
let { SHIP_HIT_ICONS_VIS_ALL_FLAGS } = require("%globalScripts/shipHitIconsConsts.nut")

let crosshairColorOpt = extWatched("crosshairColorOpt", 0xFFFFFFFF)
let isHeliPilotHudDisabled = extWatched("heliPilotHudDisabled", false)
let isVisibleTankGunsAmmoIndicator = extWatched("isVisibleTankGunsAmmoIndicator", false)
let shipHitIconsVisibilityStateFlags = extWatched("shipHitIconsVisibilityStateFlags", SHIP_HIT_ICONS_VIS_ALL_FLAGS)

return {
  crosshairColorOpt
  isHeliPilotHudDisabled
  isVisibleTankGunsAmmoIndicator
  shipHitIconsVisibilityStateFlags
}