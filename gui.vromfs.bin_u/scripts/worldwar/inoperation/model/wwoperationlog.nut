//-file:plus-string
from "%scripts/dagui_natives.nut" import ww_side_val_to_name, ww_operation_get_log
from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let { saveLocalByAccount } = require("%scripts/clientState/localProfile.nut")
let DataBlock  = require("DataBlock")
let { wwGetPlayerSide } = require("worldwar")
let wwEvent = require("%scripts/worldWar/wwEvent.nut")
let { WwBattle } = require("%scripts/worldWar/inOperation/model/wwBattle.nut")
let { WwArmy } = require("%scripts/worldWar/inOperation/model/wwArmy.nut")

::g_ww_logs <- {
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
      icon = "#ui/gameuiskin#" + WW_LOG_ICONS.SYSTEM
      color = WW_LOG_COLORS.SYSTEM
      size = "veryTiny"
    },
    {
      value = WW_LOG_CATEGORIES.EXISTING_BATTLES
      selected = false
      text = loc("worldwar/log/filter/show_existing_battles")
      icon = "#ui/gameuiskin#" + WW_LOG_ICONS.EXISTING_BATTLES
      color = WW_LOG_COLORS.EXISTING_BATTLES
      size = "veryTiny"
    },
    {
      value = WW_LOG_CATEGORIES.FINISHED_BATTLES
      selected = false
      text = loc("worldwar/log/filter/show_finished_battles")
      icon = "#ui/gameuiskin#" + WW_LOG_ICONS.EXISTING_BATTLES
      color = WW_LOG_COLORS.FINISHED_BATTLES
      size = "veryTiny"
    },
    {
      value = WW_LOG_CATEGORIES.ARMY_ACTIVITY
      selected = false
      text = loc("worldwar/log/filter/show_army_activity")
      icon = "#ui/gameuiskin#" + WW_LOG_ICONS.ARMY_ACTIVITY
      color = WW_LOG_COLORS.ARMY_ACTIVITY
      size = "veryTiny"
    },
    {
      value = WW_LOG_CATEGORIES.ZONE_CAPTURE
      selected = false
      text = loc("worldwar/log/filter/show_zone_capture")
      icon = "#ui/gameuiskin#" + WW_LOG_ICONS.ZONE_CAPTURE
      color = WW_LOG_COLORS.ZONE_CAPTURE
      size = "veryTiny"
    }
  ]
}

::g_ww_logs.getObjectivesBlk <- function getObjectivesBlk() {
  let objectivesBlk = ::g_world_war.getOperationObjectives()
  return objectivesBlk ? u.copy(objectivesBlk?.data) : DataBlock()
}

::g_ww_logs.requestNewLogs <- function requestNewLogs(loadAmount, useLogMark, handler = null) {
  if (useLogMark && ::g_ww_logs.lastMark != "")
    return

  ::g_ww_logs.changeLogsLoadStatus(true)
  let cb = Callback(function() {
    this.loadNewLogs(useLogMark, handler)
    this.changeLogsLoadStatus()
  }, this)
  let errorCb = Callback(this.changeLogsLoadStatus, this)
  ::g_world_war.requestLogs(loadAmount, useLogMark, cb, errorCb)
}

::g_ww_logs.changeLogsLoadStatus <- function changeLogsLoadStatus(isLogsLoading = false) {
  wwEvent("LogsLoadStatusChanged", { isLogsLoading = isLogsLoading })
}

::g_ww_logs.loadNewLogs <- function loadNewLogs(useLogMark, handler) {
  let logsBlk = ww_operation_get_log()
  if (useLogMark)
    ::g_ww_logs.lastMark = logsBlk?.lastMark ?? ""

  this.saveLoadedLogs(logsBlk, useLogMark, handler)
}

::g_ww_logs.saveLoadedLogs <- function saveLoadedLogs(loadedLogsBlk, useLogMark, _handler) {
  if (!this.objectivesStaticBlk)
    this.objectivesStaticBlk = this.getObjectivesBlk()

  wwEvent("NewLogsLoaded")

  local addedLogsNumber = 0
  if (!loadedLogsBlk)
    return

  let freshLogs = []
  let firstLogId = ::g_ww_logs.loaded.len() ?
    ::g_ww_logs.loaded[::g_ww_logs.loaded.len() - 1].id : ""

  local isStrengthUpdateNeeded = false
  local isToBattleUpdateNeeded = false
  let unknownLogType = ::g_ww_log_type.getLogTypeByName(WW_LOG_TYPES.UNKNOWN)
  for (local i = 0; i < loadedLogsBlk.blockCount(); i++) {
    let logBlk = loadedLogsBlk.getBlock(i)

    if (!useLogMark && logBlk?.thisLogId == firstLogId)
      break

    let logType = ::g_ww_log_type.getLogTypeByName(logBlk?.type)
    if (logType == unknownLogType)
      continue

    let logTable = {
      id = logBlk?.thisLogId
      blk = u.copy(logBlk)
      time = logBlk?.time ?? -1
      category = logType.category
      isReaded = false
    }

    ::g_ww_logs.saveLogBattle(logTable.blk)
    ::g_ww_logs.saveLogArmies(logTable.blk, logTable.id)
    ::g_ww_logs.saveLogView(logTable)

    // on some fresh logs - we need to play sound or update strength
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
      this.playLogSound(logBlk)
    }

    addedLogsNumber++
    if (useLogMark)
      ::g_ww_logs.loaded.insert(0, logTable)
    else
      freshLogs.insert(0, logTable)
  }
  if (!useLogMark)
    ::g_ww_logs.loaded.extend(freshLogs)

  if (!addedLogsNumber) {
    wwEvent("NoLogsAdded")
    return
  }

  local isLastReadedLogFounded = false
  for (local i = ::g_ww_logs.loaded.len() - 1; i >= 0; i--) {
    if (::g_ww_logs.loaded[i]?.isReaded)
      break

    if (!isLastReadedLogFounded && ::g_ww_logs.loaded[i]?.id == this.lastReadLogMark)
      isLastReadedLogFounded = true

    if (isLastReadedLogFounded)
      ::g_ww_logs.loaded[i].isReaded = true
  }

  this.applyLogsFilter()
  wwEvent("NewLogsAdded", {
    isLogMarkUsed = useLogMark
    isStrengthUpdateNeeded = isStrengthUpdateNeeded
    isToBattleUpdateNeeded = isToBattleUpdateNeeded })
  wwEvent("NewLogsDisplayed", { amount = this.getUnreadedNumber() })
}

::g_ww_logs.saveLogView <- function saveLogView(logObj) {
  if (!(logObj.id in this.logsViews))
    this.logsViews[logObj.id] <- ::WwOperationLogView(logObj)
}

::g_ww_logs.saveLogBattle <- function saveLogBattle(blk) {
  if (!blk?.battle)
    return
  let savedData = getTblValue(blk.battle?.id, this.logsBattles)
  let savedDataTime = savedData?.time ?? -1
  let logTime = blk?.time ?? -1
  if (savedDataTime > -1 && savedDataTime >= logTime)
    return

  this.logsBattles[blk.battle.id] <- {
    battle = WwBattle(blk.battle)
    time = logTime
    logBlk = blk
  }
}

::g_ww_logs.saveLogArmies <- function saveLogArmies(blk, logId) {
  if ("armies" in blk)
    foreach (armyBlk in blk.armies) {
      let armyId = this.getLogArmyId(logId, armyBlk?.name)
      if (!(armyId in this.logsArmies))
        this.logsArmies[armyId] <- WwArmy(armyBlk?.name, armyBlk)
    }
}

::g_ww_logs.getLogArmyId <- function getLogArmyId(logId, armyName) {
  return "log_" + logId + "_" + armyName
}

::g_ww_logs.saveLastReadLogMark <- function saveLastReadLogMark() {
  this.lastReadLogMark = this.getLastReadLogMark()
  saveLocalByAccount(::g_world_war.getSaveOperationLogId(), this.lastReadLogMark)
}

::g_ww_logs.getLastReadLogMark <- function getLastReadLogMark() {
  return u.search(::g_ww_logs.loaded, @(l) l.isReaded, true)?.id ?? ""
}

::g_ww_logs.getUnreadedNumber <- function getUnreadedNumber() {
  local unreadedNumber = 0
  foreach (logObj in this.loaded)
    if (!logObj?.isReaded)
      unreadedNumber ++

  return unreadedNumber
}

::g_ww_logs.applyLogsFilter <- function applyLogsFilter() {
  this.filtered.clear()
  for (local i = 0; i < this.loaded.len(); i++)
    if (this.filter[this.loaded[i].category])
      this.filtered.append(i)
}

::g_ww_logs.playLogSound <- function playLogSound(logBlk) {
  let logBlkType = logBlk?.type

  if (logBlkType == WW_LOG_TYPES.ARTILLERY_STRIKE_DAMAGE) {
    let wwArmy = this.getLogArmy(logBlk)
    if (wwArmy && !wwArmy.isMySide(wwGetPlayerSide()))
      get_cur_gui_scene()?.playSound("ww_artillery_enemy")
  }

  else if (logBlkType == WW_LOG_TYPES.ARMY_FLYOUT) {
    let wwArmy = this.getLogArmy(logBlk)
    if (wwArmy && !wwArmy.isMySide(wwGetPlayerSide()))
      get_cur_gui_scene()?.playSound("ww_enemy_airplane_incoming")
  }

  else if (WW_LOG_TYPES.BATTLE_STARTED == logBlkType) {
    get_cur_gui_scene()?.playSound("ww_battle_start")
  }

  else if (WW_LOG_TYPES.BATTLE_FINISHED == logBlkType) {
    get_cur_gui_scene()?.playSound(this.isPlayerWinner(logBlk) ?
      "ww_battle_end_win" : "ww_battle_end_fail")
  }
}

::g_ww_logs.isPlayerWinner <- function isPlayerWinner(logBlk) {
  let mySideName = ww_side_val_to_name(wwGetPlayerSide())
  if (logBlk?.type == WW_LOG_TYPES.BATTLE_FINISHED)
    for (local i = 0; i < logBlk.battle.teams.blockCount(); i++)
      if (logBlk.battle.teams.getBlock(i).side == mySideName)
        return logBlk.battle.teams.getBlock(i)?.isWinner

  return logBlk?.winner == mySideName
}

::g_ww_logs.getLogArmy <- function getLogArmy(logBlk) {
  let wwArmyId = this.getLogArmyId(logBlk?.thisLogId, logBlk?.army)
  return getTblValue(wwArmyId, this.logsArmies)
}

::g_ww_logs.clear <- function clear() {
  this.saveLastReadLogMark()
  this.loaded.clear()
  this.filtered.clear()
  this.logsBattles.clear()
  this.logsArmies.clear()
  this.logsViews.clear()
  this.lastMark = ""
  this.viewIndex = 0
  this.objectivesStaticBlk = null
}
