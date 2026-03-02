from "%rGui/globals/ui_library.nut" import *
let extWatched = require("%rGui/globals/extWatched.nut")
let { SHIP_HIT_ICONS_VIS_ALL_FLAGS } = require("%globalScripts/shipHitIconsConsts.nut")

const DAMAGE_INDICATOR_MAX_VALUE = 2
const DAMAGE_INDICATOR_SCALE_FACTOR = 0.333

let crosshairColorOpt = extWatched("crosshairColorOpt", 0xFFFFFFFF)
let isHeliPilotHudDisabled = extWatched("heliPilotHudDisabled", false)
let isVisibleTankGunsAmmoIndicator = extWatched("isVisibleTankGunsAmmoIndicator", false)
let shipHitIconsVisibilityStateFlags = extWatched("shipHitIconsVisibilityStateFlags", SHIP_HIT_ICONS_VIS_ALL_FLAGS)
let isChatReputationFilterEnabled = extWatched("isChatReputationFilterEnabled", false)
let userOptDamageIndicatorSize = extWatched("userOptDamageIndicatorSize", 1)

let damageIndicatorScale = Computed(@() (1 + DAMAGE_INDICATOR_SCALE_FACTOR * (userOptDamageIndicatorSize.get().tofloat() / DAMAGE_INDICATOR_MAX_VALUE)))

return {
  crosshairColorOpt
  isHeliPilotHudDisabled
  isVisibleTankGunsAmmoIndicator
  shipHitIconsVisibilityStateFlags
  isChatReputationFilterEnabled
  userOptDamageIndicatorSize
  damageIndicatorScale
}