from "%scripts/dagui_library.nut" import *
let { set_gui_option, get_gui_option, setGuiOptionsMode, getGuiOptionsMode } = require("guiOptions")


function get_gui_option_in_mode(optionId, mode, defaultValue = null) {
  let mainOptionsMode = getGuiOptionsMode()
  setGuiOptionsMode(mode)
  let res = get_gui_option(optionId)
  if (mainOptionsMode >= 0)
    setGuiOptionsMode(mainOptionsMode)
  if (defaultValue != null && res == null)
    return defaultValue
  return res
}

function set_gui_option_in_mode(optionId, value, mode) {
  let mainOptionsMode = getGuiOptionsMode()
  setGuiOptionsMode(mode)
  set_gui_option(optionId, value)
  setGuiOptionsMode(mainOptionsMode)
}

return {
  get_gui_option_in_mode
  set_gui_option_in_mode
}