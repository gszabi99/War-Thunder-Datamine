::is_version_equals_or_newer <- function is_version_equals_or_newer(verTxt, isTorrentVersion = false) // "1.43.7.75"
{
  if (!("get_game_version" in ::getroottable()))
    return false
  local cur = isTorrentVersion ? ::get_game_version() : ::get_base_game_version()
  return cur == 0 || cur >= ::get_version_int_from_string(verTxt)
}

::is_version_equals_or_older <- function is_version_equals_or_older(verTxt, isTorrentVersion = false) // "1.61.1.37"
{
  if (!("get_game_version" in ::getroottable()))
    return true
  local cur = isTorrentVersion ? ::get_game_version() : ::get_base_game_version()
  return cur != 0 && cur <= ::get_version_int_from_string(verTxt)
}

::get_version_int_from_string <- function get_version_int_from_string(versionText)
{
  local res = 0
  local list = ::split(versionText, ".")
  local intRegExp = regexp2(@"\D+")
  for(local i = list.len()-1; i >= 0; i--)
  {
    local val = list[i]
    if (intRegExp.match(val))
    {
      ::dagor.assertf(false, "Error: cant convert version text to int: " + versionText)
      break
    }
    res += val.tointeger() << (8 * (list.len() - i - 1))
  }
  return res
}

//--------------------------------------------------------------------//
//----------------------OBSOLETTE SCRIPT FUNCTIONS--------------------//
//-- Do not use them. Use null operators or native functons instead --//
//--------------------------------------------------------------------//

::getTblValue <- @(key, tbl, defValue = null) key in tbl ? tbl[key] : defValue

//--------------------------------------------------------------------//
//----------------------COMPATIBILITIES BY VERSIONS-------------------//
// -----------can be removed after version reach all platforms--------//
//--------------------------------------------------------------------//

//----------------------------wop_1_99_1_X---------------------------------//
::apply_compatibilities({
  get_sso_short_token = @() { yuplayResult = ::YU2_FAIL, shortToken = null }
  is_dlss_quality_available_at_resolution = @(request_quality, screen_width, screen_height) false
  is_sound_inited = @() true
  set_mute_sound = @(bool) null
  hangar_current_preset_changed = @(...) null
})

//----------------------------wop_1_101_0_X---------------------------------//
::apply_compatibilities({
  gchat_voice_mute_peer_by_name = @(...) null
  gchat_voice_mute_peer_by_uid = @(...) null
  ES_UNIT_TYPE_BOAT = ::ES_UNIT_TYPE_SHIP
})

//----------------------------wop_1_101_1_X---------------------------------//
::apply_compatibilities({
  EII_AI_GUNNERS = 30
  AI_GUNNERS_DISABLED = 0
  AI_GUNNERS_ALL_TARGETS = 1
  AI_GUNNERS_AIR_TARGETS = 2
  AI_GUNNERS_GROUND_TARGETS = 3
  get_ai_gunners_state = @() 0
  set_option_torpedo_dive_depth = @(...) null
  get_option_torpedo_dive_depth = @(...) 1
  get_option_torpedo_dive_depth_auto = @() false
  get_options_torpedo_dive_depth = @() [1, 4]
  xbox_try_show_crossnetwork_message = @() false
  get_activate_ground_active_counter_measures_on_spawn = @() false
  GO_WAITING_FOR_RESULT = 4
})

//----------------------------wop_2_1_0_X---------------------------------//
::apply_compatibilities({
  USEROPT_ACTIVATE_AIRBORNE_WEAPON_SELECTION_ON_SPAWN = -1
})