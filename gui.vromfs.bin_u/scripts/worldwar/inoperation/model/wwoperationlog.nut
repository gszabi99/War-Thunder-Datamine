global enum WW_LOG_CATEGORIES
{
  SYSTEM
  EXISTING_BATTLES
  FINISHED_BATTLES
  ARMY_ACTIVITY
  ZONE_CAPTURE
}

global enum WW_LOG_ICONS
{
  SYSTEM = "icon_type_log_systems.png"
  EXISTING_BATTLES = "icon_type_log_battles.png"
  FINISHED_BATTLES = "icon_type_log_battles.png"
  ARMY_ACTIVITY = "icon_type_log_army.png"
  ZONE_CAPTURE = "icon_type_log_sectors.png"
}

global enum WW_LOG_COLORS
{
  NEUTRAL_EVENT = "@commonTextColor"
  GOOD_EVENT = "@wwTeamAllyColor"
  BAD_EVENT = "@wwTeamEnemyColor"
  SYSTEM = "@operationLogSystemMessage"
  EXISTING_BATTLES = "@operationLogBattleInProgress"
  FINISHED_BATTLES = "@operationLogBattleCompleted"
  ARMY_ACTIVITY = "@operationLogArmyInfo"
  ZONE_CAPTURE = "@operationLogBattleCompleted"
}

global enum WW_LOG_TYPES
{
  UNKNOWN = "UNKNOWN"
  OPERATION_CREATED = "operation_created"
  OPERATION_STARTED = "operation_started"
  OBJECTIVE_COMPLETED = "objective_completed"
  OPERATION_FINISHED = "operation_finished"
  BATTLE_STARTED = "battle_started"
  BATTLE_FINISHED = "battle_finished"
  BATTLE_JOIN = "battle_join"
  ZONE_CAPTURED = "zone_captured"
  ARMY_RETREAT = "army_retreat"
  ARMY_DIED = "army_died"
  ARMY_FLYOUT = "army_flyout"
  ARMY_LAND_ON_AIRFIELD = "army_landOnAirfield"
  ARTILLERY_STRIKE_DAMAGE = "artillery_strike_damage"
  REINFORCEMENT = "reinforcement"
}

global enum WW_LOG_BATTLE
{
  DEFAULT_ARMY_INDEX = 0
  MIN_ARMIES_PER_SIDE = 1
  MAX_ARMIES_PER_SIDE = 2
  MAX_DAMAGED_ARMIES = 5
}

global const WW_LOG_REQUEST_DELAY = 1
global const WW_LOG_MAX_LOAD_AMOUNT = 20
global const WW_LOG_EVENT_LOAD_AMOUNT = 10
global const WW_LOG_MAX_DISPLAY_AMOUNT = 40

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
      show = true
      text = ::loc("worldwar/log/filter/show_system_message")
      icon = "#ui/gameuiskin#" + WW_LOG_ICONS.SYSTEM
      color = WW_LOG_COLORS.SYSTEM
      size = "veryTiny"
    },
    {
      value = WW_LOG_CATEGORIES.EXISTING_BATTLES
      selected = false
      show = true
      text = ::loc("worldwar/log/filter/show_existing_battles")
      icon = "#ui/gameuiskin#" + WW_LOG_ICONS.EXISTING_BATTLES
      color = WW_LOG_COLORS.EXISTING_BATTLES
      size = "veryTiny"
    },
    {
      value = WW_LOG_CATEGORIES.FINISHED_BATTLES
      selected = false
      show = true
      text = ::loc("worldwar/log/filter/show_finished_battles")
      icon = "#ui/gameuiskin#" + WW_LOG_ICONS.EXISTING_BATTLES
      color = WW_LOG_COLORS.FINISHED_BATTLES
      size = "veryTiny"
    },
    {
      value = WW_LOG_CATEGORIES.ARMY_ACTIVITY
      selected = false
      show = true
      text = ::loc("worldwar/log/filter/show_army_activity")
      icon = "#ui/gameuiskin#" + WW_LOG_ICONS.ARMY_ACTIVITY
      color = WW_LOG_COLORS.ARMY_ACTIVITY
      size = "veryTiny"
    },
    {
      value = WW_LOG_CATEGORIES.ZONE_CAPTURE
      selected = false
      show = true
      text = ::loc("worldwar/log/filter/show_zone_capture")
      icon = "#ui/gameuiskin#" + WW_LOG_ICONS.ZONE_CAPTURE
      color = WW_LOG_COLORS.ZONE_CAPTURE
      size = "veryTiny"
    }
  ]
}

g_ww_logs.getObjectivesBlk <- function getObjectivesBlk()
{
  let objectivesBlk = ::g_world_war.getOperationObjectives()
  return objectivesBlk ? ::u.copy(objectivesBlk?.data) : ::DataBlock()
}

g_ww_logs.requestNewLogs <- function requestNewLogs(loadAmount, useLogMark, handler = null)
{
  if (useLogMark && !::g_ww_logs.lastMark)
    return

  ::g_ww_logs.changeLogsLoadStatus(true)
  let cb = ::Callback(function() {
    loadNewLogs(useLogMark, handler)
    changeLogsLoadStatus()
  }, this)
  let errorCb = ::Callback(changeLogsLoadStatus, this)
  ::g_world_war.requestLogs(loadAmount, useLogMark, cb, errorCb)
}

g_ww_logs.changeLogsLoadStatus <- function changeLogsLoadStatus(isLogsLoading = false)
{
  ::ww_event("LogsLoadStatusChanged", {isLogsLoading = isLogsLoading})
}

g_ww_logs.loadNewLogs <- function loadNewLogs(useLogMark, handler)
{
  let logsBlk = ::ww_operation_get_log()
  if (useLogMark)
    ::g_ww_logs.lastMark = logsBlk?.lastMark ?? ""

  saveLoadedLogs(logsBlk, useLogMark, handler)
}

g_ww_logs.saveLoadedLogs <- function saveLoadedLogs(loadedLogsBlk, useLogMark, handler)
{
  if (!objectivesStaticBlk)
    objectivesStaticBlk = getObjectivesBlk()

  ::ww_event("NewLogsLoaded")

  local addedLogsNumber = 0
  if (!loadedLogsBlk)
    return

  let freshLogs = []
  let firstLogId = ::g_ww_logs.loaded.len() ?
    ::g_ww_logs.loaded[::g_ww_logs.loaded.len() - 1].id : ""

  local isStrengthUpdateNeeded = false
  local isToBattleUpdateNeeded = false
  let unknownLogType = ::g_ww_log_type.getLogTypeByName(WW_LOG_TYPES.UNKNOWN)
  for (local i = 0; i < loadedLogsBlk.blockCount(); i++)
  {
    let logBlk = loadedLogsBlk.getBlock(i)

    if (!useLogMark && logBlk?.thisLogId == firstLogId)
      break

    let logType = ::g_ww_log_type.getLogTypeByName(logBlk?.type)
    if (logType == unknownLogType)
      continue

    let logTable = {
      id = logBlk?.thisLogId
      blk = ::u.copy(logBlk)
      time = logBlk?.time ?? -1
      category = logType.category
      isReaded = false
    }

    ::g_ww_logs.saveLogBattle(logTable.blk)
    ::g_ww_logs.saveLogArmies(logTable.blk, logTable.id)
    ::g_ww_logs.saveLogView(logTable)

    // on some fresh logs - we need to play sound or update strength
    if (!useLogMark)
    {
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
      ::g_ww_logs.loaded.insert(0, logTable)
    else
      freshLogs.insert(0, logTable)
  }
  if (!useLogMark)
    ::g_ww_logs.loaded.extend(freshLogs)

  if (!addedLogsNumber)
  {
    ::ww_event("NoLogsAdded")
    return
  }

  local isLastReadedLogFounded = false
  for (local i = ::g_ww_logs.loaded.len() - 1; i >= 0; i--)
  {
    if (::g_ww_logs.loaded[i]?.isReaded)
      break

    if (!isLastReadedLogFounded && ::g_ww_logs.loaded[i]?.id == lastReadLogMark)
      isLastReadedLogFounded = true

    if (isLastReadedLogFounded)
      ::g_ww_logs.loaded[i].isReaded = true
  }

  applyLogsFilter()
  ::ww_event("NewLogsAdded", {
    isLogMarkUsed = useLogMark
    isStrengthUpdateNeeded = isStrengthUpdateNeeded
    isToBattleUpdateNeeded = isToBattleUpdateNeeded })
  ::ww_event("NewLogsDisplayed", { amount = getUnreadedNumber() })
}

g_ww_logs.saveLogView <- function saveLogView(log)
{
  if (!(log.id in logsViews))
    logsViews[log.id] <- ::WwOperationLogView(log)
}

g_ww_logs.saveLogBattle <- function saveLogBattle(blk)
{
  if (!blk?.battle)
    return
  let savedData = ::getTblValue(blk.battle?.id, logsBattles)
  let savedDataTime = savedData?.time ?? -1
  let logTime = blk?.time ?? -1
  if (savedDataTime > -1 && savedDataTime >= logTime)
    return

  logsBattles[blk.battle.id] <- {
    battle = ::WwBattle(blk.battle)
    time = logTime
    logBlk = blk
  }
}

g_ww_logs.saveLogArmies <- function saveLogArmies(blk, logId)
{
  if ("armies" in blk)
    foreach (armyBlk in blk.armies)
    {
      let armyId = getLogArmyId(logId, armyBlk?.name)
      if (!(armyId in logsArmies))
        logsArmies[armyId] <- ::WwArmy(armyBlk?.name, armyBlk)
    }
}

g_ww_logs.getLogArmyId <- function getLogArmyId(logId, armyName)
{
  return "log_" + logId + "_" + armyName
}

g_ww_logs.saveLastReadLogMark <- function saveLastReadLogMark()
{
  lastReadLogMark = getLastReadLogMark()
  ::saveLocalByAccount(::g_world_war.getSaveOperationLogId(), lastReadLogMark)
}

g_ww_logs.getLastReadLogMark <- function getLastReadLogMark()
{
  return ::u.search(::g_ww_logs.loaded, @(l) l.isReaded, true)?.id ?? ""
}

g_ww_logs.getUnreadedNumber <- function getUnreadedNumber()
{
  local unreadedNumber = 0
  foreach (log in loaded)
    if (!log?.isReaded)
      unreadedNumber ++

  return unreadedNumber
}

g_ww_logs.applyLogsFilter <- function applyLogsFilter()
{
  filtered.clear()
  for (local i = 0; i < loaded.len(); i++)
    if (filter[loaded[i].category])
      filtered.append(i)
}

g_ww_logs.playLogSound <- function playLogSound(logBlk)
{
  switch (logBlk?.type)
  {
    case WW_LOG_TYPES.ARTILLERY_STRIKE_DAMAGE:
      let wwArmy = getLogArmy(logBlk)
      if (wwArmy && !wwArmy.isMySide(::ww_get_player_side()))
        ::get_cur_gui_scene()?.playSound("ww_artillery_enemy")
      break

    case WW_LOG_TYPES.ARMY_FLYOUT:
      let wwArmy = getLogArmy(logBlk)
      if (wwArmy && !wwArmy.isMySide(::ww_get_player_side()))
        ::get_cur_gui_scene()?.playSound("ww_enemy_airplane_incoming")
      break

    case WW_LOG_TYPES.BATTLE_STARTED:
      ::get_cur_gui_scene()?.playSound("ww_battle_start")
      break

    case WW_LOG_TYPES.BATTLE_FINISHED:
      ::get_cur_gui_scene()?.playSound(isPlayerWinner(logBlk) ?
        "ww_battle_end_win" : "ww_battle_end_fail")
      break
  }
}

g_ww_logs.isPlayerWinner <- function isPlayerWinner(logBlk)
{
  let mySideName = ::ww_side_val_to_name(::ww_get_player_side())
  if (logBlk?.type == WW_LOG_TYPES.BATTLE_FINISHED)
    for (local i = 0; i < logBlk.battle.teams.blockCount(); i++)
      if (logBlk.battle.teams.getBlock(i).side == mySideName)
        return logBlk.battle.teams.getBlock(i)?.isWinner

  return logBlk?.winner == mySideName
}

g_ww_logs.getLogArmy <- function getLogArmy(logBlk)
{
  let wwArmyId = getLogArmyId(logBlk?.thisLogId, logBlk?.army)
  return ::getTblValue(wwArmyId, logsArmies)
}

g_ww_logs.clear <- function clear()
{
  saveLastReadLogMark()
  loaded.clear()
  filtered.clear()
  logsBattles.clear()
  logsArmies.clear()
  logsViews.clear()
  lastMark = ""
  viewIndex = 0
  objectivesStaticBlk = null
}
