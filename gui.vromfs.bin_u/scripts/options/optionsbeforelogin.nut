from "%appGlobals/clientState/localProfile.nut" import saveLocalSharedSettings, loadLocalSharedSettings
from "%scripts/options/optionsExtNames.nut" import USEROPT_AUTOLOGIN
from "guiOptions" import get_gui_option
from "%scripts/dagui_library.nut" import *

const AUTOLOGIN_SAVE_ID = "autologin"

function set_autologin_enabled(isEnabled) {
  saveLocalSharedSettings(AUTOLOGIN_SAVE_ID, isEnabled)
}

function is_autologin_enabled() {
  local res = loadLocalSharedSettings(AUTOLOGIN_SAVE_ID)
  if (res != null)
    return res
  
  res = !!get_gui_option(USEROPT_AUTOLOGIN)
  set_autologin_enabled(res)
  return res
}

return freeze({
  set_autologin_enabled
  is_autologin_enabled
})