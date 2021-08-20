local mpChatModel = require("scripts/chat/mpChatModel.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")
local { NO_BONUS, PREV_UNIT_EFFICIENCY } = require("scripts/debriefing/rewardSources.nut")
local { MISSION_OBJECTIVE } = require("scripts/missions/missionsUtilsModule.nut")
local { isGameModeVersus } = require("scripts/matchingRooms/matchingGameModesUtils.nut")
local { money_type } = require("scripts/money.nut")

global enum debrState {
  init
  showPlayers
  showMyStats
  showBonuses
  showAwards
  done
}

local debriefingResult = null
local dynamicResult = -1

local function countWholeRewardInTable(table, currency, specParam = null) {
  if (!table || table.len() == 0)
    return 0

  local reward = 0
  local upCur = ::g_string.toUpper(currency, 1)
  local searchArray = specParam || ["noBonus", "premMod", "premAcc", "booster"]
  foreach(cur in searchArray)
    reward += ::getTblValue(cur + upCur, table, 0)
  return reward
}

local getTableNameById = @(row) $"tbl{row.getRewardId()}"

local debriefingRowDefault = {
  id = ""
  rewardId = null
  showEvenEmpty = false //show row even there only 0
  showByValue = null  //bool function(value)
  rowProps = null //for custom row visual
  showByModes = null //function(gameMode), boolean
  showByTypes = null //function(gameType), boolean
  isShowOnlyInTooltips = false // row is invisible in table, but still can show in other rows tooltips, as extra row.
  canShowRewardAsValue = false  //when no reward in other rows, reward in thoose rows will show in value row.
  showOnlyWhenFullResult = false
  joinRows = null // null or array of existing row ids, which must be joined into this new row.
  customValueName = null
  getValueFunc = null
  icon = "icon/summation" // Icon used as Value column header in tooltip
  getIcon = @() ::loc(icon, "")
  tooltipExtraRows = null //function(), array
  tooltipComment = null  //string function()
  tooltipRowBonuses = @(unitId, unitData) null
  hideTooltip = false
  hideUnitSessionTimeInTooltip = false
  isCountedInUnits = true
  isFreeRP = false  //special row where exp currency is not RP but FreeRP

  //!!FIX ME: all data must come full from server
  //Here temporary params for debriefing data recount while it not fixed.
  isOverall = false  //first win mul sum will add to overall, and premium will count here as sum of all other.
  isUsedInRecount = true
  //!!finish temp params

  //auto refill params by debriefing
  value = 0
  type = "num"  //"num", "sec", "mul", "pct", "tim", "ptm", ""
  wp = 0
  gold = 0
  exp = 0
  reward = 0
  rewardType = "wp"
  show = false
  showInTooltips = false

  getRewardId = function() { return rewardId || id }
  isVisible = function(gameMode, gameType, isDebriefingFull, isTooltip = false)
  {
    if (showByModes && !showByModes(gameMode))
      return false
    if (showByTypes && !showByTypes(gameType))
      return false
    return (isDebriefingFull || !showOnlyWhenFullResult) && (isTooltip || !isShowOnlyInTooltips)
  }
  isVisibleWhenEmpty = function() { return showEvenEmpty }
  getName = function() { return ::loc(::getTblValue("text", this, "debriefing/" + id)) }
}

local debriefingRows = [] //!!!FIX ME debriefingRows used for some rows tooltip
debriefingRows = [
  { id = "AirKills"
    showByModes = isGameModeVersus
    showByTypes = function(gt) {return (!(gt & ::GT_RACE) && !(gt & ::GT_FOOTBALL))}
    text = "multiplayer/air_kills"
    icon = "icon/mpstats/kills"
    isVisibleWhenEmpty = @() !!(::g_mission_type.getCurrentObjectives() & MISSION_OBJECTIVE.KILLS_AIR)
  }
  { id = "GroundKills"
    showByTypes = function(gt) {return (!(gt & ::GT_RACE) && !(gt & ::GT_FOOTBALL))}
    showByModes = isGameModeVersus
    getName = @() ::loc("multiplayer/ground_kills")
    getIcon = @() ::loc("icon/mpstats/groundKills", "")
    isVisibleWhenEmpty = @() !!(::g_mission_type.getCurrentObjectives() & MISSION_OBJECTIVE.KILLS_GROUND)
  }
  { id = "AwardDamage"
    showByTypes = function(gt) {return (!(gt & ::GT_RACE) && !(gt & ::GT_FOOTBALL))}
    showByModes = function(gm) { return gm != ::GM_SKIRMISH }
    text = "multiplayer/naval_damage"
    icon = "icon/mpstats/navalDamage"
    isVisibleWhenEmpty = @() !!(::g_mission_type.getCurrentObjectives() & MISSION_OBJECTIVE.KILLS_NAVAL)
  }
  { id = "NavalKills"
    showByTypes = function(gt) {return (!(gt & ::GT_RACE) && !(gt & ::GT_FOOTBALL))}
    showByModes = isGameModeVersus
    text = "multiplayer/naval_kills"
    icon = "icon/mpstats/navalKills"
    isVisibleWhenEmpty = @() !!(::g_mission_type.getCurrentObjectives() & MISSION_OBJECTIVE.KILLS_NAVAL)
  }
  "GroundKillsF"
  "NavalKillsF"
  { id = "Assist"
    showByModes = isGameModeVersus
    text = "multiplayer/assists"
    icon = "icon/mpstats/assists"
  }
  "Critical"
  "Hit"
  { id = "Scouting"
    showByTypes = function(gt) {return (!(gt & ::GT_RACE) && !(gt & ::GT_FOOTBALL))}
    showByModes = isGameModeVersus
    icon = "hud/iconBinocular"
    joinRows = [ "Scout", "ScoutKill", "ScoutCriticalHit", "ScoutKillUnknown"]
  }
  { id = "Scout"
    isShowOnlyInTooltips = true
  }
  { id = "ScoutCriticalHit"
    isShowOnlyInTooltips = true
  }
  { id = "ScoutKill"
    isShowOnlyInTooltips = true
  }
  { id = "ScoutKillUnknown"
    isShowOnlyInTooltips = true
  }
  { id = "Overkill"
    showByModes = isGameModeVersus
  }
  { id = "Captures"
    type = "num"
    showByModes = isGameModeVersus
    text = "multiplayer/zone_captures"
    icon = "icon/mpstats/captureZone"
  }
  "Landings"
  "Takeoffs"
  { id = "Sights"
    showByModes = isGameModeVersus
    showByTypes = function(gt) {return (!(gt & ::GT_RACE) && !(gt & ::GT_FOOTBALL))}
  }
  { id = "Damage",
    type = "tnt"
    showByModes = isGameModeVersus
    icon = "icon/mpstats/damageZone"
  }
  { id = "Destruction"
    type = ""
    showByModes = isGameModeVersus
    icon = "icon/mpstats/damageZone"
  }
  { id = "MissionObjective"
    type = ""
    icon = "icon/star"
  }
  { id = "BestLap"
    type = "ptm"
    icon = "icon/mpstats/raceBestLapTime"
  }
  { id = "TimedAward"
    type = ""
    text = "exp_reasons/timed_award"
  }
  { id = "BattleTime"
    text = "debriefing/activityTime"
    type = "tim"
    icon = "icon/hourglass"
    hideUnitSessionTimeInTooltip = true
  }
  { id = "Activity"
    customValueName = "activity"
    type = "pct"
    showByModes = function(gm) { return gm == ::GM_DOMINATION }
    showOnlyWhenFullResult = true
    showEvenEmpty = true
    infoName = "score"
    infoType = ""
  }
  { id = "Mission"
    type = "exp"
    showByModes = function(gm) { return gm == ::GM_DOMINATION }
    getName = function() {
      if (!debriefingResult || !("exp" in debriefingResult))
        return ::loc("debriefing/Mission")

      local checkVal = countWholeRewardInTable(debriefingResult.exp?[getTableNameById(this)],
        type, ["premMod", "premAcc"])
      if (checkVal < 0)
        return ::loc("debriefing/MissionNegative")

      if (debriefingResult.exp.result == ::STATS_RESULT_SUCCESS)
        return ::loc("debriefing/MissionWinReward")
      else if (debriefingResult.exp.result == ::STATS_RESULT_FAIL)
        return ::loc("debriefing/MissionLoseReward")
      return ::loc("debriefing/Mission")
    }
    rowProps = function() {
        if (debriefingResult.exp.result == ::STATS_RESULT_SUCCESS)
          return {winAwardColor="yes"}
        return null
      }
    icon = ""
    canShowRewardAsValue = true
  }
  { id = "MissionCoop"
    rewardId = "Mission"
    isUsedInRecount = false //duplicate mission row
    type = "exp"
    showByModes = function(gm) { return gm != ::GM_DOMINATION }
    text = "debriefing/Mission"
    icon = ""
    canShowRewardAsValue = true
  }
  { id = "Unlocks"
    type = "exp"
    icon = ""
    isCountedInUnits = false
  }
  { id = "FriendlyKills"
    showByModes = isGameModeVersus
  }
  { id = "TournamentBaseReward"
    type = "exp"
    text = "debriefing/tournamentBaseReward"
    icon = ""
    canShowRewardAsValue = true
  }
  { id = "FirstWinInDay"
    type = "exp"
    text = "debriefing/firstWinInDay"
    icon = ""
    tooltipComment = function() {
      local firstWinMulRp = (debriefingResult?.xpFirstWinInDayMul ?? 1.0).tointeger()
      local firstWinMulWp = (debriefingResult?.wpFirstWinInDayMul ?? 1.0).tointeger()
      return ::loc("reward") + ::loc("ui/colon") + ::g_string.implode([
        firstWinMulRp > 1 ? ::getRpPriceText("x" + firstWinMulRp, true) : "",
        firstWinMulWp > 1 ? ::getWpPriceText("x" + firstWinMulWp, true) : "",
      ], ::loc("ui/comma"))
    }
    canShowRewardAsValue = true
    isCountedInUnits = false
  }
  { id = "Total"
    text = "debriefing/total"
    icon = ""
    type = "exp"
    showEvenEmpty = true
    rowProps =  { totalColor="yes", totalRowStyle="first" }
    canShowRewardAsValue = true
    showOnlyWhenFullResult = true
    isOverall = true
    tooltipExtraRows = function() {
      local res = []
      foreach (row in debriefingRows)
        if (!row.isCountedInUnits)
          res.append(row.id)
      return res
    }
    tooltipComment = function() {
      local texts = []
      local tournamentWp   = ::getTblValue("wpTournamentBaseReward",   debriefingResult.exp, 0)
      local tournamentGold = ::getTblValue("goldTournamentBaseReward", debriefingResult.exp, 0)
      local goldTotal = ::getTblValue("goldTotal",   debriefingResult.exp, 0)
      if (tournamentWp || tournamentGold)
        texts.append(::loc("debriefing/tournamentBaseReward") + ::loc("ui/colon") + ::Cost(tournamentWp, tournamentGold))
      else if (goldTotal)
        texts.append(::loc("chapters/training") + ::loc("ui/colon") + ::Cost(0, goldTotal))
      local raceWp = ::getTblValue("wpRace",  debriefingResult.exp, 0)
      local raceRp = ::getTblValue("expRace", debriefingResult.exp, 0)
      if (raceWp || raceRp)
        texts.append(::loc("events/chapter/race") + ::loc("ui/colon") + ::Cost(raceWp, 0, 0, raceRp))
      return texts.len() ? ::colorize("commonTextColor", ::g_string.implode(texts, "\n")) : null
    }
  }
  {
    id = "ModsTotal"
    text = "debriefing/total/modsResearch"
    icon = ""
    rewardType = "exp"
    rowProps =  { totalColor="yes", totalRowStyle="first" }
    canShowRewardAsValue = true
    showByModes = function(gm) { return gm == ::GM_DOMINATION }
    showOnlyWhenFullResult = true
    isOverall = false
  }
  { id = "UnitTotal"
    text = "debriefing/total/unitsResearch"
    icon = ""
    rewardType = "exp"
    rowProps =  { totalColor="yes", totalRowStyle="last" }
    showOnlyWhenFullResult = true
    isOverall = true
    tooltipComment = function() { return ::loc("debriefing/EfficiencyReason") }
    tooltipRowBonuses = function(unitId, unitData) {
      local unitTypeName = ::getAircraftByName(unitId)?.unitType?.name ?? ""
      local investUnit = ::getAircraftByName(debriefingResult?.exp?["investUnitName" + unitTypeName])
      local prevUnit = ::getPrevUnit(investUnit)
      if (unitId != prevUnit?.name)
        return null

      local noBonus = unitData?.expTotal ?? 0
      local bonus = (unitData?.expInvestUnit ?? 0) - noBonus
      if (noBonus <= 0 || bonus <= 0)
        return null

      local comment = ::colorize("fadedTextColor", ::loc("debriefing/bonusToNextUnit",
        { unitName = ::colorize("userlogColoredText", ::getUnitName(investUnit)) }))

      return {
        sources = [
          NO_BONUS.__merge({ text = ::Cost().setRp(noBonus).tostring() }),
          PREV_UNIT_EFFICIENCY.__merge({ text = $"{::Cost().setRp(bonus).tostring()}{comment}" })
        ]
      }
    }
  }
  { id = "ecSpawnScore"
    text = "debriefing/total/ecSpawnScore"
    icon = "multiplayer/spawnScore/abbr"
    showByValue = function (value) {return value > 0}
    rowProps = { totalColor="yes", totalRowStyle="last" }
    tooltipComment = function() {return ::loc("debriefing/ecSpawnScore")}
    getValueFunc = function() {
                              local logs = ::getUserLogsList({
                                show = [
                                  ::EULT_SESSION_RESULT
                                  ::EULT_EARLY_SESSION_LEAVE
                                ]
                                currentRoomOnly = true
                              })

                              local result = 0
                              foreach (log in logs)
                              {
                                result = ::getTblValue(id, log, 0)
                                if (result > 0)
                                  break
                              }

                              return result
                            }
  }
  { id = "wwSpawnScore"
    text = "debriefing/total/wwSpawnScore"
    icon = "multiplayer/spawnScore/abbr"
    showByValue = function (value) {return value > 0}
    rowProps = { totalColor="yes", totalRowStyle="last" }
    tooltipComment = function() {return ::loc("debriefing/wwSpawnScore")}
    getValueFunc = function() {
                              local logs = ::getUserLogsList({
                                show = [
                                  ::EULT_SESSION_RESULT
                                  ::EULT_EARLY_SESSION_LEAVE
                                ]
                                currentRoomOnly = true
                              })

                              local result = 0
                              foreach (log in logs)
                              {
                                result = log?[id] ?? 0
                                if (result > 0)
                                  break
                              }

                              return result
                            }
  }
  { id = "timePlayed"
    customValueName = "timePlayed"
    type = "tim"
    icon = ""
  }
  { id = "sessionTime"
    customValueName = "sessionTime"
    text = "debriefing/missionDuration"
    type = "tim"
    icon = ""
    hideTooltip = true
    hideUnitSessionTimeInTooltip = true
  }
  { id = "Free"
    text = "debriefing/freeExp"
    icon = ""
    rewardType = "exp"
    isFreeRP = true
    isOverall = true
    hideTooltip = true
  }
]
//  notReduceByPrem = ["total", "Premium", "Unlocks"]

//fill all rows by default params
foreach(idx, row in debriefingRows)
{
  if (typeof(row) != "table")
    debriefingRows[idx] = { id = row }
  foreach(param, value in debriefingRowDefault)
    if (!(param in debriefingRows[idx]))
      debriefingRows[idx][param] <- value
}

local isDebriefingResultFull = @() (debriefingResult != null
  && (!debriefingResult.isMp
    || !debriefingResult.useFinalResults
    || debriefingResult.exp.result == ::STATS_RESULT_SUCCESS
    || debriefingResult.exp.result == ::STATS_RESULT_FAIL
    || (debriefingResult.gm != ::GM_DOMINATION
      && !!(debriefingResult.gameType & ::GT_RACE)
      && debriefingResult.exp.result != ::STATS_RESULT_IN_PROGRESS
    )
  )
)

local function updateDebriefingExpInvestmentData() {
  local gatheredTotalModsExp = 0
  local gatheredTotalUnitExp = 0
  foreach(airName, airData in debriefingResult.exp.aircrafts)
  {
    local expModuleTotal = ::getTblValue("expInvestModuleTotal", airData, 0)
    airData.expModsTotal <- expModuleTotal
    gatheredTotalModsExp += expModuleTotal

    local expUnitTotal = ::getTblValue("expInvestUnitTotal", airData, 0)
    airData.expUnitTotal <- expUnitTotal
    gatheredTotalUnitExp += expUnitTotal

    airData.expModuleCapped <- expModuleTotal != ::getTblValue("expInvestModule", airData, 0)
        //we cant correct recount bonus multiply on not total exp when they equal
  }

  local expTotal = ::getTblValue("expTotal", debriefingResult.exp, 0)
  debriefingResult.exp.pctUnitTotal <- expTotal > 0 ? gatheredTotalUnitExp.tofloat() / expTotal : 0.0

  debriefingResult.exp.expModsTotal <- gatheredTotalModsExp
  debriefingResult.exp.expUnitTotal <- gatheredTotalUnitExp
}

local function getStatReward(row, currency, keysArray = []) {
  if (!keysArray.len()) // empty means pre-calculated final value
  {
    local finalId = currency + row.getRewardId()
    return ::getTblValue(finalId, debriefingResult.exp, 0)
  }

  local result = 0
  local tableId = getTableNameById(row)
  local currencyName = ::g_string.toUpper(currency, 1)
  foreach(key in keysArray)
    result += debriefingResult.exp?[tableId][key + currencyName] ?? 0
  return result
}

local getCountedResultId = @(row, state, currency)
  $"{getTableNameById(row)}_debrState{state}_{currency}"

local function calculateDebriefingTabularData(addVirtPremAcc = false) {
  local countTable = !addVirtPremAcc ?
  {
    [debrState.showMyStats] = ["noBonus"],
    [debrState.showBonuses] = [],
  }
  :
  {
    [debrState.showMyStats] = ["noPremAcc"],
    [debrState.showBonuses] = [],
  }

  debriefingResult.counted_result_by_debrState <- {}
  foreach (row in debriefingRows)
  {
    if (!row.isUsedInRecount)
      continue
    if (::u.isEmpty(debriefingResult.exp?[getTableNameById(row)]))
      continue

    foreach(currency in [ "wp", "exp" ])
      foreach(state, statsArray in countTable)
      {
        local key = getCountedResultId(row, state, currency)
        local reward = getStatReward(row, currency, statsArray)
        debriefingResult.counted_result_by_debrState[key] <- reward
      }
  }
}

local function recountDebriefingResult() {
  local gm = ::get_game_mode()
  local gt = ::get_game_type()

  foreach(row in debriefingRows)
  {
    row.show = row.isVisible(gm, gt, isDebriefingResultFull)
    row.showInTooltips = row.show || row.isVisible(gm, gt, isDebriefingResultFull, true)
    if (!row.show && !row.showInTooltips)
      continue

    local isRowEmpty = true
    foreach(currency in ["wp", "exp", "gold"])
    {
      local id = currency + row.getRewardId()
      local result = ::getTblValue(id, debriefingResult.exp, 0)
      row[currency] <- result
      isRowEmpty = isRowEmpty && !result
    }

    if (row.getValueFunc)
      row.value = row.getValueFunc()
    else if (row.customValueName)
      row.value = ::getTblValue(row.customValueName, debriefingResult.exp, 0)
    else
      row.value = ::getTblValue(row.type + row.getRewardId(), debriefingResult.exp, 0)
    isRowEmpty = isRowEmpty && !row.value

    local isHide = (row.showByValue && !row.showByValue(row.value))
      || (isRowEmpty && !row.isVisibleWhenEmpty())

    if (isHide)
    {
      row.show = false
      row.showInTooltips = false
    }
  }

  foreach(row in debriefingRows)
  {
    if (row.rewardType in row)
      row.reward = row[row.rewardType]

    if (row.reward > 0 && (row.value > 0 || !row.canShowRewardAsValue))
      debriefingResult.needRewardColumn = true
  }
}

/**
 * Returns proper "haveTeamkills" value from related userlogs.
 */
local function debriefingResultHaveTeamkills() {
  local logs = getUserLogsList({
    show = [
      ::EULT_EARLY_SESSION_LEAVE
      ::EULT_SESSION_RESULT
      ::EULT_AWARD_FOR_PVE_MODE
    ]
    currentRoomOnly = true
  })
  local result = false
  foreach (log in logs)
    result = result || (log?.haveTeamkills ?? false)
  return result
}

local function getDebriefingBaseTournamentReward() {
  local result = ::Cost()

  local logs = getUserLogsList({
    show = [
      ::EULT_SESSION_RESULT
    ]
    currentRoomOnly = true
  })
  if (logs.len())
  {
    result.wp   = ::getTblValue("baseTournamentWp", logs[0], 0)
    result.gold = ::getTblValue("baseTournamentGold", logs[0], 0)
  }

  if (!result.isZero())
    return result

  logs = ::getUserLogsList({
    show = [::EULT_CHARD_AWARD]
    currentRoomOnly = true
    filters = { rewardType = ["TournamentReward"] }
  })
  if (logs.len())
  {
    result.wp   = ::getTblValue("wpEarned", logs[0], 0)
    result.gold = ::getTblValue("goldEarned", logs[0], 0)
  }

  return result
}

local function getDebriefingActiveBoosters() {
  local logs = getUserLogsList({
    show = [
      ::EULT_EARLY_SESSION_LEAVE
      ::EULT_SESSION_RESULT
      ::EULT_AWARD_FOR_PVE_MODE
    ]
    currentRoomOnly = true
  })
  foreach (log in logs)
  {
    local boosters = log?.affectedBoosters.activeBooster ?? []
    if (typeof(boosters) != "array")
      boosters = [boosters]
    if (boosters.len() > 0)
      return boosters
  }
  return []
}

/**
 * Returns table with active wager related data with following data format:
 * {
 *   wagerShopId = ... (null - if no wager found for recent battle)
 *   wagerInventoryId = ... (null - if wager is no longer active)
 *   wagerResult = ... (null - if result is unknown)
 * }
 */
local function getDebriefingActiveWager() {
  // First, we see is there's any active wager at all.
  local logs = getUserLogsList({
    show = [
      ::EULT_EARLY_SESSION_LEAVE
      ::EULT_SESSION_RESULT
      ::EULT_AWARD_FOR_PVE_MODE
    ]
    currentRoomOnly = true
  })
  local wagerIds
  foreach (log in logs)
  {
    wagerIds = log?.container.affectedWagers.itemId
    if (wagerIds != null)
      break
  }
  if (wagerIds == null || (typeof(wagerIds) == "array" && wagerIds.len() == 0)) // Nothing found.
    return null

  local data = {
    wagerInventoryId = null
    wagerShopId = typeof(wagerIds) == "array" ? wagerIds[0] : wagerIds // See buildTableFromBlk.
    wagerResult = null
    wagerWpEarned = 0
    wagerGoldEarned = 0
    wagerNumWins = 0
    wagerNumFails = 0
    wagerText = ::loc("item/wager/endedWager/main")
  }

  // Then we look up for it's result.
  logs = getUserLogsList({
    show = [
      ::EULT_CHARD_AWARD
    ]
    currentRoomOnly = true
  })
  foreach (log in logs)
  {
    local wagerShopId = ::getTblValue("id", log)
    if (wagerShopId != data.wagerShopId)
      continue
    local rewardType = ::getTblValue("rewardType", log)
    if (rewardType == null)
      continue
    data.wagerResult = rewardType
    data.wagerInventoryId = ::getTblValue("uid", log)
    data.wagerWpEarned = ::getTblValue("wpEarned", log, 0)
    data.wagerGoldEarned = ::getTblValue("goldEarned", log, 0)
    data.wagerNumWins = ::getTblValue("numWins", log, 0)
    data.wagerNumFails = ::getTblValue("numFails", log, 0)
    break
  }

  if (data.wagerWpEarned != 0 || data.wagerGoldEarned != 0)
  {
    local money = ::Money(money_type.cost, data.wagerWpEarned, data.wagerGoldEarned)
    local rewardText = money.tostring()
    local locParams = {
      wagerRewardText = rewardText
    }
    data.wagerText += "\n" + ::loc("item/wager/endedWager/rewardPart", locParams)
  }

  return data
}

local function getDebriefingEventId() {
  local logs = ::getUserLogsList({
    show = [::EULT_SESSION_RESULT]
    currentRoomOnly = true
  })

  return logs.len() ? ::getTblValue("eventId", logs[0]) : null
}

/**
 * Joins multiple rows rewards into new single row.
 */
local function debriefingJoinRowsIntoRow(exp, destRowId, srcRowIdsArray) {
  local tables = [ exp ]
  if (exp?.aircrafts)
    foreach (unitId, tbl in exp.aircrafts)
      tables.append(tbl)

  foreach (tbl in tables)
    foreach (prefix in [ "tbl", "wp", "exp", "num" ])
    {
      local keyTo = prefix + destRowId
      if (keyTo in tbl)
        continue
      foreach (srcRowId in srcRowIdsArray)
      {
        local keyFrom = prefix + srcRowId
        if (!(keyFrom in tbl))
          continue
        local val = tbl[keyFrom]
        local isTable = ::u.isTable(val)
        if (!(keyTo in tbl))
          tbl[keyTo] <- isTable ? (clone val) : val
        else
        {
          if (::is_numeric(val))
            tbl[keyTo] += val
          else if (isTable)
            foreach (i, v in val)
              if (::is_numeric(v))
              tbl[keyTo][i] += v
        }
      }
    }
}

/**
 * Applies xpFirstWinInDayMul and wpFirstWinInDayMul to debriefing result totals,
 * free exp, units and mods research (but not to expTotal in aircrafts).
 * Adds FirstWinInDay as a separate bonus row.
 */
local function debriefingApplyFirstWinInDayMul(exp, debrResult)
{
  local logs = ::getUserLogsList({ show = [::EULT_SESSION_RESULT], currentRoomOnly = true })
  if (!logs.len())
    return

  local xpFirstWinInDayMul = logs[0]?.xpFirstWinInDayMul ?? 1.0
  local wpFirstWinInDayMul = logs[0]?.wpFirstWinInDayMul ?? 1.0
  if (xpFirstWinInDayMul == 1 && wpFirstWinInDayMul == 1)
    return

  local xpTotalDebr = exp?.expTotal ?? 0
  local xpTotalUserlog = logs[0]?.xpEarned ?? 0
  local xpCheck = xpTotalDebr * xpFirstWinInDayMul
  local isNeedMulXp = (xpCheck > xpTotalDebr && ::fabs(xpCheck - xpTotalDebr) > ::fabs(xpCheck - xpTotalUserlog))

  local wpTotalDebr = exp?.wpTotal  ?? 0
  local wpTotalUserlog = logs[0]?.wpEarned ?? 0
  local wpCheck = wpTotalDebr * wpFirstWinInDayMul
  local isNeedMulWp = (wpCheck > wpTotalDebr && ::fabs(wpCheck - wpTotalDebr) > ::fabs(wpCheck - wpTotalUserlog))

  if (isNeedMulXp)
  {
    local keys = [ "expTotal", "expFree", "expInvestUnit", "expInvestUnitTotal" ]
    foreach (ut in unitTypes.types)
      keys.append(
        "expInvestUnit" + ut.name,
        "expInvestUnitTotal" + ut.name
      )
    foreach (key in keys)
      if ((key in exp) && exp[key] > 0)
        exp[key] = (exp[key] * xpFirstWinInDayMul).tointeger()

    if ("aircrafts" in exp)
      foreach (unitData in exp.aircrafts)
        foreach (key in keys)
          if (key != "expTotal")
            if ((key in unitData) && unitData[key] > 0)
              unitData[key] = (unitData[key] * xpFirstWinInDayMul).tointeger()

    exp.expFirstWinInDay <- ::max(0, exp.expTotal - xpTotalDebr)
    debrResult.xpFirstWinInDayMul <- xpFirstWinInDayMul
  }

  if (isNeedMulWp)
  {
    exp.wpTotal <- (wpTotalDebr * wpFirstWinInDayMul).tointeger()
    exp.wpFirstWinInDay <- ::max(0, exp.wpTotal - wpTotalDebr)
    debrResult.wpFirstWinInDayMul <- wpFirstWinInDayMul
  }
}

local function getPveRewardTrophyInfo(sessionTime, sessionActivity, isSuccess) {
  local pveTrophyName = ::getTblValue("pveTrophyName", ::get_current_mission_info_cached())
  if (::u.isEmpty(pveTrophyName))
    return null

  local warpoints = ::get_warpoints_blk()

  local isEnoughActivity = sessionActivity >= ::getTblValue("pveTrophyMinActivity", warpoints, 1)
  local reachedTrophyName = isEnoughActivity ? ::get_pve_trophy_name(sessionTime, isSuccess) : null
  local receivedTrophyName = null

  if (reachedTrophyName)
  {
    local logs = ::getUserLogsList({
      show = [
        ::EULT_SESSION_RESULT
      ]
      currentRoomOnly = true
    })
    local trophyRewardsList = logs?[0].container.trophies ?? {}
    receivedTrophyName = (reachedTrophyName in trophyRewardsList) ? reachedTrophyName : null
  }

  local victoryStageTime = ::getTblValue("pveTimeAwardWinVisual", warpoints, 1)
  local stagesTime = []
  for (local i = 0; i <= ::getTblValue("pveTrophyMaxStage", warpoints, -1); i++)
  {
    local time = ::getTblValue("pveTimeAwardStage" + i, warpoints, -1)
    if (time > 0 && time < victoryStageTime)
      stagesTime.append(time)
  }
  stagesTime.append(victoryStageTime)

  local visSessionTime = isSuccess ? victoryStageTime : sessionTime.tointeger()
  if (!isSuccess)
  {
    local preVictoryStageTime = stagesTime.len() > 1 ? stagesTime[stagesTime.len() - 2] : 0
    local maxTime = preVictoryStageTime + (victoryStageTime - preVictoryStageTime) / 2
    visSessionTime = ::min(visSessionTime, maxTime)
  }

  return {
    isVisible = isEnoughActivity && reachedTrophyName != null
    warnLowActivity = ! isEnoughActivity
    reachedTrophyName  = reachedTrophyName
    receivedTrophyName = receivedTrophyName
    isRewardReceivedEarlier = reachedTrophyName != null && ! receivedTrophyName
    sessionTime = visSessionTime
    victoryStageTime = victoryStageTime
    stagesTime = stagesTime
  }
}

local function getDebriefingGiftItemsInfo(skipItemId = null) {
  local res = []

  // Collecting Marketplace items
  local logs = ::getUserLogsList({
    show = [ ::EULT_INVENTORY_ADD_ITEM ]
    currentRoomOnly = true
    disableVisible = true
  })
  foreach (log in logs)
    foreach (data in log)
    {
      if (typeof(data) != "table" || !("itemDefId" in data))
        continue

      res.append({item=data.itemDefId, count=data?.quantity ?? 1, needOpen=false, enableBackground=true})
      ::ItemsManager.findItemById(data.itemDefId) // Requests itemdefs for unknown items
    }

  // Collecting trophies and items
  logs = ::getUserLogsList({
    show = [ ::EULT_SESSION_RESULT ]
    currentRoomOnly = true
    disableVisible = true
  })
  foreach (rewardType in [ "trophies", "items" ])
  {
    local rewards = logs?[0]?.container?[rewardType] ?? {}
    foreach (id, count in rewards)
      if (id != skipItemId)
        res.append({item=id, count=count, needOpen=rewardType == "trophies", enableBackground=true})
  }

  return res.len() ? res : null
}

local function gatherDebriefingResult() {
  local gm = ::get_game_mode()
  if (gm==::GM_DYNAMIC)
    dynamicResult = ::dynamic_apply_status();

  debriefingResult = {}

  debriefingResult.isSucceed <- (::get_mission_status() == ::MISSION_STATUS_SUCCESS)
  debriefingResult.restoreType <- ::get_mission_restore_type()
  debriefingResult.gm <- gm
  debriefingResult.gameType <- ::get_game_type()
  debriefingResult.isTeamplay <- ::is_mode_with_teams(debriefingResult.gameType)

  local isInRoom = ::SessionLobby.isInRoom()
  debriefingResult.isInRoom <- isInRoom
  debriefingResult.mGameMode <- isInRoom ? ::SessionLobby.getMGameMode() : null
  debriefingResult.isSpectator <- isInRoom && ::SessionLobby.spectator

  debriefingResult.isMp <- ::is_multiplayer()
  debriefingResult.isReplay <- ::is_replay_playing()
  debriefingResult.sessionId <- ::get_mp_session_id()
  debriefingResult.useFinalResults <- ::getTblValue("useFinalResults", ::get_current_mission_info_cached(), false)
  debriefingResult.mpTblTeams <- ::get_mp_tbl_teams()
  debriefingResult.unitTypesMask <- ::SessionLobby.getUnitTypesMask()
  debriefingResult.playersInfo <- clone ::SessionLobby.getPlayersInfo()
  debriefingResult.missionDifficultyInt <-::get_mission_difficulty_int()
  debriefingResult.isSymmetric <- ::SessionLobby.getPublicParam("symmetricTeams", true)
  debriefingResult.missionObjectives <- ::g_mission_type.getCurrentObjectives()


  if (gm == ::GM_BENCHMARK)
    debriefingResult.benchmark <- ::stat_get_benchmark()

  debriefingResult.numberOfWinningPlaces <- ::get_race_winners_count()
  debriefingResult.mplayers_list <- ::get_mplayers_list(::GET_MPLAYERS_LIST, true)

  //Fill Exp and WP table in correct format
  local exp = ::stat_get_exp() || {}

  debriefingResult.expDump <- ::u.copy(exp) // Untouched copy for debug

  // Put exp data compatibility changes here.

  // Temporary compatibility fix for 1.85.0.X
  if (exp?.numAwardDamage && exp?.expAwardDamage)
  {
    local tables = [ exp ]
    foreach (a in exp?.aircrafts ?? {})
      tables.append(a)
    foreach (t in tables)
    {
      t.numAwardDamage <- t?.expAwardDamage ?? 0
      t.expAwardDamage <- 0
    }
  }

  foreach (row in debriefingRows)
    if (row.joinRows)
      debriefingJoinRowsIntoRow(exp, row.getRewardId(), row.joinRows)

  debriefingApplyFirstWinInDayMul(exp, debriefingResult)

  debriefingResult.exp <- clone exp

  if (!("result" in debriefingResult.exp))
    debriefingResult.exp.result <- ::STATS_RESULT_FAIL

  debriefingResult.country <- ::get_local_player_country()
  debriefingResult.localTeam <- ::get_mp_local_team()
  debriefingResult.friendlyTeam <- ::get_player_army_for_hud()
  debriefingResult.haveTeamkills <- debriefingResultHaveTeamkills()
  debriefingResult.activeBoosters <- getDebriefingActiveBoosters()
  debriefingResult.activeWager <- getDebriefingActiveWager()
  debriefingResult.eventId <- getDebriefingEventId()
  debriefingResult.chatLog <- ::get_gamechat_log_text()
  debriefingResult.logForBanhammer <- mpChatModel.getLogForBanhammer()

  debriefingResult.exp.timBattleTime <- ::getTblValue("battleTime", debriefingResult.exp, 0)
  debriefingResult.needRewardColumn <- false
  debriefingResult.mulsList <- []

  debriefingResult.roomUserlogs <- []
  for (local i = ::get_user_logs_count() - 1; i >= 0; i--)
    if (::is_user_log_for_current_room(i))
    {
      local blk = ::DataBlock()
      ::get_user_log_blk_body(i, blk)
      debriefingResult.roomUserlogs.append(blk)
    }

  if (!("aircrafts" in debriefingResult.exp))
    debriefingResult.exp.aircrafts <- []

  // Deleting killstreak flyout units (has zero sessionTime), because it has some stats,
  // (kills, etc) which are calculated TWICE (in both player's unit, and in killstreak unit).
  // So deleting info about killstreak units is very important.
  local aircraftsForDelete = []
  foreach(airName, airData in debriefingResult.exp.aircrafts)
    if (airData.sessionTime == 0 || !::getAircraftByName(airName))
      aircraftsForDelete.append(airName)
  foreach(airName in aircraftsForDelete)
    debriefingResult.exp.aircrafts.rawdelete(airName)

  debriefingResult.exp["tntDamage"] <- ::getTblValue("numDamage", debriefingResult.exp, 0)
  foreach(airName, airData in debriefingResult.exp.aircrafts)
    airData["tntDamage"] <- ::getTblValue("numDamage", airData, 0)

  if ((::get_game_type() & ::GT_RACE) && ("get_race_lap_times" in getroottable()))
  {
    debriefingResult.exp.ptmBestLap <- ::get_race_best_lap_time()
    debriefingResult.exp.ptmLapTimesArray <- ::get_race_lap_times()
  }

  local sessionTime = ::getTblValue("sessionTime", debriefingResult.exp, 0)
  local score = 0.0
  local timePlayed = 0.0
  foreach(airName, airData in debriefingResult.exp.aircrafts)
  {
    score += airData.score
    timePlayed += (airData.sessionTime+0.5).tointeger().tofloat()
    airData.timBattleTime <- airData.battleTime
    airData.pctActivity <- 0
  }
  debriefingResult.exp.timePlayed <- timePlayed
  local sessionActivity = debriefingResult.exp?.activity ?? 0

  local pveRewardInfo = getPveRewardTrophyInfo(sessionTime, sessionActivity, debriefingResult.isSucceed)
  if (pveRewardInfo)
    debriefingResult.pveRewardInfo <- pveRewardInfo
  local giftItemsInfo = getDebriefingGiftItemsInfo(pveRewardInfo?.receivedTrophyName)
  if (giftItemsInfo)
    debriefingResult.giftItemsInfo <- giftItemsInfo

  local trournamentBaseReward = getDebriefingBaseTournamentReward()
  debriefingResult.exp.wpTournamentBaseReward <- trournamentBaseReward.wp
  debriefingResult.exp.goldTournamentBaseReward <- trournamentBaseReward.gold
  local wpTotal = ::getTblValue("wpTotal", debriefingResult.exp, 0)
  if (wpTotal >= 0)
    debriefingResult.exp.wpTotal <- wpTotal + trournamentBaseReward.wp

  debriefingResult.exp.expMission <- ::getTblValue("expMission", exp, 0) + ::getTblValue("expRace", exp, 0)
  debriefingResult.exp.wpMission <- ::getTblValue("wpMission", exp, 0) + ::getTblValue("wpRace", exp, 0)

  local missionRules = ::g_mis_custom_state.getCurMissionRules()
  debriefingResult.overrideCountryIconByTeam <- {
    [::g_team.A.code] = missionRules.getOverrideCountryIconByTeam(::g_team.A.code),
    [::g_team.B.code] = missionRules.getOverrideCountryIconByTeam(::g_team.B.code)
  }
  updateDebriefingExpInvestmentData()
  calculateDebriefingTabularData(false)
  recountDebriefingResult()

  if (::is_mplayer_peer())
    ::destroy_session_scripted()
}

local function debriefingAddVirtualPremAccToStatTbl(data, isRoot) {
  local totalVirtPremAccExp = data?.tblTotal.virtPremAccExp ?? 0
  if (totalVirtPremAccExp > 0)
  {
    local list = isRoot ? [ "expFree" ] : [ "expInvestModuleTotal", "expInvestUnitTotal", "expModsTotal", "expUnitTotal" ]
    if (isRoot)
      foreach (ut in unitTypes.types)
        list.append([ "expInvestUnitTotal" + ut.name])
    foreach (id in list)
      if (::getTblValue(id, data, 0) > 0)
        data[id] += totalVirtPremAccExp
  }

  if (isRoot)
    foreach (ut in unitTypes.types)
    {
      local typeName = ut.name
      local unitId = ::getTblValue("investUnitName" + typeName, data, "")
      if (::u.isEmpty(unitId))
        continue
      local unitVirtPremAccExp = data?.aircrafts[unitId].tblTotal.virtPremAccExp ?? 0
      if (unitVirtPremAccExp > 0 && ::getTblValue("expInvestUnit" + typeName, data, 0) > 0)
        data["expInvestUnit" + typeName] += unitVirtPremAccExp
    }

  foreach (row in debriefingRows)
  {
    if (!row.isUsedInRecount)
      continue
    local rowTbl = data?[getTableNameById(row)]
    if (::u.isEmpty(rowTbl))
      continue
    foreach(suffix in [ "Exp", "Wp" ])
    {
      local virtPremAcc = ::getTblValue("virtPremAcc" + suffix, rowTbl, 0)
      if (virtPremAcc <= 0)
        continue
      rowTbl["premAcc" + suffix] <- virtPremAcc

      local precalcResultId = suffix.tolower() + row.getRewardId()
      local origFinal = ::getTblValue(precalcResultId, data, 0)
      if (origFinal >= 0)
      {
        data["noPremAcc" + suffix] <- origFinal
        data[precalcResultId] += virtPremAcc
      }
    }
  }
}

/**
 * Emulates last mission rewards gain (by adding virtPremAccWp/virtPremAccExp) on byuing Premium Account from Debriefing window.
 */
local function debriefingAddVirtualPremAcc() {
  if (!::havePremium())
    return

  debriefingAddVirtualPremAccToStatTbl(debriefingResult.exp, true)
  if ("aircrafts" in debriefingResult.exp)
    foreach (unitData in debriefingResult.exp.aircrafts)
      debriefingAddVirtualPremAccToStatTbl(unitData, false)

  updateDebriefingExpInvestmentData()
  calculateDebriefingTabularData(true)
  recountDebriefingResult()
}

local function getMoneyFromDebriefingResult() {
  local res = ::Cost()
  gatherDebriefingResult()
  if (debriefingResult == null)
    return res

  local exp = debriefingResult.exp
  res.wp    = exp?.wpMission ?? 0
  res.gold  = exp?.goldMission ?? 0
  res.frp   = exp?.expMission ?? 0
  return res
}

::gather_debriefing_result <- @() gatherDebriefingResult() // used from native code

return {
  getDebriefingResult = @() debriefingResult
  setDebriefingResult = @(res) debriefingResult = res
  debriefingRows
  getDynamicResult = @() dynamicResult
  getMoneyFromDebriefingResult
  isDebriefingResultFull
  gatherDebriefingResult
  getCountedResultId
  debriefingAddVirtualPremAcc
  getTableNameById
}
