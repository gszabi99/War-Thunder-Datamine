from "%scripts/dagui_natives.nut" import ww_side_val_to_name, ww_operation_get_log
from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *

let DataBlock = require("DataBlock")
let { wwGetPlayerSide } = require("worldwar")
let { copy, search } = require("%sqStdLibs/helpers/u.nut")
let { saveLocalByAccount } = require("%scripts/clientState/localProfileDeprecated.nut")
let wwEvent = require("%scripts/worldWar/wwEvent.nut")
let { WwBattle } = require("%scripts/worldWar/inOperation/model/wwBattle.nut")
let { WwArmy } = require("%scripts/worldWar/inOperation/model/wwArmy.nut")
let { g_ww_log_type } = require("%scripts/worldWar/inOperation/model/wwOperationLogTypes.nut")

let logsData = {
  loaded = []
  filter = [ true, true, true, true, true ]
  filtered = []
  logsBattles = {}
  logsArmies = {}
  logsViews = {}
  lastMark = ""
  viewIndex = 0
  lastReadLogMark = ""
  objectivesStaticBlk = null

  logCategories = [
    {
      value = WW_LOG_CATEGORIES.SYSTEM
      selected = false
      text = loc("worldwar/log/filter/show_system_message")
      icon = $"#ui/gameuiskin#{WW_LOG_ICONS.SYSTEM}"
      color = WW_LOG_COLORS.SYSTEM
      size = "veryTiny"
    },
    {
      value = WW_LOG_CATEGORIES.EXISTING_BATTLES
      selected = false
      text = loc("worldwar/log/filter/show_existing_battles")
      icon = $"#ui/gameuiskin#{WW_LOG_ICONS.EXISTING_BATTLES}"
      color = WW_LOG_COLORS.EXISTING_BATTLES
      size = "veryTiny"
    },
    {
      value = WW_LOG_CATEGORIES.FINISHED_BATTLES
      selected = false
      text = loc("worldwar/log/filter/show_finished_battles")
      icon = $"#ui/gameuiskin#{WW_LOG_ICONS.EXISTING_BATTLES}"
      color = WW_LOG_COLORS.FINISHED_BATTLES
      size = "veryTiny"
    },
    {
      value = WW_LOG_CATEGORIES.ARMY_ACTIVITY
      selected = false
      text = loc("worldwar/log/filter/show_army_activity")
      icon = $"#ui/gameuiskin#{WW_LOG_ICONS.ARMY_ACTIVITY}"
      color = WW_LOG_COLORS.ARMY_ACTIVITY
      size = "veryTiny"
    },
    {
      value = WW_LOG_CATEGORIES.ZONE_CAPTURE
      selected = false
      text = loc("worldwar/log/filter/show_zone_capture")
      icon = $"#ui/gameuiskin#{WW_LOG_ICONS.ZONE_CAPTURE}"
      color = WW_LOG_COLORS.ZONE_CAPTURE
      size = "veryTiny"
    }
  ]
}

let getWWLogsData = @() logsData

function getUnreadedNumber() {
  return logsData.loaded.reduce(function(res, logObj) {
    return res + (!logObj?.isReaded ? 1 : 0)
  }, 0)
}

function applyLogsFilter() {
  logsData.filtered.clear()
  for (local i = 0; i < logsData.loaded.len(); i++)
    if (logsData.filter[logsData.loaded[i].category])
      logsData.filtered.append(i)
}

function isPlayerWinner(logBlk) {
  let mySideName = ww_side_val_to_name(wwGetPlayerSide())
  if (logBlk?.type == WW_LOG_TYPES.BATTLE_FINISHED)
    for (local i = 0; i < logBlk.battle.teams.blockCount(); i++)
      if (logBlk.battle.teams.getBlock(i).side == mySideName)
        return logBlk.battle.teams.getBlock(i)?.isWinner

  return logBlk?.winner == mySideName
}

function getLogArmyId(logId, armyName) {
  return $"log_{logId}_{armyName}"
}

function getObjectivesBlk() {
  let objectivesBlk = ::g_world_war.getOperationObjectives()
  return objectivesBlk ? copy(objectivesBlk?.data) : DataBlock()
}

function getLogArmy(logBlk) {
  let wwArmyId = getLogArmyId(logBlk?.thisLogId, logBlk?.army)
  return logsData.logsArmies?[wwArmyId]
}

function playLogSound(logBlk) {
  let logBlkType = logBlk?.type

  if (logBlkType == WW_LOG_TYPES.ARTILLERY_STRIKE_DAMAGE) {
    let wwArmy = getLogArmy(logBlk)
    if (wwArmy && !wwArmy.isMySide(wwGetPlayerSide()))
      get_cur_gui_scene()?.playSound("ww_artillery_enemy")
  }

  else if (logBlkType == WW_LOG_TYPES.ARMY_FLYOUT) {
    let wwArmy = getLogArmy(logBlk)
    if (wwArmy && !wwArmy.isMySide(wwGetPlayerSide()))
      get_cur_gui_scene()?.playSound("ww_enemy_airplane_incoming")
  }

  else if (WW_LOG_TYPES.BATTLE_STARTED == logBlkType) {
    get_cur_gui_scene()?.playSound("ww_battle_start")
  }

  else if (WW_LOG_TYPES.BATTLE_FINISHED == logBlkType) {
    get_cur_gui_scene()?.playSound(isPlayerWinner(logBlk) ?
      "ww_battle_end_win" : "ww_battle_end_fail")
  }
}

function changeLogsLoadStatus(isLogsLoading = false) {
  wwEvent("LogsLoadStatusChanged", { isLogsLoading = isLogsLoading })
}

function saveLogBattle(blk) {
  if (!blk?.battle)
    return
  let savedData = getTblValue(blk.battle?.id, logsData.logsBattles)
  let savedDataTime = savedData?.time ?? -1
  let logTime = blk?.time ?? -1
  if (savedDataTime > -1 && savedDataTime >= logTime)
    return

  logsData.logsBattles[blk.battle.id] <- {
    battle = WwBattle(blk.battle)
    time = logTime
    logBlk = blk
  }
}

function saveLogView(logObj) {
  if (!(logObj.id in logsData.logsViews))
    logsData.logsViews[logObj.id] <- logObj
}

function saveLogArmies(blk, logId) {
  if ("armies" in blk)
    foreach (armyBlk in blk.armies) {
      let armyId = getLogArmyId(logId, armyBlk?.name)
      if (!(armyId in logsData.logsArmies))
        logsData.logsArmies[armyId] <- WwArmy(armyBlk?.name, armyBlk)
    }
}

function saveLoadedLogs(loadedLogsBlk, useLogMark, _handler) {
  if (!logsData.objectivesStaticBlk)
    logsData.objectivesStaticBlk = getObjectivesBlk()

  wwEvent("NewLogsLoaded")

  local addedLogsNumber = 0
  if (!loadedLogsBlk)
    return

  let freshLogs = []
  let firstLogId = logsData.loaded.len() ?
    logsData.loaded[logsData.loaded.len() - 1].id : ""

  local isStrengthUpdateNeeded = false
  local isToBattleUpdateNeeded = false
  let unknownLogType = g_ww_log_type.getLogTypeByName(WW_LOG_TYPES.UNKNOWN)
  for (local i = 0; i < loadedLogsBlk.blockCount(); i++) {
    let logBlk = loadedLogsBlk.getBlock(i)

    if (!useLogMark && logBlk?.thisLogId == firstLogId)
      break

    let logType = g_ww_log_type.getLogTypeByName(logBlk?.type)
    if (logType == unknownLogType)
      continue

    let logTable = {
      id = logBlk?.thisLogId
      blk = copy(logBlk)
      time = logBlk?.time ?? -1
      category = logType.category
      isReaded = false
    }

    saveLogBattle(logTable.blk)
    saveLogArmies(logTable.blk, logTable.id)
    saveLogView(logTable)

    
    if (!useLogMark) {
      isStrengthUpdateNeeded = logBlk.type == WW_LOG_TYPES.ARTILLERY_STRIKE_DAMAGE ||
                               logBlk.type == WW_LOG_TYPES.BATTLE_FINISHED ||
                               logBlk.type == WW_LOG_TYPES.REINFORCEMENT ||
                               isStrengthUpdateNeeded
      isToBattleUpdateNeeded = logBlk.type == WW_LOG_TYPES.OPERATION_CREATED ||
                               logBlk.type == WW_LOG_TYPES.OPERATION_FINISHED ||
                               logBlk.type == WW_LOG_TYPES.BATTLE_STARTED ||
                               logBlk.type == WW_LOG_TYPES.BATTLE_FINISHED ||
                               isToBattleUpdateNeeded
      playLogSound(logBlk)
    }

    addedLogsNumber++
    if (useLogMark)
      logsData.loaded.insert(0, logTable)
    else
      freshLogs.insert(0, logTable)
  }
  if (!useLogMark)
    logsData.loaded.extend(freshLogs)

  if (!addedLogsNumber) {
    wwEvent("NoLogsAdded")
    return
  }

  local isLastReadedLogFounded = false
  for (local i = logsData.loaded.len() - 1; i >= 0; i--) {
    if (logsData.loaded[i]?.isReaded)
      break

    if (!isLastReadedLogFounded && logsData.loaded[i]?.id == logsData.lastReadLogMark)
      isLastReadedLogFounded = true

    if (isLastReadedLogFounded)
      logsData.loaded[i].isReaded = true
  }

  applyLogsFilter()
  wwEvent("NewLogsAdded", {
    isLogMarkUsed = useLogMark
    isStrengthUpdateNeeded = isStrengthUpdateNeeded
    isToBattleUpdateNeeded = isToBattleUpdateNeeded })
  wwEvent("NewLogsDisplayed", { amount = getUnreadedNumber() })
}

function loadNewLogs(useLogMark, handler) {
  let logsBlk = ww_operation_get_log()
  if (useLogMark)
    logsData.lastMark = logsBlk?.lastMark ?? ""

  saveLoadedLogs(logsBlk, useLogMark, handler)
}

function requestNewLogs(loadAmount, useLogMark, handler = null) {
  if (useLogMark && logsData.lastMark != "")
    return

  changeLogsLoadStatus(true)
  let cb = function() {
    loadNewLogs(useLogMark, handler)
    changeLogsLoadStatus()
  }
  ::g_world_war.requestLogs(loadAmount, useLogMark, cb, changeLogsLoadStatus)
}

function getLastReadLogMark() {
  return search(logsData.loaded, @(l) l.isReaded, true)?.id ?? ""
}

function saveLastReadLogMark() {
  logsData.lastReadLogMark = getLastReadLogMark()
  saveLocalByAccount(::g_world_war.getSaveOperationLogId(), logsData.lastReadLogMark)
}

function clearWWLogs() {
  saveLastReadLogMark()
  logsData.loaded.clear()
  logsData.filtered.clear()
  logsData.logsBattles.clear()
  logsData.logsArmies.clear()
  logsData.logsViews.clear()
  logsData.lastMark = ""
  logsData.viewIndex = 0
  logsData.objectivesStaticBlk = null
}

return {
  getWWLogsData
  requestNewWWLogs = requestNewLogs
  getWWLogArmyId = getLogArmyId
  saveLastReadWWLogMark = saveLastReadLogMark
  getUnreadedWWLogsNumber = getUnreadedNumber
  applyWWLogsFilter = applyLogsFilter
  isWWPlayerWinner = isPlayerWinner
  clearWWLogs
}