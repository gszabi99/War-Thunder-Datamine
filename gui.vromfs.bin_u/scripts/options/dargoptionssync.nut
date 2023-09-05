//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { hardPersistWatched } = require("%sqstd/globalState.nut")
let updateExtWatched = require("%scripts/global/updateExtWatched.nut")
let { color4ToInt } = require("%scripts/utils/colorUtil.nut")
let { USEROPT_CROSSHAIR_COLOR } = require("%scripts/options/optionsExtNames.nut")

let function mkUseroptHardWatched(id, defValue = null) {
  let opt = hardPersistWatched(id, defValue)
  opt.subscribe(@(v) updateExtWatched({ [id] = v }))
  return opt
}

let crosshairColorOpt = mkUseroptHardWatched("crosshairColorOpt", 0xFFFFFFFF)

let function getCrosshairColor() {
  let opt = ::get_option(USEROPT_CROSSHAIR_COLOR)
  let colorIdx = opt.values[opt.value]
  return color4ToInt(::crosshair_colors[colorIdx].color)
}

let function initOptions() {
  crosshairColorOpt(getCrosshairColor())
}

addListenersWithoutEnv({
  InitConfigs = @(_) initOptions()
})

return {
  crosshairColorOpt
}
