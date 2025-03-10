from "%scripts/dagui_library.nut" import *

let { get_gui_option } = require("guiOptions")
let { saveLocalSharedSettings, loadLocalSharedSettings
} = require("%scripts/clientState/localProfile.nut")
let { USEROPT_AUTOLOGIN } = require("%scripts/options/optionsExtNames.nut")

const AUTOLOGIN_SAVE_ID = "autologin"

function set_autologin_enabled(isEnabled) {
  saveLocalSharedSettings(AUTOLOGIN_SAVE_ID, isEnabled)
}

function is_autologin_enabled() {
  local res = loadLocalSharedSettings(AUTOLOGIN_SAVE_ID)
  if (res != null)
    return res
  
  res = get_gui_option(USEROPT_AUTOLOGIN) || false
  set_autologin_enabled(res)
  return res
}

return {
  set_autologin_enabled
  is_autologin_enabled
}