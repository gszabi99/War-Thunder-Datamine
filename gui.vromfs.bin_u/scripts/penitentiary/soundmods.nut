//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { is_sound_mods_enabled, restart_game_without_mods } = require("soundModCheck")

let isAllowSoundMods = @(event) event?.allowSoundMods ?? true

let function showMsgboxIfSoundModsNotAllowed(event) {
  if (!is_sound_mods_enabled() || isAllowSoundMods(event))
    return true
  ::scene_msg_box("sound_mods_not_allowed", null, loc("sound_mod_not_allowed_restart"),
  [
    ["restart", restart_game_without_mods],
    ["cancel", function() {}]
  ], null)
  return false
}


return {
  showMsgboxIfSoundModsNotAllowed
}