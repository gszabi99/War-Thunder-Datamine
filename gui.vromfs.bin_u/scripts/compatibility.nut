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

//----------------------------wop_2_5_0_X---------------------------------//
::apply_compatibilities({
  EII_AUTO_TURRET = 31
  get_autoturret_state = @() 0
  AI_GUNNERS_SHELL = 4
  EII_SUPPORT_PLANE = 32
  EII_STEALTH = 33
  EII_LOCK = 34
  //


  is_perf_metrics_available = @(request_mode) false
  get_option_delayed_download_content = @() false
  set_option_delayed_download_content = @(value) null
  get_commander_camera_in_views = @() 0
  set_commander_camera_in_views = @(value) null
})

