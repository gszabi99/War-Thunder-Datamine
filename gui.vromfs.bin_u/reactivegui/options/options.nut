import "%rGui/globals/extWatched.nut" as extWatched
from "%globalScripts/shipHitIconsConsts.nut" import SHIP_HIT_ICONS_VIS_ALL_FLAGS
from "%rGui/globals/ui_library.nut" import *

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