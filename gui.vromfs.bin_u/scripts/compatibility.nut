::is_version_equals_or_newer <- function is_version_equals_or_newer(verTxt, isTorrentVersion = false) // "1.43.7.75"
{
  if (!("get_game_version" in ::getroottable()))
    return false
  let cur = isTorrentVersion ? ::get_game_version() : ::get_base_game_version()
  return cur == 0 || cur >= ::get_version_int_from_string(verTxt)
}

::is_version_equals_or_older <- function is_version_equals_or_older(verTxt, isTorrentVersion = false) // "1.61.1.37"
{
  if (!("get_game_version" in ::getroottable()))
    return true
  let cur = isTorrentVersion ? ::get_game_version() : ::get_base_game_version()
  return cur != 0 && cur <= ::get_version_int_from_string(verTxt)
}

::get_version_int_from_string <- function get_version_int_from_string(versionText)
{
  local res = 0
  let list = ::split(versionText, ".")
  let intRegExp = regexp2(@"\D+")
  for(local i = list.len()-1; i >= 0; i--)
  {
    let val = list[i]
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

//----------------------------wop_2_5_0_X---------------------------------//
::apply_compatibilities({
  is_perf_metrics_available = @(request_mode) false
  get_option_delayed_download_content = @() false
  set_option_delayed_download_content = @(value) null
  set_gui_vr_params = @(...) null
  get_commander_camera_in_views = @() 0
  set_commander_camera_in_views = @(value) null
})

//----------------------------wop_2_7_0_X---------------------------------//
::apply_compatibilities({
  EXP_EVENT_TIMED_AWARD = 29
  USEROPT_HUE_AIRCRAFT_HUD = -1
  USEROPT_HUE_AIRCRAFT_PARAM_HUD = -1
  USEROPT_HUE_AIRCRAFT_HUD_ALERT = -1
  USEROPT_HUE_HELICOPTER_PARAM_HUD = -1
  is_freecam_enabled = @() false
})

//----------------------------wop_2_9_0_X---------------------------------//
::apply_compatibilities({
  EXP_EVENT_DEATH = 30
  EXP_EVENT_TOTAL = 31
})

