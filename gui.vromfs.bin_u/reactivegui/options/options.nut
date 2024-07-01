from "%rGui/globals/ui_library.nut" import *
let extWatched = require("%rGui/globals/extWatched.nut")

let crosshairColorOpt = extWatched("crosshairColorOpt", 0xFFFFFFFF)
let isHeliPilotHudDisabled = extWatched("heliPilotHudDisabled", false)
let isVisibleTankGunsAmmoIndicator = extWatched("isVisibleTankGunsAmmoIndicator", false)

return {
  crosshairColorOpt
  isHeliPilotHudDisabled
  isVisibleTankGunsAmmoIndicator
}