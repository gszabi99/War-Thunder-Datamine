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

//----------------------------wop_1_91_0_X---------------------------------//
::apply_compatibilities({
    XBOX_COMMUNICATIONS_MUTED = 3
    EII_HULL_AIMING = -1
    get_option_use_rectangular_radar_indicator = @() false
    set_option_use_rectangular_radar_indicator = @(b) null
})

//----------------------------wop_1_93_0_X---------------------------------//
::apply_compatibilities({
  OPTION_FIX_GUN_IN_MOUSE_LOOK = -1
  OPTION_SHOW_COMPASS_IN_TANK_HUD = -1
  function shop_get_premium_account_ent_name() {return "PremiumAccount"}
  ww_get_load_army_to_transport_error = @() ""
  ww_get_unload_army_from_transport_error = @() ""
  ww_get_army_override_icon = @(overrideIcon, loadedArmyTypeStr, isAtillery) ""
  ww_get_loaded_army_type = @(armyName, isReinforcement) ""
  ww_get_loaded_transport = @(blk) blk
  AUT_None = -1
  AUT_ArtilleryFire = 0
  AUT_TransportLoad = 1
  AUT_TransportUnload = 2
  ww_get_curr_action_type = @() ::AUT_None
  ww_set_curr_action_type = @(modeType) null
  get_allow_to_be_added_to_lb = @() true
  set_allow_to_be_added_to_lb = @(val) null
  get_allow_to_be_added_to_contacts = @() true
  set_allow_to_be_added_to_contacts = @(val) null
  is_hdr_available = @() true
})
//----------------------------wop_1_95_0_X---------------------------------//
::apply_compatibilities({
  OPTION_ENABLE_SOUND_SPEED = 255
  TARGET_HUE_HELICOPTER_MFD = 9
  get_aircraft_crew_blk = @(crewId, unitName) ::get_aircraft_crew_by_id(crewId)
  ps4_update_purchases_on_auth = @() null
  get_option_indicatedSpeedType = @() ::get_option_indicatedSpeed()
  set_option_indicatedSpeedType = function(value)
  {
    if (value > 1)
      ::set_option_indicatedSpeed(0)
    else
      ::set_option_indicatedSpeed(value)
  }
  get_thermovision_index = @() 0
  set_thermovision_index = @(idx) null
  UT_SuitVehicle = 14
})
//----------------------------wop_1_97_0_X---------------------------------//
::apply_compatibilities({
  OPTION_PITCH_BLOCKER_WHILE_BRACKING = -1
  need_force_autologin = @() false
  request_leaderboard_blk = function(blk) {
    if (blk?.start != null)
    {
      return ::request_page_of_leaderboard(
        blk.valueType == LEADERBOARD_VALUE_INHISTORY? ::ETTI_VALUE_INHISORY : ETTI_VALUE_TOTAL,
        blk.category,
        blk.count,
        blk.start,
        blk.gameMode
      )
    }

    return ::request_me_in_leaderboard(
      blk.valueType == LEADERBOARD_VALUE_INHISTORY? ::ETTI_VALUE_INHISORY : ETTI_VALUE_TOTAL,
      blk.category,
      0,
      blk.gameMode
    )
  }
})
//----------------------------wop_1_97_1_X---------------------------------//
::have_per_vehicle_zoom_sens <- "OPTION_GUNNER_VIEW_ZOOM_SENS" in ::getroottable()
                             && "OPTION_ATGM_AIM_ZOOM_SENS_HELICOPTER" in ::getroottable()
::apply_compatibilities({
  request_voice_message_list = @(...) null
  is_last_voice_message_list_for_squad = @() false
  TP_PS4 = 7
  CONTROLS_ALLOW_ENGINE_AUTOSTART = false
})
//----------------------------wop_1_97_2_X---------------------------------//
::apply_compatibilities({
  YU2_PAY_GJN = 32
  YU2_FORBIDDEN_NEED_2STEP = 32
})

