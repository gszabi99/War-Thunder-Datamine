from "%scripts/dagui_library.nut" import *

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { hardPersistWatched } = require("%sqstd/globalState.nut")
let updateExtWatched = require("%scripts/global/updateExtWatched.nut")
let { color4ToInt } = require("%scripts/utils/colorUtil.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_CROSSHAIR_COLOR, USEROPT_HELI_COCKPIT_HUD_DISABLED,
  USEROPT_HUD_SHOW_TANK_GUNS_AMMO } = require("%scripts/options/optionsExtNames.nut")

function mkUseroptHardWatched(id, defValue = null) {
  let opt = hardPersistWatched(id, defValue)
  opt.subscribe(@(v) updateExtWatched({ [id] = v }))
  return opt
}

let crosshairColorOpt = mkUseroptHardWatched("crosshairColorOpt", 0xFFFFFFFF)
let isHeliPuilotHudDisabled = mkUseroptHardWatched("heliPilotHudDisabled", false)
let isVisibleTankGunsAmmoIndicator = mkUseroptHardWatched("isVisibleTankGunsAmmoIndicator", false)

function getOption(optionName) {
  return ::get_option(optionName)
}

function getCrosshairColor() {
  let opt = getOption(USEROPT_CROSSHAIR_COLOR)
  let colorIdx = opt.values[opt.value]
  return color4ToInt(::crosshair_colors[colorIdx].color)
}

function getHeliPuilotHudDisabled() {
  return getOption(USEROPT_HELI_COCKPIT_HUD_DISABLED)
}

function getIsVisibleTankGunsAmmoIndicatorValue() {
  return ::get_gui_option_in_mode(USEROPT_HUD_SHOW_TANK_GUNS_AMMO, OPTIONS_MODE_GAMEPLAY, false)
}

function initOptions() {
  crosshairColorOpt(getCrosshairColor())
  isHeliPuilotHudDisabled(getHeliPuilotHudDisabled().value)
  isVisibleTankGunsAmmoIndicator(getIsVisibleTankGunsAmmoIndicatorValue())
}

addListenersWithoutEnv({
  InitConfigs = @(_) initOptions()
})

return {
  crosshairColorOpt
  isHeliPuilotHudDisabled
  isVisibleTankGunsAmmoIndicator
}
