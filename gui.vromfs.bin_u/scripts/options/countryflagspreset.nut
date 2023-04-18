//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

::g_script_reloader.loadOnce("%scripts/options/bhvHarmonizedImage.nut")
let { eachParam } = require("%sqstd/datablock.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let DataBlock = require("DataBlock")

::country_flags_preset <- {}

::get_country_flags_preset <- function get_country_flags_preset() {
  if (::is_vendor_tencent())
    return "tencent"
  if (::is_chinese_version())
    return "chinese"
  if (::is_vietnamese_version())
    return "vietnam"
  return "default"
}

::get_country_flag_img <- function get_country_flag_img(id) {
  return (id in ::country_flags_preset) ? ::country_flags_preset[id] : ""
}

::get_country_icon <- function get_country_icon(countryId, big = false, locked = false) {
  let id = countryId + (big ? "_big" : "") + (locked ? "_locked" : "")
  return ::get_country_flag_img(id)
}

::init_country_flags_preset <- function init_country_flags_preset() {
  let blk = GUI.get()
  if (!blk)
    return
  let texBlk = blk?.texture_presets
  if (!texBlk || type(texBlk) != "instance" || !(texBlk instanceof DataBlock)) {
    ::script_net_assert_once("flags_presets", "Error: not texture_presets block in gui.blk")
    return
  }

  let defPreset = "default"
  let presetsList = [::get_country_flags_preset()]
  if (presetsList[0] != defPreset)
    presetsList.append(defPreset)

  ::country_flags_preset = {}

  foreach (blockName in presetsList) {
    let block = texBlk?[blockName]
    if (!block || type(block) != "instance" || !(block instanceof DataBlock))
      continue

    eachParam(block, function(value, name) {
      if (!(name in ::country_flags_preset) && type(value) == "string")
        ::country_flags_preset[name] <- value
    })
  }
}

::add_event_listener("GameLocalizationChanged", function(_params) {
    ::init_country_flags_preset()
  }, null, ::g_listener_priority.CONFIG_VALIDATION)

::init_country_flags_preset()