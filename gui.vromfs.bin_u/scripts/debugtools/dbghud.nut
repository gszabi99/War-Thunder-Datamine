::dbg_msg_obj_counter <- 0
::hud_message_objective_debug <- function hud_message_objective_debug(show = true, alwaysShow = false, id = -1)
{
  ::g_hud_event_manager.onHudEvent("HudMessage", {
    type = ::HUD_MSG_OBJECTIVE
    text = "Main center notification number " + dbg_msg_obj_counter++
    id = id
    alwaysShow = alwaysShow
    show = show
  })
}

::dbg_player_damage_counter <- 0
::dbg_player_damage_messages <- [
  "HUD_CAN_NOT_REPAIR",
  "NET_PROTOCOL_VERSION_MISMATCH",
  "hud_tank_engine_damaged",
  "hud_gun_barrel_exploded"
]
::hud_message_player_damage_debug <- function hud_message_player_damage_debug(id = -1)
{
  ::g_hud_event_manager.onHudEvent("HudMessage", {
    type = HUD_MSG_DAMAGE
    text = ::loc(dbg_player_damage_messages[(::math.frnd() * dbg_player_damage_messages.len()).tointeger()])
    id = id
  })
}

::KillLogMessageDebugCounter <- 0
::hud_message_kill_log_debug <- function hud_message_kill_log_debug()
{
  ::g_hud_event_manager.onHudEvent("HudMessage", {
    type = ::HUD_MSG_MULTIPLAYER_DMG
    isKill=true
    action="kill"
    playerId=-1
    unitName=""
    unitType=""
    unitNameLoc="Friend" + ::KillLogMessageDebugCounter
    team=::get_player_army_for_hud()
    victimPlayerId=-1
    victimUnitName=""
    victimUnitType =""
    victimUnitNameLoc="Enemy" + ::KillLogMessageDebugCounter++
    victimTeam=-1
  })
}

::hud_zone_capture_event_hero_captures_zone <- function hud_zone_capture_event_hero_captures_zone()
{
  ::g_hud_event_manager.onHudEvent("zoneCapturingEvent", {
    text = ::loc("NET_YOU_CAPTURING_LA")
    eventId = ::MISSION_CAPTURING_ZONE
    isMyTeam = true
    isHeroAction = true
    zoneName = "A"
    captureProgress = 0.7
  })
}

::hud_zone_capture_event_hero_uncaptures_zone <- function hud_zone_capture_event_hero_uncaptures_zone()
{
  ::g_hud_event_manager.onHudEvent("zoneCapturingEvent", {
    text = ::loc("NET_TEAM_A_CAPTURING_STOP_LA")
    eventId = ::MISSION_CAPTURING_ZONE
    isMyTeam = true
    isHeroAction = true
    zoneName = "A"
    captureProgress = -0.7
  })
}

::hud_zone_capture_event_allay_captures_zone <- function hud_zone_capture_event_allay_captures_zone()
{
  ::g_hud_event_manager.onHudEvent("zoneCapturingEvent", {
    text = ::loc("NET_TEAM_A_CAPTURED_LA")
    isHeroAction = false
    isMyTeam = true
    zoneName = "A"
  })
}

::hud_reward_message_debug <- function hud_reward_message_debug()
{

  ::g_hud_event_manager.onHudEvent("InBattleReward", {
    warpoints = 100
    experience = 100
    messageCode = ::EXP_EVENT_CRITICAL_HIT
    counter = 1
  })
}

::hud_debug_streak <- function hud_debug_streak(streakId = null)
{
  if (!streakId)
  {
    local list = ::u.filter(::g_unlocks.getAllUnlocks(),
                   function(blk) { return blk?.type == "streak" &&  !blk?.hidden })
    streakId = list[::math.rnd() % list.len()].id
  }

  local header = ::get_loc_for_streak(::SNT_MY_STREAK_HEADER, streakId, ::math.rnd() % 3)
  local wp = ::math.rnd() % 5000
  ::add_streak_message(header, wp, 0, streakId)
}

::hud_mission_result_debug <- function hud_mission_result_debug(result = ::GO_WIN, checkResending = false, noLives = false)
{
  ::g_hud_event_manager.onHudEvent("MissionResult", {resultNum = result,
                                                     checkResending = checkResending,
                                                     noLives = noLives})
}

::hud_show_in_battle_time_to_kick_timer <- function hud_show_in_battle_time_to_kick_timer()
{
  local time = ::get_mp_kick_countdown() + 5000
  ::get_mp_kick_countdown <- (@(time) function() { return time })(time)
  ::in_battle_time_to_kick_show_timer <- ::get_mp_kick_countdown()
}

::hud_show_in_battle_time_to_kick_alert <- function hud_show_in_battle_time_to_kick_alert()
{
  ::get_mp_kick_countdown <- function() { return ::math.rnd() % 5000 }
  ::in_battle_time_to_kick_show_alert <- ::get_mp_kick_countdown()
}

::hud_reset_in_battle_time_to_kick <- function hud_reset_in_battle_time_to_kick()
{
  local gmSettingsBlk = ::get_game_settings_blk()
  ::in_battle_time_to_kick_show_timer = gmSettingsBlk?.time_to_kick.in_battle_show_timer_threshold ?? 150
  ::in_battle_time_to_kick_show_alert = gmSettingsBlk?.time_to_kick.in_battle_show_alert_threshold ?? 50
}

::hud_show_tutorial_obj <- function hud_show_tutorial_obj(id, show = true)
{
  ::g_hud_tutorial_elements.onElementToggle({ element = id, show = show })
}

::test_hint_start_bailout <- function test_hint_start_bailout() {
  ::g_hud_event_manager.onHudEvent("hint:bailout:startBailout", {
    lifeTime = 15
    offenderName = ""
  })
}

::test_hint_offer_bailout <- function test_hint_offer_bailout() {
  ::g_hud_event_manager.onHudEvent("hint:bailout:offerBailout", {})
}

::test_hint_stop <- function test_hint_stop() {
  ::g_hud_event_manager.onHudEvent("hint:bailout:notBailouts", {})
}

::test_hint_skip_xray_shot <- function test_hint_skip_xray_shot()
{
  ::g_hud_event_manager.onHudEvent("hint:xrayCamera:showSkipHint", {})
}

::text_hint_mission_hint_zoom <- function text_hint_mission_hint_zoom()
{
  ::g_hud_event_manager.onHudEvent("hint:missionHint:set", {
    shortcuts = [
      "@ID_ZOOM",
      "ID_ZOOM_TOGGLE",
      "@zoom=max",
    ]
    priority = 0
    locId = "hints/tutorialB_zoom_in"
  })
}
