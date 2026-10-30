import "%scripts/g_listener_priority.nut" as g_listener_priority
import "DataBlock" as DataBlock
from "%scripts/crossModuleEvents.nut" import GAME_LOCALIZATION_CHANGED
from "%scripts/countries/countriesCustomization.nut" import getCountryOverride
from "%sqStdLibs/helpers/subscriptions.nut" import add_event_listener
from "%sqStdLibs/helpers/net_errors.nut" import script_net_assert_once
from "%sqstd/datablock.nut" import eachParam
from "%scripts/dagui_library.nut" import *
from "types" import String

let { GUI } = require("%scripts/utils/configs.nut")

let countryFlagsPreset = {}
let getCountryFlagImg = @(id) countryFlagsPreset?[id] ?? ""
let getCountryIcon = @(countryId, useOverrides = true) getCountryFlagImg(useOverrides ? getCountryOverride(countryId) : countryId)
let hasCountryIcon = @(id) countryFlagsPreset?[id] != null


function initCountryFlagsPreset() {
  let blk = GUI.get()
  if (!blk)
    return
  let texBlk = blk?.texture_presets
  if (!texBlk || type(texBlk) != "instance" || !(texBlk instanceof DataBlock)) {
    script_net_assert_once("flags_presets", "Error: not texture_presets block in gui.blk")
    return
  }

  countryFlagsPreset.clear()
  let block = texBlk?["default"]
  if (!block || type(block) != "instance" || !(block instanceof DataBlock))
    return

  eachParam(block, function(value, name) {
    if (!(name in countryFlagsPreset) && value instanceof String)
      countryFlagsPreset[name] <- value
  })
}

add_event_listener(GAME_LOCALIZATION_CHANGED, @(_params) initCountryFlagsPreset(),
  null, g_listener_priority.CONFIG_VALIDATION)

initCountryFlagsPreset()

let getCountryFlagForUnitTooltip = @(id) countryFlagsPreset?[$"{id}_unit_tooltip"]
  ?? $"#ui/images/flags/unit_tooltip/{id}.avif:0:P"

return freeze({
  getCountryFlagForUnitTooltip
  getCountryFlagImg
  getCountryIcon
  hasCountryIcon
})
