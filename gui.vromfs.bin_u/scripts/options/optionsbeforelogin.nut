from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { get_gui_option } = require("guiOptions")

const AUTOLOGIN_SAVE_ID = "autologin"

::is_autologin_enabled <- function is_autologin_enabled() {
  local res = ::load_local_shared_settings(AUTOLOGIN_SAVE_ID)
  if (res != null)
    return res
  //compatibility with saves 1.67.2.X and below
  res = get_gui_option(::USEROPT_AUTOLOGIN) || false
  ::set_autologin_enabled(res)
  return res
}

::set_autologin_enabled <- function set_autologin_enabled(isEnabled)
{
  ::save_local_shared_settings(AUTOLOGIN_SAVE_ID, isEnabled)
}