from "%scripts/dagui_library.nut" import *

let { is_sound_mods_enabled, restart_game_without_mods, is_sound_mods_force_disabled = null,
  get_sound_mods_error_type = null,
  SOUND_MODS_FILES_INTEGRITY = 1, SOUND_MODS_FMOD_ASSERTS = 2 } = require("soundModCheck")

let isAllowSoundMods = @(event) event?.allowSoundMods ?? true

function showMsgboxIfSoundModsNotAllowed(event) {
  if (!is_sound_mods_enabled() || isAllowSoundMods(event))
    return true
  scene_msg_box("sound_mods_not_allowed", null, loc("sound_mod_not_allowed_restart"),
  [
    ["restart", restart_game_without_mods],
    ["cancel", function() {}]
  ], null)
  return false
}

function showMsgboxIfSoundModsForceDisabled() {
  if (is_sound_mods_force_disabled!= null && is_sound_mods_force_disabled())
    scene_msg_box("sound_mods_force_disabled", null, loc("sound_mods_force_disabled"),
    [
      ["ok", function() {}]
    ], null)
}

function showMsgboxIfSoundModsBanksCheckFailed() {
  if (get_sound_mods_error_type == null)
    return
  let errorType = get_sound_mods_error_type()
  if (errorType == SOUND_MODS_FILES_INTEGRITY)
    scene_msg_box("sound_mods_banks_check_failed", null, loc("sound_mods_banks_check_failed"),
    [
      ["ok", function() {}]
    ], null)
  else if (errorType == SOUND_MODS_FMOD_ASSERTS)
    scene_msg_box("sound_mods_banks_check_failed", null, loc("sound_mods_disabled"),
    [
      ["ok", function() {}]
    ], null)
}

return {
  showMsgboxIfSoundModsNotAllowed
  showMsgboxIfSoundModsForceDisabled
  showMsgboxIfSoundModsBanksCheckFailed
}