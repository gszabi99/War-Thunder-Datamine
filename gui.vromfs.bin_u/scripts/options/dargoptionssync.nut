//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let mkHardWatched = require("%globalScripts/mkHardWatched.nut")
let updateExtWatched = require("%scripts/global/updateExtWatched.nut")
let { color4ToInt } = require("%scripts/utils/colorUtil.nut")
let { getRgbIntFromHsv } = require("colorCorrector")

let function mkUseroptHardWatched(id, defValue = null) {
  let opt = mkHardWatched(id, defValue)
  opt.subscribe(@(v) updateExtWatched({ [id] = v }))
  return opt
}

let crosshairColorOpt = mkUseroptHardWatched("crosshairColorOpt", 0xFFFFFFFF)
let hueHeliCrosshairOpt = mkUseroptHardWatched("hueHeliCrosshairOpt", 0xFFFFFFFF)

let function getCrosshairColor() {
  let opt = ::get_option(::USEROPT_CROSSHAIR_COLOR)
  let colorIdx = opt.values[opt.value]
  return color4ToInt(::crosshair_colors[colorIdx].color)
}

let function getHueHeliCrosshair() {
  let opt = ::get_option(::USEROPT_HUE_HELICOPTER_CROSSHAIR)
  let { sat = 0.7, val = 0.7 } = opt.items[opt.value]
  let hue = opt.values[opt.value]
  return getRgbIntFromHsv(hue, sat, val)
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
