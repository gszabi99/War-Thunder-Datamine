// warning disable: -file:forbidden-function
from "%scripts/dagui_natives.nut" import shop_get_units_list_with_autoset_modules, get_player_army_for_hud, get_user_logs_count, get_local_player_country, get_user_log_blk_body, copy_to_clipboard, shop_get_countries_list_with_autoset_units
from "%scripts/dagui_library.nut" import *

let { eventbus_send } = require("eventbus")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { clearCrewsList } = require("%scripts/slotbar/crewsList.nut")
let DataBlock  = require("DataBlock")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { DBGLEVEL } = require("dagor.system")
if (DBGLEVEL <= 0)
  return

let { g_mis_loading_state } = require("%scripts/respawn/misLoadingState.nut")
let { HudBattleLog } = require("%scripts/hud/hudBattleLog.nut")
let { get_mp_session_id_str } = require("multiplayer")
let dbg_dump = require("%scripts/debugTools/dbgDump.nut")
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")
let g_path = require("%sqstd/path.nut")
let dagor_fs = require("dagor.fs")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getDebriefingResult, getDynamicResult, gatherDebriefingResult
} = require("%scripts/debriefing/debriefingFull.nut")
let { guiStartDebriefingFull } = require("%scripts/debriefing/debriefingModal.nut")
let { getPlayersInfo, initListLabelsSquad } = require("%scripts/statistics/squadIcon.nut")
let { guiStartMPStatScreen } = require("%scripts/statistics/mpStatisticsUtil.nut")
let { havePremium } = require("%scripts/user/premium.nut")
let { register_command } = require("console")
let { debug_get_skyquake_path } = require("%scripts/debugTools/dbgUtils.nut")
let { get_game_mode, get_game_type, get_mplayers_list, GET_MPLAYERS_LIST } = require("mission")
let { get_mission_difficulty, stat_get_benchmark,
  get_mp_tbl_teams, get_current_mission_desc } = require("guiMission")
let { get_charserver_time_sec } = require("chard")
let { getUnitCountry } = require("%scripts/unit/unitInfo.nut")
let { getEsUnitType } = require("%scripts/unit/unitParams.nut")
let { get_current_mission_info_cached } = require("blkGetters")
let { userIdInt64 } = require("%scripts/user/profileStates.nut")
let { wwGetOperationId, wwGetPlayerSide, wwIsOperationLoaded,
  wwGetOperationWinner } = require("worldwar")
let { curMissionRulesInvalidate, getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let { getCrewsListByCountry } = require("%scripts/slotbar/slotbarState.nut")
let { getCrewUnit } = require("%scripts/crew/crew.nut")
let { setGameChatLogText } = require("%scripts/chat/mpChat.nut")
let { getMpChatLog, setMpChatLog } = require("%scripts/chat/mpChatState.nut")
let { isWorldWarEnabled } = require("%scripts/globalWorldWarScripts.nut")
let { checkNonApprovedResearches } = require("%scripts/researches/researchActions.nut")
let { getSessionLobbyRoomId, getSessionLobbySettings, getSessionLobbyPlayersInfo
} = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { getRoomEvent } = require("%scripts/matchingRooms/sessionLobbyInfo.nut")

//==================================================================================================
let get_fake_userlogs = memoize(@() getroottable()?["_fake_userlogs"] ?? {})
let get_fake_mplayers_list = memoize(@() getroottable()?["_fake_mplayers_list"] ?? {})
//let get_fake_sessionlobby_settings = memoize(@() getroottable()?["_fake_sessionlobby_settings"] ?? {})
//let get_fake_battlelog = memoize(@() getroottable()?["_fake_battlelog"] ?? {})

function debug_dump_debriefing_save(filename) {
  let debriefingResult = getDebriefingResult()
  if (!debriefingResult || dbg_dump.isLoaded())
    return "IGNORED: No debriefingResult, or dump is loaded."

  let list = [
    { id = "stat_get_exp", value = getTblValue("expDump", debriefingResult, {}) }
    { id = "get_game_type", value = debriefingResult?.gameType ?? get_game_type() }
    { id = "get_game_mode", value = debriefingResult?.gm ?? get_game_mode() }
    "get_current_mission_info_cached"
    { id = "_fake_get_current_mission_desc", value = function() { let b = DataBlock(); get_current_mission_desc(b); return b } }
    { id = "_fake_mplayers_list", value = getTblValue("mplayers_list", debriefingResult, []) }
    { id = "dynamic_apply_status", value = getDynamicResult() }
    { id = "get_mission_status", value = getTblValue("isSucceed", debriefingResult) ? MISSION_STATUS_SUCCESS : MISSION_STATUS_RUNNING }
    { id = "get_mission_restore_type", value = getTblValue("restoreType", debriefingResult, 0) }
    { id = "get_local_player_country", value = getTblValue("country", debriefingResult, "") }
    { id = "get_mp_session_id", value = getTblValue("sessionId", debriefingResult, get_mp_session_id_str()) }
    { id = "get_mp_tbl_teams", value = getTblValue("mpTblTeams", debriefingResult, get_mp_tbl_teams()) }
    { id = "_fake_sessionlobby_unit_type_mask", value = debriefingResult?.unitTypesMask }
    { id = "stat_get_benchmark", value = getTblValue("benchmark", debriefingResult, stat_get_benchmark()) }
    { id = "get_race_winners_count", value = getTblValue("numberOfWinningPlaces", debriefingResult, 0) }
    { id = "get_race_best_lap_time", value = debriefingResult?.exp.ptmBestLap ?? -1 }
    { id = "get_race_lap_times", value = debriefingResult?.exp.ptmLapTimesArray ?? [] }
    { id = "get_player_army_for_hud", value = debriefingResult?.friendlyTeam ?? get_player_army_for_hud() }
    { id = "_fake_sessionlobby_settings", value = getSessionLobbySettings() }
    { id = "_fake_sessionlobby_last_event_name", value = getRoomEvent()?.name ?? "" }
    "LAST_SESSION_DEBUG_INFO"
    "get_mission_mode"
    "get_mission_difficulty_int"
    "get_premium_reward_wp"
    "get_premium_reward_xp"
    { id = "isWorldWarEnabled", value = isWorldWarEnabled() }
    { id = "wwIsOperationLoaded", value = wwIsOperationLoaded() }
    { id = "wwGetOperationId", value = wwGetOperationId() }
    { id = "wwGetOperationWinner", value = wwGetOperationWinner() }
    { id = "wwGetPlayerSide", value = wwGetPlayerSide() }
    { id = "havePremium", value = havePremium.value }
    "shop_get_countries_list_with_autoset_units"
    "shop_get_units_list_with_autoset_modules"
    { id = "abandoned_researched_items_for_session", value = [] }
    { id = "_fake_mpchat_log_text", value = getTblValue("chatLog", debriefingResult, "") }
    { id = "getLogForBanhammer", value = debriefingResult?.logForBanhammer ??  "" }
    { id = "is_multiplayer", value = getTblValue("isMp", debriefingResult, false) }
    { id = "_fake_battlelog", value = HudBattleLog.battleLog }
    { id = "_fake_userlogs", value = getTblValue("roomUserlogs", debriefingResult, []) }
    { id = "get_user_logs_count", value = getTblValue("roomUserlogs", debriefingResult, []).len() }
    { id = "_fake_playersInfo", value = getPlayersInfo() }
  ]

  let units = []
  let mods  = []
  let exp = getTblValue("expDump", debriefingResult, {})
  foreach (ut in unitTypes.types) {
    let unitId = getTblValue($"investUnitName{ut.name}", exp, "")
    if (unitId != "")
      units.append([ unitId ])
  }
  foreach (unitId, data in getTblValue("aircrafts", exp, {})) {
    if (!getAircraftByName(unitId))
      continue
    units.append([ unitId ])
    let modId = getTblValue("investModuleName", data, "")
    if (modId != "")
      mods.append([ unitId, modId ])
  }
  foreach (tbl in shop_get_countries_list_with_autoset_units()) {
    let unitId = getTblValue("unit", tbl, "")
    let unit = getAircraftByName(unitId)
    let args = [ getUnitCountry(unit), getEsUnitType(unit) ]
    foreach (id in [ "shop_get_researchable_unit_name", "shop_get_country_excess_exp" ])
      list.append({ id = id, args = args })
    units.append([ unitId ])
  }
  foreach (tbl in shop_get_units_list_with_autoset_modules())
    mods.append([ getTblValue("name", tbl, ""), getTblValue("mod", tbl, "") ])
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
  return $"Debriefing result saved to {filename}"
}

function debug_dump_debriefing_load(filename, onUnloadFunc = null) {
  if (!dbg_dump.load(filename))
    return $"File not found: {filename}"

  dbg_dump.loadFuncs({
    is_user_log_for_current_room = function(_idx) { return true }
    get_user_log_blk_body = @(idx, outBlk) outBlk.setFrom(get_fake_userlogs()?[idx] ?? DataBlock())
    get_user_log_time_sec = function(_idx) { return get_charserver_time_sec() }
    disable_user_log_entry = function(idx) { if (idx in get_fake_userlogs()) get_fake_userlogs()[idx].disabled = true }
    is_era_available = function(...) { return true }
    get_current_mission_desc = @(outBlk) outBlk.setFrom(
      getroottable()?._fake_get_current_mission_desc ?? get_current_mission_info_cached())
    get_mplayers_list = function(team, _full) {
      let res = []
      foreach (v in get_fake_mplayers_list())
        if (team == GET_MPLAYERS_LIST || v.team == team)
          res.append(v)
      return (res)
    }
    get_local_mplayer = function() {
      foreach (v in get_fake_mplayers_list())
        if (v.isLocal)
          return v
      return dbg_dump.getOriginal("get_local_mplayer")()
    }
    is_unlocked = function(unlockType, unlockId) {
      foreach (logObj in get_fake_userlogs())
        if (logObj?.body.unlockId == unlockId)
          return true
      return dbg_dump.getOriginal("is_unlocked")(unlockType, unlockId)
    }
  }, false)

  //getRoomUnitTypesMask = @(_room = null) getroottable()?._fake_sessionlobby_unit_type_mask ?? 0
  //getRoomEvent = @(_room = null) events.getEvent(getroottable()?._fake_sessionlobby_last_event_name ?? "")
  //HudBattleLog.battleLog = get_fake_battlelog()
  initListLabelsSquad()

  curMissionRulesInvalidate()
  getCurMissionRules(true)
  setGameChatLogText(getroottable()?._fake_mpchat_log_text)

  gatherDebriefingResult()
  guiStartDebriefingFull({
    function callbackOnDebriefingClose() {
      dbg_dump.unload()
      onUnloadFunc?()
    }
  })
  checkNonApprovedResearches(true)
  broadcastEvent("SessionDestroyed")
  return $"Debriefing result loaded from {filename}"
}

function debug_dump_debriefing_batch_load() {
  let skyquakePath = debug_get_skyquake_path()
  let filesList = dagor_fs.scan_folder({ root = $"{skyquakePath}/gameOnline",
    files_suffix = "*.blk", recursive = false, vromfs = false, realfs = true
  }).filter(@(v) v.contains("debug_dump_debriefing") && !v.contains("_SKIP.blk"))
    .map(@(v) g_path.fileName(v)).sort().reverse()
  let total = filesList.len()
  function loadNext() {
    let count = filesList.len()
    if (!count)
      return
    let filename = filesList.pop()
    console_print($"[{total - count + 1}/{total}] {filename}")
    copy_to_clipboard(filename)
    debug_dump_debriefing_load(filename, loadNext)
  }
  loadNext()
}

//==================================================================================================

function debug_dump_mpstatistics_save(filename) {
  dbg_dump.save(filename, [
    { id = "_fake_mplayers_list", value = get_mplayers_list(GET_MPLAYERS_LIST, true) }
    { id = "_fake_playersInfo", value = getSessionLobbyPlayersInfo() }
    { id = "_fake_get_current_mission_desc", value = function() { let b = DataBlock(); get_current_mission_desc(b); return b } }
    "LAST_SESSION_DEBUG_INFO"
    "is_in_flight"
    "get_player_army_for_hud"
    "get_mp_tbl_teams"
    "get_mp_session_info"
    "get_mp_kick_countdown"
    "get_mp_zone_countdown"
    "get_mp_ffa_score_limit"
    "get_mission_difficulty"
    "get_mission_difficulty_int"
    "get_current_mission_info_cached"
    "get_multiplayer_time_left"
    "is_race_started"
    "get_race_checkpoints_count"
    "get_race_winners_count"
  ])
  return $"Saved {filename}"
}

function debug_dump_mpstatistics_load(filename) {
  if (!dbg_dump.load(filename))
    return $"File not found: {filename}"
  dbg_dump.loadFuncs({
    get_current_mission_desc = @(outBlk) outBlk.setFrom(getroottable()?._fake_get_current_mission_desc)
    get_mplayers_list = function(team, _full) {
      return get_fake_mplayers_list().filter(@(p) p.team == team || team == GET_MPLAYERS_LIST)
    }
    get_mplayer_by_id = function(id) {
      return u.search(get_fake_mplayers_list(), @(p) p.id == id)
    }
    get_local_mplayer = function() {
      return u.search(get_fake_mplayers_list(), @(p) p.isLocal) ?? dbg_dump.getOriginal("get_local_mplayer")()
    }
  }, false)
  guiStartMPStatScreen()
  return $"Loaded {filename}"
}

//==================================================================================================

function debug_dump_respawn_save(filename) {
  let handler = handlersManager.findHandlerClassInScene(gui_handlers.RespawnHandler)
  if (!handler || dbg_dump.isLoaded())
    return "IGNORED: Handler not found, or dump is loaded."

  let list = [
    { id = "_fake_mplayers_list", value = get_mplayers_list(GET_MPLAYERS_LIST, true) }
    { id = "_fake_get_current_mission_desc",
      value = function() {
        let b = DataBlock();
        get_current_mission_desc(b);
        return b
      }
    }
    { id = "get_user_custom_state", args = [ userIdInt64.value, false ] }
    { id = "_fake_mpchat_log", value = getMpChatLog() }
    "LAST_SESSION_DEBUG_INFO"
    "get_current_mission_info_cached"
    "has_available_slots"
    "get_local_player_country"
    "get_crew_info"
    "get_respawns_left"
    "stay_on_respawn_screen"
    "fetch_change_aircraft_on_start"
    "is_menu_state"
    "get_cur_rank_info"
    "get_cur_warpoints"
    "get_option_gun_target_dist"
    "get_option_bomb_activation_type"
    "get_option_bomb_activation_time"
    "get_bomb_activation_auto_time"
    "get_option_depthcharge_activation_time"
    "get_option_mine_depth"
    "get_option_rocket_fuse_dist"
    "is_in_flight"
    "get_player_army_for_hud"
    "get_mp_tbl_teams"
    "get_mp_session_info"
    "get_mp_kick_countdown"
    "get_mp_zone_countdown"
    "get_mp_ffa_score_limit"
    "get_mission_difficulty"
    "get_mission_difficulty_int"
    "get_multiplayer_time_left"
    "is_race_started"
    "get_race_checkpoints_count"
    "get_race_winners_count"
    {id = "g_mis_loading_state.curState", value = g_mis_loading_state.getCurState()}
    "HudBattleLog.battleLog"
  ]

  foreach (crew in getCrewsListByCountry(get_local_player_country())) {
    let unit = getCrewUnit(crew)
    if (unit) {
      foreach (id in [ "get_slot_delay", "get_unit_wp_to_respawn",
        "get_max_spawns_unit_count", "shop_unit_research_status", "shop_is_player_has_unit",
        "shop_is_aircraft_purchased", "wp_get_cost", "wp_get_cost_gold", "get_aircraft_max_fuel" ])
        list.append({ id = id, args = [ unit.name ] })
      list.append({ id = "get_available_respawn_bases", args = [ unit.tags ] })
      list.append({ id = "shop_get_spawn_score", args = [ unit.name, "", [] ] })
      list.append({ id = "is_crew_slot_was_ready_at_host", args = [ crew.idInCountry, unit.name, false ] })
      list.append({ id = "get_aircraft_fuel_consumption", args = [ unit.name, get_mission_difficulty(), true ] })

      foreach (weapon in unit.getWeapons()) {
        foreach (id in [ "wp_get_cost2", "wp_get_cost_gold2", "shop_is_weapon_purchased",
          "shop_get_weapon_baseval" ])
          list.append({ id = id, args = [ unit.name, weapon.name ] })
        list.append({ id = "shop_get_spawn_score", args = [ unit.name, weapon.name, [] ] })
        list.append({ id = "shop_is_weapon_available", args = [ unit.name, weapon.name, true, false ] })
      }
    }
    foreach (id in [ "get_slot_delay_by_slot", "get_num_used_unit_spawns" ])
      list.append({ id = id, args = [ crew.idInCountry ] })
  }

  dbg_dump.save(filename, list)
  return $"Saved {filename}"
}

function debug_dump_respawn_load(filename) {
  if (!dbg_dump.load(filename))
    return $"File not found: {filename}"
  dbg_dump.loadFuncs({
    get_current_mission_desc = @(outBlk) outBlk.setFrom(getroottable()?._fake_get_current_mission_desc)
    get_mplayers_list = @(team, _full) get_fake_mplayers_list().filter(
      @(p) p.team == team || team == GET_MPLAYERS_LIST)
    get_mplayer_by_id = @(id) get_fake_mplayers_list().filter(@(p) p.id == id)?[0]
    get_local_mplayer = @() get_fake_mplayers_list().filter(@(p) p.isLocal)?[0]
  }, false)
  curMissionRulesInvalidate()
  getCurMissionRules()
  clearCrewsList()
  initListLabelsSquad()
  setMpChatLog(getroottable()?._fake_mpchat_log)
  eventbus_send("gui_start_respawn")
  broadcastEvent("MpChatLogUpdated")
  broadcastEvent("BattleLogMessage")
  return $"Loaded {filename}"
}

//==================================================================================================

function debug_dump_userlogs_save(filename) {
  let userlogs = []
  for (local i = 0; i < get_user_logs_count(); i++) {
    let blk = DataBlock()
    get_user_log_blk_body(i, blk)
    userlogs.append(blk)
  }
  dbg_dump.save(filename, [
    { id = "_fake_userlogs", value = userlogs }
  ])
  return $"Saved {filename}"
}

function debug_dump_userlogs_load(filename) {
  if (!dbg_dump.load(filename))
    return $"File not found: {filename}"
  dbg_dump.loadFuncs({
    get_user_logs_count = function() { return get_fake_userlogs().len() }
    is_user_log_for_current_room = function(idx) { return getSessionLobbyRoomId() && getSessionLobbyRoomId() == get_fake_userlogs()?[idx]?.roomId }
    get_user_log_blk_body = @(idx, outBlk) outBlk.setFrom(get_fake_userlogs()?[idx] ?? DataBlock())
    get_user_log_time_sec = function(idx) { return get_fake_userlogs()?[idx]?.timeStamp ?? 0 }
    disable_user_log_entry = function(idx) { if (idx in get_fake_userlogs()) get_fake_userlogs()[idx].disabled = true }
  }, false)
  return $"Loaded {filename}"
}

//==================================================================================================

function debug_dump_inventory_save(filename) {
  dbg_dump.save(filename, [
    { id = "_inventoryClient_items",    value = inventoryClient.items }
    { id = "_inventoryClient_itemdefs", value = inventoryClient.itemdefs }
  ])
  return $"Saved {filename}"
}

function debug_dump_inventory_load(filename) {
  if (!dbg_dump.load(filename))
    return $"File not found: {filename}"
  dbg_dump.loadFuncs({
    inventory = { request  = @(...) null }
  }, false)
  inventoryClient.itemdefs = getroottable()?._inventoryClient_itemdefs ?? {}
  inventoryClient.items    = getroottable()?._inventoryClient_items ?? []
  broadcastEvent("ItemDefChanged")
  broadcastEvent("ExtInventoryChanged")
  return $"Loaded {filename}"
}

//==================================================================================================

register_command(dbg_dump.unload, "debug.dump.unload")
register_command(dbg_dump.isLoaded, "debug.dump.is_loaded")

let defDebriefingFile = "debug_dump_debriefing.blk"
register_command(@() debug_dump_debriefing_save(defDebriefingFile), "debug.dump.debriefing_save")
register_command(debug_dump_debriefing_save, "debug.dump.debriefing_save_to_file")
register_command(@() debug_dump_debriefing_load(defDebriefingFile), "debug.dump.debriefing_load")
register_command(@(file) debug_dump_debriefing_load(file), "debug.dump.debriefing_load_from_file")
register_command(debug_dump_debriefing_batch_load, "debug.dump.debriefing_batch_load")

let defMpStatFile = "debug_dump_mpstatistics.blk"
register_command(@() debug_dump_mpstatistics_save(defMpStatFile), "debug.dump.mpstatistics_save")
register_command(debug_dump_mpstatistics_save, "debug.dump.mpstatistics_save_to_file")
register_command(@() debug_dump_mpstatistics_load(defMpStatFile), "debug.dump.mpstatistics_load")
register_command(debug_dump_mpstatistics_load, "debug.dump.mpstatistics_load_from_file")

let defRespawnFile = "debug_dump_respawn.blk"
register_command(@() debug_dump_respawn_save(defRespawnFile), "debug.dump.respawn_save")
register_command(debug_dump_respawn_save, "debug.dump.respawn_save_to_file")
register_command(@() debug_dump_respawn_load(defRespawnFile), "debug.dump.respawn_load")
register_command(debug_dump_respawn_load, "debug.dump.respawn_load_from_file")

let defUserlogsFile = "debug_dump_userlogs.blk"
register_command(@() debug_dump_userlogs_save(defUserlogsFile), "debug.dump.userlogs_save")
register_command(debug_dump_userlogs_save, "debug.dump.userlogs_save_to_file")
register_command(@() debug_dump_userlogs_load(defUserlogsFile), "debug.dump.userlogs_load")
register_command(debug_dump_userlogs_load, "debug.dump.userlogs_load_from_file")

let defInventoryFile = "debug_dump_inventory.blk"
register_command(@() debug_dump_inventory_save(defInventoryFile), "debug.dump.inventory_save")
register_command(debug_dump_inventory_save, "debug.dump.inventory_save_to_file")
register_command(@() debug_dump_inventory_load(defInventoryFile), "debug.dump.inventory_load")
register_command(debug_dump_inventory_load, "debug.dump.inventory_load_from_file")
