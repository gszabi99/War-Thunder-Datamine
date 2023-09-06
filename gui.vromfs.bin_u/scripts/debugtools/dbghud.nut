//checked for plus_string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

let { frnd, rnd } = require("dagor.random")
let { HUD_MSG_OBJECTIVE, HUD_MSG_DAMAGE, HUD_MSG_MULTIPLAYER_DMG } = require("hudMessages")
let { getAllUnlocks } = require("%scripts/unlocks/unlocksCache.nut")


let { GO_WIN, MISSION_CAPTURING_ZONE } = require("guiMission")
let { register_command } = require("console")

local dbg_msg_obj_counter = 0
let function hud_message_objective_debug(show = true, alwaysShow = false) {
  ::g_hud_event_manager.onHudEvent("HudMessage", {
    type = HUD_MSG_OBJECTIVE
    text = $"Main center notification number {dbg_msg_obj_counter}"
    id = dbg_msg_obj_counter
    alwaysShow = alwaysShow
    show = show
  })
  dbg_msg_obj_counter++
}

local dbg_player_damage_counter = 0
let dbg_player_damage_messages = [
  "HUD_CAN_NOT_REPAIR",
  "NET_PROTOCOL_VERSION_MISMATCH",
  "hud_tank_engine_damaged",
  "hud_gun_barrel_exploded"
]
let function hud_message_player_damage_debug() {
  ::g_hud_event_manager.onHudEvent("HudMessage", {
    type = HUD_MSG_DAMAGE
    text = loc(dbg_player_damage_messages[(frnd() * dbg_player_damage_messages.len()).tointeger()])
    id = dbg_player_damage_counter++
  })
}

local killLogMessageDebugCounter = 0
let function hud_message_kill_log_debug() {
  ::g_hud_event_manager.onHudEvent("HudMessage", {
    type = HUD_MSG_MULTIPLAYER_DMG
    isKill = true
    action = "kill"
    playerId = -1
    unitName = ""
    unitType = ""
    unitNameLoc = $"Friend{killLogMessageDebugCounter}"
    team = ::get_player_army_for_hud()
    victimPlayerId = -1
    victimUnitName = ""
    victimUnitType = ""
    victimUnitNameLoc = $"Enemy{killLogMessageDebugCounter}"
    victimTeam = -1
  })
  killLogMessageDebugCounter++
}

let function hud_zone_capture_event_hero_captures_zone() {
  ::g_hud_event_manager.onHudEvent("zoneCapturingEvent", {
    text = loc("NET_YOU_CAPTURING_LA")
    eventId = MISSION_CAPTURING_ZONE
    isMyTeam = true
    isHeroAction = true
    zoneName = "A"
    captureProgress = 0.7
  })
}

let function hud_zone_capture_event_hero_uncaptures_zone() {
  ::g_hud_event_manager.onHudEvent("zoneCapturingEvent", {
    text = loc("NET_TEAM_A_CAPTURING_STOP_LA")
    eventId = MISSION_CAPTURING_ZONE
    isMyTeam = true
    isHeroAction = true
    zoneName = "A"
    captureProgress = -0.7
  })
}

let function hud_zone_capture_event_allay_captures_zone() {
  ::g_hud_event_manager.onHudEvent("zoneCapturingEvent", {
    text = loc("NET_TEAM_A_CAPTURED_LA")
    isHeroAction = false
    isMyTeam = true
    zoneName = "A"
  })
}

let function hud_reward_message_debug() {
  ::g_hud_event_manager.onHudEvent("InBattleReward", {
    warpoints = 100
    experience = 100
    messageCode = EXP_EVENT_CRITICAL_HIT
    counter = 1
  })
}

let function hud_debug_streak(streakId = null) {
  if (!streakId) {
    let list = u.filter(getAllUnlocks(),
                   function(blk) { return blk?.type == "streak" &&  !blk?.hidden })
    streakId = list[rnd() % list.len()].id
  }

  let header = ::get_loc_for_streak(SNT_MY_STREAK_HEADER, streakId, rnd() % 3)
  let wp = rnd() % 5000
  ::add_streak_message(header, wp, 0, streakId)
}

let function hud_mission_result_debug(result = GO_WIN, checkResending = false, noLives = false) {
  ::g_hud_event_manager.onHudEvent("MissionResult", { resultNum = result,
                                                     checkResending = checkResending,
                                                     noLives = noLives })
}

let function hud_show_in_battle_time_to_kick_timer() {
  let time = ::get_mp_kick_countdown() + 5000
  ::get_mp_kick_countdown <- @() time
  ::in_battle_time_to_kick_show_timer <- ::get_mp_kick_countdown()
}

let function hud_show_in_battle_time_to_kick_alert() {
  ::get_mp_kick_countdown <- @() rnd() % 5000
  ::in_battle_time_to_kick_show_alert <- ::get_mp_kick_countdown()
}

let function hud_reset_in_battle_time_to_kick() {
  let gmSettingsBlk = ::get_game_settings_blk()
  ::in_battle_time_to_kick_show_timer = gmSettingsBlk?.time_to_kick.in_battle_show_timer_threshold ?? 150
  ::in_battle_time_to_kick_show_alert = gmSettingsBlk?.time_to_kick.in_battle_show_alert_threshold ?? 50
}

let function hud_show_tutorial_obj(id, show) {
  ::g_hud_tutorial_elements.onElementToggle({ element = id, show = show })
}

let function test_hint_start_bailout() {
  ::g_hud_event_manager.onHudEvent("hint:bailout:startBailout", {
    lifeTime = 15
    offenderName = ""
  })
}

let function test_hint_offer_bailout() {
  ::g_hud_event_manager.onHudEvent("hint:bailout:offerBailout", {})
}

let function test_hint_stop() {
  ::g_hud_event_manager.onHudEvent("hint:bailout:notBailouts", {})
}

let function test_hint_skip_xray_shot() {
  ::g_hud_event_manager.onHudEvent("hint:xrayCamera:showSkipHint", {})
}

let function text_hint_mission_hint_zoom() {
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

register_command(hud_message_objective_debug, "debug.hud.message_objective_debug")
register_command(hud_message_player_damage_debug, "debug.hud.message_player_damage_debug")
register_command(hud_message_kill_log_debug, "debug.hud.message_kill_log_debug")
register_command(hud_zone_capture_event_hero_captures_zone, "debug.hud.zone_capture_event_hero_captures_zone")
register_command(hud_zone_capture_event_hero_uncaptures_zone, "debug.hud.zone_capture_event_hero_uncaptures_zone")
register_command(hud_zone_capture_event_allay_captures_zone, "debug.hud.zone_capture_event_allay_captures_zone")
register_command(hud_reward_message_debug, "debug.hud.reward_message_debug")
register_command(hud_debug_streak, "debug.hud.debug_streak")
register_command(@() hud_debug_streak(), "debug.hud.debug_random_streak")
register_command(hud_mission_result_debug, "debug.hud.mission_result_debug")
register_command(hud_show_in_battle_time_to_kick_timer, "debug.hud.show_in_battle_time_to_kick_timer")
register_command(hud_show_in_battle_time_to_kick_alert, "debug.hud.show_in_battle_time_to_kick_alert")
register_command(hud_reset_in_battle_time_to_kick, "debug.hud.reset_in_battle_time_to_kick")
register_command(hud_show_tutorial_obj, "debug.hud.show_tutorial_obj")
register_command(test_hint_start_bailout, "debug.hud.test_hint_start_bailout")
register_command(test_hint_offer_bailout, "debug.hud.test_hint_offer_bailout")
register_command(test_hint_stop, "debug.hud.test_hint_stop")
register_command(test_hint_skip_xray_shot, "debug.hud.test_hint_skip_xray_shot")
register_command(text_hint_mission_hint_zoom, "debug.hud.text_hint_mission_hint_zoom")

return {
  hud_message_objective_debug
  hud_message_player_damage_debug
  hud_message_kill_log_debug
  hud_debug_streak
}