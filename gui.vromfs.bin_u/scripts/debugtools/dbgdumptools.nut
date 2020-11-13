// warning disable: -file:forbidden-function

local dbg_dump = require("scripts/debugTools/dbgDump.nut")
local inventoryClient = require("scripts/inventory/inventoryClient.nut")
local g_path = require("std/path.nut")
local dagor_fs = require("dagor.fs")
local unitTypes = require("scripts/unit/unitTypesList.nut")

::debug_dump_unload <- dbg_dump.unload
::debug_dump_is_loaded <- dbg_dump.isLoaded

//==================================================================================================

::debug_dump_debriefing_save <- function debug_dump_debriefing_save(filename = "debug_dump_debriefing.blk")
{
  if (!::debriefing_result || dbg_dump.isLoaded())
    return "IGNORED: No debriefing_result, or dump is loaded."

  local list = [
    { id = "stat_get_exp", value = ::getTblValue("expDump", ::debriefing_result, {}) }
    "get_game_type"
    "get_game_mode"
    "get_current_mission_info_cached"
    { id = "_fake_get_current_mission_desc", value = function() { local b = ::DataBlock(); ::get_current_mission_desc(b); return b } }
    { id = "_fake_mplayers_list", value = ::getTblValue("mplayers_list", ::debriefing_result, []) }
    { id = "dynamic_apply_status", value = ::dynamic_result }
    { id = "get_mission_status", value = ::getTblValue("isSucceed", ::debriefing_result) ? ::MISSION_STATUS_SUCCESS : ::MISSION_STATUS_RUNNING }
    { id = "get_mission_restore_type", value = ::getTblValue("restoreType", ::debriefing_result, 0) }
    { id = "get_local_player_country", value = ::getTblValue("country", ::debriefing_result, "") }
    { id = "get_mp_session_id", value = ::getTblValue("sessionId", ::debriefing_result, ::get_mp_session_id()) }
    { id = "get_mp_tbl_teams", value = ::getTblValue("mpTblTeams", ::debriefing_result, ::get_mp_tbl_teams()) }
    { id = "_fake_sessionlobby_unit_type_mask", value = ::debriefing_result?.unitTypesMask }
    { id = "stat_get_benchmark", value = ::getTblValue("benchmark", ::debriefing_result, ::stat_get_benchmark()) }
    { id = "get_race_winners_count", value = ::getTblValue("numberOfWinningPlaces", ::debriefing_result, 0) }
    { id = "get_race_best_lap_time", value = ::debriefing_result?.exp.ptmBestLap ?? -1 }
    { id = "get_race_lap_times", value = ::debriefing_result?.exp.ptmLapTimesArray ?? [] }
    { id = "get_mp_local_team", value = ::debriefing_result?.localTeam ?? ::get_mp_local_team() }
    { id = "get_player_army_for_hud", value = ::debriefing_result?.friendlyTeam ?? ::get_player_army_for_hud() }
    { id = "_fake_sessionlobby_settings", value = ::SessionLobby.settings }
    { id = "_fake_sessionlobby_last_event_name", value = ::SessionLobby.lastEventName }
    "LAST_SESSION_DEBUG_INFO"
    "get_mission_mode"
    "get_mission_difficulty_int"
    "get_premium_reward_wp"
    "get_premium_reward_xp"
    "is_replay_turned_on"
    "is_replay_present"
    "is_replay_saved"
    "is_worldwar_enabled"
    "ww_is_operation_loaded"
    "ww_get_operation_id"
    "ww_get_operation_winner"
    "ww_get_player_side"
    "havePremium"
    "shop_get_countries_list_with_autoset_units"
    "shop_get_units_list_with_autoset_modules"
    { id = "abandoned_researched_items_for_session", value = [] }
    { id = "get_gamechat_log_text", value = ::getTblValue("chatLog", ::debriefing_result, "") }
    { id = "getLogForBanhammer", value = ::debriefing_result?.logForBanhammer ??  "" }
    { id = "is_multiplayer", value = ::getTblValue("isMp", ::debriefing_result, false) }
    { id = "_fake_battlelog", value = ::HudBattleLog.battleLog }
    { id = "_fake_userlogs", value = ::getTblValue("roomUserlogs", ::debriefing_result, []) }
    { id = "get_user_logs_count", value = ::getTblValue("roomUserlogs", ::debriefing_result, []).len() }
    { id = "_fake_playersInfo", value = ::SquadIcon.playersInfo }
  ]

  local units = []
  local mods  = []
  local exp = ::getTblValue("expDump", ::debriefing_result, {})
  foreach (ut in unitTypes.types)
  {
    local unitId = ::getTblValue("investUnitName" + ut.name, exp, "")
    if (unitId != "")
      units.append([ unitId ])
  }
  foreach (unitId, data in ::getTblValue("aircrafts", exp, {}))
  {
    if (!::getAircraftByName(unitId))
      continue
    units.append([ unitId ])
    local modId = ::getTblValue("investModuleName", data, "")
    if (modId != "")
      mods.append([ unitId, modId ])
  }
  foreach (tbl in ::shop_get_countries_list_with_autoset_units())
  {
    local unitId = ::getTblValue("unit", tbl, "")
    local unit = ::getAircraftByName(unitId)
    local args = [ ::getUnitCountry(unit), ::get_es_unit_type(unit) ]
    foreach (id in [ "shop_get_researchable_unit_name", "shop_get_country_excess_exp" ])
      list.append({ id = id, args = args })
    units.append([ unitId ])
  }
  foreach (tbl in ::shop_get_units_list_with_autoset_modules())
    mods.append([ ::getTblValue("name", tbl, ""), ::getTblValue("mod", tbl, "") ])
  foreach (args in units)
    foreach (id in [ "shop_is_player_has_unit", "shop_is_aircraft_purchased", "shop_unit_research_status",
      "shop_get_researchable_module_name", "shop_get_unit_exp", "shop_get_unit_excess_exp",
      "shop_is_unit_rented", "rented_units_get_expired_time_sec" ])
        list.append({ id = id, args = args })
  foreach (args in mods)
    foreach (id in [ "shop_is_modification_enabled", "shop_is_modification_purchased",
      "shop_get_module_research_status", "shop_get_module_exp" ])
        list.append({ id = id, args = args })

  dbg_dump.save(filename, list)
  return "Debriefing result saved to " + filename
}

::debug_dump_debriefing_load <- function debug_dump_debriefing_load(filename = "debug_dump_debriefing.blk", onUnloadFunc = null)
{
  if (!dbg_dump.load(filename))
    return "File not found: " + filename

  dbg_dump.loadFuncs({
    is_user_log_for_current_room = function(idx) { return true }
    get_user_log_blk_body = @(idx, outBlk) outBlk.setFrom(::_fake_userlogs?[idx] ?? ::DataBlock())
    get_user_log_time_sec = function(idx) { return ::get_charserver_time_sec() }
    disable_user_log_entry = function(idx) { if (idx in ::_fake_userlogs) ::_fake_userlogs[idx].disabled = true }
    shown_userlog_notifications = []
    autosave_replay = @() null
    on_save_replay = @(fn) true
    is_era_available = function(...) { return true }
    get_current_mission_desc = @(outBlk) outBlk.setFrom(
      ::getroottable()?._fake_get_current_mission_desc ?? ::get_current_mission_info_cached())
    get_mplayers_list = function(team, full) {
      local res = []
      foreach (v in ::_fake_mplayers_list)
        if (team == ::GET_MPLAYERS_LIST || v.team == team)
          res.append(v)
      return (res)
    }
    get_local_mplayer = function() {
      foreach (v in ::_fake_mplayers_list)
        if (v.isLocal)
          return v
      return dbg_dump.getOriginal("get_local_mplayer")()
    }
    is_unlocked = function(unlockType, unlockId) {
      foreach (log in ::_fake_userlogs)
        if (log?.body.unlockId == unlockId)
          return true
      return dbg_dump.getOriginal("is_unlocked")(unlockType, unlockId)
    }
  }, false)

  ::SessionLobby.settings = ::_fake_sessionlobby_settings
  ::SessionLobby.playersInfo = ::getroottable()?._fake_playersInfo ?? {}
  ::SessionLobby.getUnitTypesMask = @() ::getroottable()?._fake_sessionlobby_unit_type_mask ?? 0
  ::SessionLobby.lastEventName = ::getroottable()?._fake_sessionlobby_last_event_name ?? ""
  ::HudBattleLog.battleLog = ::_fake_battlelog
  ::SquadIcon.initListLabelsSquad()

  local _is_in_flight = ::is_in_flight
  ::is_in_flight = function() { return true }
  ::g_mis_custom_state.isCurRulesValid = false
  ::g_mis_custom_state.getCurMissionRules()
  ::is_in_flight = _is_in_flight

  ::gui_start_debriefingFull()
  ::checkNonApprovedResearches(true)
  ::go_debriefing_next_func = function() { dbg_dump.unload(); ::gui_start_mainmenu(); onUnloadFunc?() }
  ::broadcastEvent("SessionDestroyed")
  return "Debriefing result loaded from " + filename
}

::debug_dump_debriefing_batch_load <- function debug_dump_debriefing_batch_load()
{
  local skyquakePath = ::debug_get_skyquake_path()
  local filesList = dagor_fs.scan_folder({ root = $"{skyquakePath}/gameOnline",
    files_suffix = "*.blk", recursive = false, vromfs=false, realfs = true
  }).filter(@(v) v.indexof("debug_dump_debriefing") != null).map(@(v) g_path.fileName(v)).sort().reverse()
  local total = filesList.len()
  local function loadNext() {
    local count = filesList.len()
    if (!count) return
    local filename = filesList.pop()
    dlog(::format("[%d/%d] %s", total - count + 1, total, filename))
    ::copy_to_clipboard(filename)
    ::debug_dump_debriefing_load(filename, loadNext)
  }
  loadNext()
}

//==================================================================================================

::debug_dump_mpstatistics_save <- function debug_dump_mpstatistics_save(filename = "debug_dump_mpstatistics.blk")
{
  dbg_dump.save(filename, [
    { id = "_fake_mplayers_list", value = ::get_mplayers_list(::GET_MPLAYERS_LIST, true) }
    { id = "_fake_playersInfo", value = ::SessionLobby.playersInfo }
    { id = "_fake_get_current_mission_desc", value = function() { local b = ::DataBlock(); ::get_current_mission_desc(b); return b } }
    "LAST_SESSION_DEBUG_INFO"
    "get_game_type"
    "get_game_mode"
    "is_in_flight"
    "get_player_army_for_hud"
    "get_mp_local_team"
    "get_mp_tbl_teams"
    "get_mp_session_info"
    "get_mp_kick_countdown"
    "get_mp_rounds"
    "get_mp_current_round"
    "get_mp_zone_countdown"
    "get_mp_ffa_score_limit"
    "get_mission_difficulty"
    "get_mission_difficulty_int"
    "get_current_mission_info_cached"
    "get_multiplayer_time_left"
    "is_race_started"
    "get_race_checkpioints_count"
    "get_race_winners_count"
  ])
  return "Saved " + filename
}

::debug_dump_mpstatistics_load <- function debug_dump_mpstatistics_load(filename = "debug_dump_mpstatistics.blk")
{
  if (!dbg_dump.load(filename))
    return "File not found: " + filename
  dbg_dump.loadFuncs({
    get_current_mission_desc = @(outBlk) outBlk.setFrom(::_fake_get_current_mission_desc)
    get_mplayers_list = function(team, full) {
      return ::u.filter(::_fake_mplayers_list, @(p) p.team == team || team == ::GET_MPLAYERS_LIST)
    }
    get_mplayer_by_id = function(id) {
      return ::u.search(::_fake_mplayers_list, @(p) p.id == id)
    }
    get_local_mplayer = function() {
      return ::u.search(::_fake_mplayers_list, @(p) p.isLocal) ?? dbg_dump.getOriginal("get_local_mplayer")()
    }
  }, false)
  ::SessionLobby.playersInfo = ::getroottable()?._fake_playersInfo ?? {}
  ::gui_start_mpstatscreen()
  return "Loaded " + filename
}

//==================================================================================================

::debug_dump_respawn_save <- function debug_dump_respawn_save(filename = "debug_dump_respawn.blk")
{
  local handler = ::handlersManager.findHandlerClassInScene(::gui_handlers.RespawnHandler)
  if (!handler || dbg_dump.isLoaded())
    return "IGNORED: Handler not found, or dump is loaded."

  local list = [
    { id = "_fake_mplayers_list", value = ::get_mplayers_list(::GET_MPLAYERS_LIST, true) }
    { id = "_fake_get_current_mission_desc", value = function() { local b = ::DataBlock();
      ::get_current_mission_desc(b); return b } }
    { id = "get_user_custom_state", args = [ ::my_user_id_int64, false ] }
    { id = "_fake_mpchat_log", value = ::require("scripts/chat/mpChatModel.nut").getLog() }
    "LAST_SESSION_DEBUG_INFO"
    "get_game_type"
    "get_game_mode"
    "get_current_mission_info_cached"
    "has_available_slots"
    "get_local_player_country"
    "get_profile_country_sq"
    "get_crew_info"
    "get_respawns_left"
    "stay_on_respawn_screen"
    "dgs_get_game_params"
    "fetch_change_aircraft_on_start"
    "is_hud_visible"
    "is_menu_state"
    "get_cur_rank_info"
    "get_cur_warpoints"
    "is_has_multiplayer"
    "get_option_gun_target_dist"
    "get_option_bomb_activation_type"
    "get_option_bomb_activation_time"
    "get_bomb_activation_auto_time"
    "get_option_depthcharge_activation_time"
    "get_option_mine_depth"
    "get_option_rocket_fuse_dist"
    "get_objectives_list"
    "is_in_flight"
    "get_player_army_for_hud"
    "get_mp_local_team"
    "get_mp_tbl_teams"
    "get_mp_session_info"
    "get_mp_kick_countdown"
    "get_mp_rounds"
    "get_mp_current_round"
    "get_mp_zone_countdown"
    "get_mp_ffa_score_limit"
    "get_mission_difficulty"
    "get_mission_difficulty_int"
    "get_cd_base_difficulty"
    "get_multiplayer_time_left"
    "is_race_started"
    "get_race_checkpioints_count"
    "get_race_winners_count"
    "last_ca_aircraft"
    "used_planes"
    "g_mis_loading_state.curState"
    "HudBattleLog.battleLog"
  ]

  foreach(id in ::SessionLobby[PERSISTENT_DATA_PARAMS])
    list.append("SessionLobby." + id)

  foreach(crew in ::get_crews_list_by_country(::get_local_player_country()))
  {
    local unit = ::g_crew.getCrewUnit(crew)
    if (unit)
    {
      foreach (id in [ "get_last_weapon", "get_slot_delay", "get_unit_wp_to_respawn",
        "get_max_spawns_unit_count", "shop_unit_research_status", "shop_is_player_has_unit",
        "shop_is_aircraft_purchased", "wp_get_cost", "wp_get_cost_gold", "get_aircraft_max_fuel" ])
        list.append({ id = id, args = [ unit.name ] })
      list.append({ id = "get_available_respawn_bases", args = [ unit.tags ] })
      list.append({ id = "shop_get_spawn_score", args = [ unit.name, "" ] })
      list.append({ id = "is_crew_slot_was_ready_at_host", args = [ crew.idInCountry, unit.name, false ] })
      list.append({ id = "get_aircraft_fuel_consumption", args = [ unit.name, ::get_mission_difficulty(), true ] })

      foreach (weapon in unit.weapons)
      {
        foreach (id in [ "shop_get_spawn_score", "wp_get_cost2", "wp_get_cost_gold2",
          "shop_is_weapon_purchased", "shop_get_weapon_baseval" ])
          list.append({ id = id, args = [ unit.name, weapon.name ] })
        list.append({ id = "shop_is_weapon_available", args = [ unit.name, weapon.name, true, false ] })
      }
    }
    foreach (id in [ "is_spare_aircraft_in_slot", "get_slot_delay_by_slot", "get_num_used_unit_spawns" ])
      list.append({ id = id, args = [ crew.idInCountry ] })
    list.append({ id = "is_crew_available_in_session", args = [ crew.idInCountry, false ] })
  }

  dbg_dump.save(filename, list)
  return "Saved " + filename
}

::debug_dump_respawn_load <- function debug_dump_respawn_load(filename = "debug_dump_respawn.blk")
{
  if (!dbg_dump.load(filename))
    return "File not found: " + filename
  dbg_dump.loadFuncs({
    get_current_mission_desc = @(outBlk) outBlk.setFrom(::_fake_get_current_mission_desc)
    get_mplayers_list = @(team, full) ::_fake_mplayers_list.filter(
      @(p) p.team == team || team == ::GET_MPLAYERS_LIST)
    get_mplayer_by_id = @(id) ::_fake_mplayers_list.filter(@(p) p.id == id)?[0]
    get_local_mplayer = @() ::_fake_mplayers_list.filter(@(p) p.isLocal)?[0]
    request_aircraft_and_weapon = @(...) -1
  }, false)
  ::g_mis_custom_state.isCurRulesValid = false
  ::g_mis_custom_state.getCurMissionRules()
  ::g_crews_list.crewsList = []
  ::SquadIcon.initListLabelsSquad()
  ::require("scripts/chat/mpChatModel.nut")?.setLog(::_fake_mpchat_log)
  ::gui_start_respawn()
  ::broadcastEvent("MpChatLogUpdated")
  ::broadcastEvent("BattleLogMessage")
  return "Loaded " + filename
}

//==================================================================================================

::debug_dump_userlogs_save <- function debug_dump_userlogs_save(filename = "debug_dump_userlogs.blk")
{
  local userlogs = []
  for (local i = 0; i < ::get_user_logs_count(); i++) {
    local blk = ::DataBlock()
    ::get_user_log_blk_body(i, blk)
    userlogs.append(blk)
  }
  dbg_dump.save(filename, [
    { id = "_fake_userlogs", value = userlogs }
  ])
  return "Saved " + filename
}

::debug_dump_userlogs_load <- function debug_dump_userlogs_load(filename = "debug_dump_userlogs.blk")
{
  if (!dbg_dump.load(filename))
    return "File not found: " + filename
  dbg_dump.loadFuncs({
    get_user_logs_count = function() { return ::_fake_userlogs.len() }
    is_user_log_for_current_room = function(idx) { return ::SessionLobby.roomId && ::SessionLobby.roomId == ::_fake_userlogs?[idx]?.roomId }
    get_user_log_blk_body = @(idx, outBlk) outBlk.setFrom(::_fake_userlogs?[idx] ?? ::DataBlock())
    get_user_log_time_sec = function(idx) { return ::_fake_userlogs?[idx]?.timeStamp ?? 0 }
    disable_user_log_entry = function(idx) { if (idx in ::_fake_userlogs) ::_fake_userlogs[idx].disabled = true }
    shown_userlog_notifications = []
  }, false)
  return "Loaded " + filename
}

//==================================================================================================

::debug_dump_inventory_save <- function debug_dump_inventory_save(filename = "debug_dump_inventory.blk")
{
  dbg_dump.save(filename, [
    { id = "_inventoryClient_items",    value = inventoryClient.items }
    { id = "_inventoryClient_itemdefs", value = inventoryClient.itemdefs }
  ])
  return "Saved " + filename
}

::debug_dump_inventory_load <- function debug_dump_inventory_load(filename = "debug_dump_inventory.blk")
{
  if (!dbg_dump.load(filename))
    return "File not found: " + filename
  dbg_dump.loadFuncs({
    inventory = { request  = @(...) null }
  }, false)
  inventoryClient.itemdefs = ::_inventoryClient_itemdefs
  inventoryClient.items    = ::_inventoryClient_items
  ::broadcastEvent("ItemDefChanged")
  ::broadcastEvent("ExtInventoryChanged")
  return "Loaded " + filename
}

//==================================================================================================

::debug_debriefing_result_dump_save <- ::debug_dump_debriefing_save // old names
::debug_debriefing_result_dump_load <- ::debug_dump_debriefing_load // old names
