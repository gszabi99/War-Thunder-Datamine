local { is_sound_mods_enabled, restart_game_without_mods } = ::require_native("soundModCheck")

local isAllowSoundMods = @(event) event?.allowSoundMods ?? true

local function showMsgboxIfSoundModsNotAllowed(event)
{
  if (!is_sound_mods_enabled() || isAllowSoundMods(event))
    return true
  ::scene_msg_box("sound_mods_not_allowed", null, ::loc("sound_mod_not_allowed_restart"),
  [
    ["restart", restart_game_without_mods],
    ["cancel", function() {}]
  ], null)
  return false
}


return {
  showMsgboxIfSoundModsNotAllowed
}