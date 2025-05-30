from "%scripts/dagui_library.nut" import *
from "%scripts/options/optionsExtNames.nut" import *
let { set_gui_option, get_gui_option, setGuiOptionsMode, getGuiOptionsMode } = require("guiOptions")

let optionsModeByGameMode = {
  [GM_CAMPAIGN]          = OPTIONS_MODE_CAMPAIGN,
  [GM_TRAINING]          = OPTIONS_MODE_TRAINING,
  [GM_TEST_FLIGHT]       = OPTIONS_MODE_TRAINING,
  [GM_SINGLE_MISSION]    = OPTIONS_MODE_SINGLE_MISSION,
  [GM_USER_MISSION]      = OPTIONS_MODE_SINGLE_MISSION,
  [GM_DYNAMIC]           = OPTIONS_MODE_DYNAMIC,
  [GM_BUILDER]           = OPTIONS_MODE_DYNAMIC,
  [GM_DOMINATION]        = OPTIONS_MODE_MP_DOMINATION,
  [GM_SKIRMISH]          = OPTIONS_MODE_MP_SKIRMISH,
}

function getOptionsMode(game_mode) {
  return optionsModeByGameMode?[game_mode] ?? OPTIONS_MODE_GAMEPLAY
}

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
  getOptionsMode
}