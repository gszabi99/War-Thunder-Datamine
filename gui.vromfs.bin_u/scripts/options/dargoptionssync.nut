//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let mkHardWatched = require("%globalScripts/mkHardWatched.nut")
let { correctHueTarget, TARGET_HUE_HELICOPTER_CROSSHAIR } = require("colorCorrector")
let updateExtWatched = require("%scripts/global/updateExtWatched.nut")
let { color4ToInt } = require("%scripts/utils/colorUtil.nut")

let function mkUseroptHardWatched(id, defValue = null) {
  let opt = mkHardWatched(id, defValue)
  opt.subscribe(@(v) updateExtWatched({ [id] = v }))
  return opt
}

let crosshairColorOpt = mkUseroptHardWatched("crosshairColorOpt", 0xF0F0F0)
let hueHeliCrosshairOpt = mkUseroptHardWatched("hueHeliCrosshairOpt", 0xF0F0F0)

let function getOptVal(id) {
  let opt = ::get_option(id)
  return opt.values[opt.value]
}

let function getCrosshairColor() {
  let optVal = getOptVal(::USEROPT_CROSSHAIR_COLOR)
  return color4ToInt(::crosshair_colors[optVal].color)
}

let function getHueHeliCrosshair() {
  let optVal = getOptVal(::USEROPT_HUE_HELICOPTER_CROSSHAIR)
  let color = correctHueTarget(optVal, TARGET_HUE_HELICOPTER_CROSSHAIR)
  return color
}

let function initOptions() {
  crosshairColorOpt(getCrosshairColor())
  hueHeliCrosshairOpt(getHueHeliCrosshair())
}

addListenersWithoutEnv({
  InitConfigs = @(_) initOptions()
})

return {
  crosshairColorOpt
  hueHeliCrosshairOpt
}
