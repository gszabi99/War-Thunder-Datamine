from "%scripts/dagui_library.nut" import *

let { is_sound_mods_enabled, restart_game_without_mods, is_sound_mods_force_disabled = null,
  is_sound_mods_banks_check_failed = null } = require("soundModCheck")

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
  return false
}

function showMsgboxIfSoundModsBanksCheckFailed() {
  if (is_sound_mods_banks_check_failed != null && is_sound_mods_banks_check_failed())
    scene_msg_box("sound_mods_banks_check_failed", null, loc("sound_mods_banks_check_failed"),
    [
      ["ok", function() {}]
    ], null)
  return false
}

return {
  showMsgboxIfSoundModsNotAllowed
  showMsgboxIfSoundModsForceDisabled
  showMsgboxIfSoundModsBanksCheckFailed
}