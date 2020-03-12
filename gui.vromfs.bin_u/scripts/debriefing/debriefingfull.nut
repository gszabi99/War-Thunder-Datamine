//::g_script_reloader.loadOnce("!temp/a_test.nut") //!!debug only!!
local mpChatModel = require("scripts/chat/mpChatModel.nut")

::debriefing_skip_all_at_once <- true
::min_values_to_show_reward_premium <- { wp = 0, exp = 0 }

::g_script_reloader.registerPersistentData("DebriefingGlobals", ::getroottable(),
  [
    "min_values_to_show_reward_premium"
  ])

::debriefing_result <- null
::dynamic_result <- -1
::debriefing_countries <- {}
::check_for_victory <- false

::debriefing_row_defaults <- {
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
  tooltipExtraRows = null //function(), array
  tooltipComment = null  //string function()
  tooltipRowBonuses = @(unitId, unitData) null
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

::debriefing_rows <- [
  { id = "AirKills"
    showByModes = ::is_gamemode_versus
    showByTypes = function(gt) {return (!(gt & ::GT_RACE) && !(gt & ::GT_FOOTBALL))}
    text = "multiplayer/air_kills"
    icon = "icon/mpstats/kills"
    isVisibleWhenEmpty = @() !!(::g_mission_type.getCurrentObjectives() & MISSION_OBJECTIVE.KILLS_AIR)
  }
  { id = "GroundKills"
    showByTypes = function(gt) {return (!(gt & ::GT_RACE) && !(gt & ::GT_FOOTBALL))}
    showByModes = ::is_gamemode_versus
    text = "multiplayer/ground_kills"
    icon = "icon/mpstats/groundKills"
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
    showByModes = ::is_gamemode_versus
    text = "multiplayer/naval_kills"
    icon = "icon/mpstats/navalKills"
    isVisibleWhenEmpty = @() !!(::g_mission_type.getCurrentObjectives() & MISSION_OBJECTIVE.KILLS_NAVAL)
  }
  "GroundKillsF"
  "NavalKillsF"
  { id = "Assist"
    showByModes = ::is_gamemode_versus
    text = "multiplayer/assists"
    icon = "icon/mpstats/assists"
  }
  "Critical"
  "Hit"
  { id = "Scouting"
    showByTypes = function(gt) {return (!(gt & ::GT_RACE) && !(gt & ::GT_FOOTBALL))}
    showByModes = ::is_gamemode_versus
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
    showByModes = ::is_gamemode_versus
  }
  { id = "Captures"
    type = "num"
    showByModes = ::is_gamemode_versus
    text = "multiplayer/zone_captures"
    icon = "icon/mpstats/captureZone"
  }
  "Landings"
  "Takeoffs"
  { id = "Sights"
    showByModes = ::is_gamemode_versus
    showByTypes = function(gt) {return (!(gt & ::GT_RACE) && !(gt & ::GT_FOOTBALL))}
  }
  { id = "Damage",
    type = "tnt"
    showByModes = ::is_gamemode_versus
    icon = "icon/mpstats/damageZone"
  }
  { id = "Destruction"
    type = ""
    showByModes = ::is_gamemode_versus
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
  { id = "BattleTime"
    type = "tim"
    icon = "icon/hourglass"
    tooltipComment = function() {
      return ::g_string.implode(::u.map([ "mainmenu/legend", "ui/colon", "icon/timer", "ui/mdash",
        "multiplayer/lifetime", "ui/comma", "icon/hourglass", "ui/mdash", "debriefing/BattleTime",
        "ui/dot" ], @(t) ::loc(t)))
    }
  }
  { id = "Activity"
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
      if (!debriefing_result || !("exp" in ::debriefing_result))
        return ::loc("debriefing/Mission")

      local checkVal = ::count_whole_reward_in_table(::getTblValue(::get_table_name_by_id(this),
        ::debriefing_result.exp), type, ["premMod", "premAcc"])
      if (checkVal < 0)
        return ::loc("debriefing/MissionNegative")

      if (::debriefing_result.exp.result == ::STATS_RESULT_SUCCESS)
        return ::loc("debriefing/MissionWinReward")
      else if (::debriefing_result.exp.result == ::STATS_RESULT_FAIL)
        return ::loc("debriefing/MissionLoseReward")
      return ::loc("debriefing/Mission")
    }
    rowProps = function() {
        if (::debriefing_result.exp.result == ::STATS_RESULT_SUCCESS)
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
    showByModes = ::is_gamemode_versus
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
      local firstWinMulRp = (::debriefing_result?.xpFirstWinInDayMul ?? 1.0).tointeger()
      local firstWinMulWp = (::debriefing_result?.wpFirstWinInDayMul ?? 1.0).tointeger()
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
      foreach (row in ::debriefing_rows)
        if (!row.isCountedInUnits)
          res.append(row.id)
      return res
    }
    tooltipComment = function() {
      local texts = []
      local tournamentWp   = ::getTblValue("wpTournamentBaseReward",   ::debriefing_result.exp, 0)
      local tournamentGold = ::getTblValue("goldTournamentBaseReward", ::debriefing_result.exp, 0)
      local goldTotal = ::getTblValue("goldTotal",   ::debriefing_result.exp, 0)
      if (tournamentWp || tournamentGold)
        texts.append(::loc("debriefing/tournamentBaseReward") + ::loc("ui/colon") + ::Cost(tournamentWp, tournamentGold))
      else if (goldTotal)
        texts.append(::loc("chapters/training") + ::loc("ui/colon") + ::Cost(0, goldTotal))
      local raceWp = ::getTblValue("wpRace",  ::debriefing_result.exp, 0)
      local raceRp = ::getTblValue("expRace", ::debriefing_result.exp, 0)
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
      local investUnit = ::getAircraftByName(::debriefing_result?.exp?["investUnitName" + unitTypeName])
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
        noBonus = ::Cost().setRp(noBonus).tostring()
        prevUnitEfficiency = ::Cost().setRp(bonus).tostring() + comment
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
  { id = "sessionTime"
    customValueName = "sessionTime"
    type = "tim"
    icon = ""
  }
  { id = "Free"
    text = "debriefing/freeExp"
    icon = ""
    rewardType = "exp"
    isFreeRP = true
    isOverall = true
  }
]
//  notReduceByPrem = ["total", "Premium", "Unlocks"]

//fill all rows by default params
foreach(idx, row in ::debriefing_rows)
{
  if (typeof(row) != "table")
    ::debriefing_rows[idx] = { id = row }
  foreach(param, value in ::debriefing_row_defaults)
    if (!(param in ::debriefing_rows[idx]))
      ::debriefing_rows[idx][param] <- value
}

global enum debrState {
  init
  showPlayers
  showMyStats
  showBonuses
  showAwards
  done
}

::isDebriefingResultFull <- function isDebriefingResultFull()
{
  return (::debriefing_result != null
          && (!::debriefing_result.isMp
              || !::debriefing_result.useFinalResults
              || ::debriefing_result.exp.result == ::STATS_RESULT_SUCCESS
              || ::debriefing_result.exp.result == ::STATS_RESULT_FAIL
              || (::debriefing_result.gm != ::GM_DOMINATION
                  && !!(::get_game_type() & ::GT_RACE)
                  && ::debriefing_result.exp.result != ::STATS_RESULT_IN_PROGRESS)
             )
         )
}

::gather_debriefing_result <- function gather_debriefing_result()
{
  local gm = ::get_game_mode()
  if (gm==::GM_DYNAMIC)
    ::dynamic_result = ::dynamic_apply_status();

  ::debriefing_result = {}

  ::debriefing_result.isSucceed <- (::get_mission_status() == ::MISSION_STATUS_SUCCESS)
  ::debriefing_result.restoreType <- ::get_mission_restore_type()
  ::debriefing_result.gm <- gm
  ::debriefing_result.isMp <- ::is_multiplayer()
  ::debriefing_result.sessionId <- ::get_mp_session_id()
  ::debriefing_result.useFinalResults <- ::getTblValue("useFinalResults", ::get_current_mission_info_cached(), false)
  ::debriefing_result.mpTblTeams <- ::get_mp_tbl_teams()
  ::debriefing_result.unitTypesMask <- ::SessionLobby.getUnitTypesMask()

  if (::get_game_mode() == ::GM_BENCHMARK)
    ::debriefing_result.benchmark <- ::stat_get_benchmark()

  ::debriefing_result.numberOfWinningPlaces <- ::get_race_winners_count()
  ::debriefing_result.mplayers_list <- ::get_mplayers_list(::GET_MPLAYERS_LIST, true)

  //Fill Exp and WP table in correct format
  local exp = ::stat_get_exp() || {}

  ::debriefing_result.expDump <- ::u.copy(exp) // Untouched copy for debug

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

  foreach (row in ::debriefing_rows)
    if (row.joinRows)
      ::debriefing_join_rows_into_row(exp, row.getRewardId(), row.joinRows)

  ::debriefing_apply_first_win_in_day_mul(exp, ::debriefing_result)

  ::debriefing_result.exp <- clone exp

  if (!("result" in ::debriefing_result.exp))
    ::debriefing_result.exp.result <- ::STATS_RESULT_FAIL

  ::debriefing_result.country <- ::get_local_player_country()
  ::debriefing_result.localTeam <- ::get_mp_local_team()
  ::debriefing_result.friendlyTeam <- ::get_player_army_for_hud()
  ::debriefing_result.haveTeamkills <- debriefing_result_have_teamkills()
  ::debriefing_result.activeBoosters <- ::get_debriefing_result_active_boosters()
  ::debriefing_result.activeWager <- ::get_debriefing_result_active_wager()
  ::debriefing_result.eventId <- ::get_debriefing_result_event_id()
  ::debriefing_result.chatLog <- ::get_gamechat_log_text()
  ::debriefing_result.logForBanhammer <- mpChatModel.getLogForBanhammer()

  ::debriefing_result.exp.timBattleTime <- ::getTblValue("battleTime", ::debriefing_result.exp, 0)
  ::debriefing_result.needRewardColumn <- false
  ::debriefing_result.mulsList <- []

  ::debriefing_result.roomUserlogs <- []
  for (local i = ::get_user_logs_count() - 1; i >= 0; i--)
    if (::is_user_log_for_current_room(i))
    {
      local blk = ::DataBlock()
      ::get_user_log_blk_body(i, blk)
      ::debriefing_result.roomUserlogs.append(blk)
    }

  if (!("aircrafts" in ::debriefing_result.exp))
    ::debriefing_result.exp.aircrafts <- []

  // Deleting killstreak flyout units (has zero sessionTime), because it has some stats,
  // (kills, etc) which are calculated TWICE (in both player's unit, and in killstreak unit).
  // So deleting info about killstreak units is very important.
  local aircraftsForDelete = []
  foreach(airName, airData in ::debriefing_result.exp.aircrafts)
    if (airData.sessionTime == 0 || !::getAircraftByName(airName))
      aircraftsForDelete.append(airName)
  foreach(airName in aircraftsForDelete)
    ::debriefing_result.exp.aircrafts.rawdelete(airName)

  ::debriefing_result.exp["tntDamage"] <- ::getTblValue("numDamage", ::debriefing_result.exp, 0)
  foreach(airName, airData in ::debriefing_result.exp.aircrafts)
    airData["tntDamage"] <- ::getTblValue("numDamage", airData, 0)

  if ((::get_game_type() & ::GT_RACE) && ("get_race_lap_times" in getroottable()))
  {
    ::debriefing_result.exp.ptmBestLap <- ::get_race_best_lap_time()
    ::debriefing_result.exp.ptmLapTimesArray <- ::get_race_lap_times()
  }

  local sesTimeAir = 0
  foreach(airName, airData in ::debriefing_result.exp.aircrafts)
    sesTimeAir += airData.sessionTime

  local sessionTime = ::getTblValue("sessionTime", ::debriefing_result.exp, 0)
  local score = 0.0
  foreach(airName, airData in ::debriefing_result.exp.aircrafts)
  {
    score += airData.score
    airData.timBattleTime <- airData.battleTime
    airData.pctActivity <- 0
  }
  local sessionActivity = ::player_activity_coef(score, ((sessionTime+0.5).tointeger()).tofloat())
  ::debriefing_result.exp.pctActivity <- sessionActivity

  local pveRewardInfo = ::get_pve_reward_trophy_info(sessionTime, sessionActivity, ::debriefing_result.isSucceed)
  if (pveRewardInfo)
    ::debriefing_result.pveRewardInfo <- pveRewardInfo
  local giftItemsInfo = ::get_debriefing_gift_items_info(pveRewardInfo?.receivedTrophyName)
  if (giftItemsInfo)
    ::debriefing_result.giftItemsInfo <- giftItemsInfo

  local trournamentBaseReward = ::debriefing_result_get_base_tournament_reward()
  ::debriefing_result.exp.wpTournamentBaseReward <- trournamentBaseReward.wp
  ::debriefing_result.exp.goldTournamentBaseReward <- trournamentBaseReward.gold
  local wpTotal = ::getTblValue("wpTotal", ::debriefing_result.exp, 0)
  if (wpTotal >= 0)
    ::debriefing_result.exp.wpTotal <- wpTotal + trournamentBaseReward.wp

  ::debriefing_result.exp.expMission <- ::getTblValue("expMission", exp, 0) + ::getTblValue("expRace", exp, 0)
  ::debriefing_result.exp.wpMission <- ::getTblValue("wpMission", exp, 0) + ::getTblValue("wpRace", exp, 0)

  ::update_debriefing_exp_investment_data()
  ::calculate_debriefing_tabular_data(false)
  ::recount_debriefing_result()
}

::update_debriefing_exp_investment_data <- function update_debriefing_exp_investment_data()
{
  local gatheredTotalModsExp = 0
  local gatheredTotalUnitExp = 0
  foreach(airName, airData in ::debriefing_result.exp.aircrafts)
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

  local expTotal = ::getTblValue("expTotal", ::debriefing_result.exp, 0)
  ::debriefing_result.exp.pctUnitTotal <- expTotal > 0 ? gatheredTotalUnitExp.tofloat() / expTotal : 0.0

  ::debriefing_result.exp.expModsTotal <- gatheredTotalModsExp
  ::debriefing_result.exp.expUnitTotal <- gatheredTotalUnitExp
}

::calculate_debriefing_tabular_data <- function calculate_debriefing_tabular_data(addVirtPremAcc = false)
{
  local getStatReward = function(row, currency, keysArray = [])
  {
    if (!keysArray.len()) // empty means pre-calculated final value
    {
      local finalId = currency + row.getRewardId()
      return ::getTblValue(finalId, ::debriefing_result.exp, 0)
    }

    local result = 0
    local tableId = ::get_table_name_by_id(row)
    local currencyName = ::g_string.toUpper(currency, 1)
    foreach(key in keysArray)
      result += ::debriefing_result.exp?[tableId][key + currencyName] ?? 0
    return result
  }

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

  ::debriefing_result.counted_result_by_debrState <- {}
  foreach (row in ::debriefing_rows)
  {
    if (!row.isUsedInRecount)
      continue
    if (::u.isEmpty(::getTblValue(::get_table_name_by_id(row), ::debriefing_result.exp)))
      continue

    foreach(currency in [ "wp", "exp" ])
      foreach(state, statsArray in countTable)
      {
        local key = ::get_counted_result_id(row, state, currency)
        local reward = getStatReward(row, currency, statsArray)
        ::debriefing_result.counted_result_by_debrState[key] <- reward
      }
  }
}

::get_counted_result_id <- function get_counted_result_id(row, state, currency)
{
  return ::get_table_name_by_id(row) + "_debrState" + state + "_" + currency
}

/**
 * Emulates last mission rewards gain (by adding virtPremAccWp/virtPremAccExp) on byuing Premium Account from Debriefing window.
 */
::debriefing_add_virtual_prem_acc <- function debriefing_add_virtual_prem_acc()
{
  if (!::havePremium())
    return

  ::debriefing_add_virtual_prem_acc_to_stat_tbl(::debriefing_result.exp, true)
  if ("aircrafts" in ::debriefing_result.exp)
    foreach (unitData in ::debriefing_result.exp.aircrafts)
      ::debriefing_add_virtual_prem_acc_to_stat_tbl(unitData, false)

  ::update_debriefing_exp_investment_data()
  ::calculate_debriefing_tabular_data(true)
  ::recount_debriefing_result()
}

::debriefing_add_virtual_prem_acc_to_stat_tbl <- function debriefing_add_virtual_prem_acc_to_stat_tbl(data, isRoot)
{
  local totalVirtPremAccExp = data?.tblTotal.virtPremAccExp ?? 0
  if (totalVirtPremAccExp > 0)
  {
    local list = isRoot ? [ "expFree" ] : [ "expInvestModuleTotal", "expInvestUnitTotal", "expModsTotal", "expUnitTotal" ]
    if (isRoot)
      foreach (ut in ::g_unit_type.types)
        list.append([ "expInvestUnitTotal" + ut.name])
    foreach (id in list)
      if (::getTblValue(id, data, 0) > 0)
        data[id] += totalVirtPremAccExp
  }

  if (isRoot)
    foreach (ut in ::g_unit_type.types)
    {
      local typeName = ut.name
      local unitId = ::getTblValue("investUnitName" + typeName, data, "")
      if (::u.isEmpty(unitId))
        continue
      local unitVirtPremAccExp = data?.aircrafts[unitId].tblTotal.virtPremAccExp ?? 0
      if (unitVirtPremAccExp > 0 && ::getTblValue("expInvestUnit" + typeName, data, 0) > 0)
        data["expInvestUnit" + typeName] += unitVirtPremAccExp
    }

  foreach (row in ::debriefing_rows)
  {
    if (!row.isUsedInRecount)
      continue
    local rowTbl = ::getTblValue(::get_table_name_by_id(row), data)
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
 * Returns proper "haveTeamkills" value from related userlogs.
 */
::debriefing_result_have_teamkills <- function debriefing_result_have_teamkills()
{
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
    result = result || ::getTblValue("haveTeamkills", log)
  return result
}

::debriefing_result_get_base_tournament_reward <- function debriefing_result_get_base_tournament_reward()
{
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

::get_debriefing_result_active_boosters <- function get_debriefing_result_active_boosters()
{
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
::get_debriefing_result_active_wager <- function get_debriefing_result_active_wager()
{
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

::get_debriefing_result_event_id <- function get_debriefing_result_event_id()
{
  local logs = ::getUserLogsList({
    show = [::EULT_SESSION_RESULT]
    currentRoomOnly = true
  })

  return logs.len() ? ::getTblValue("eventId", logs[0]) : null
}

/**
 * Joins multiple rows rewards into new single row.
 */
::debriefing_join_rows_into_row <- function debriefing_join_rows_into_row(exp, destRowId, srcRowIdsArray)
{
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
::debriefing_apply_first_win_in_day_mul <- function debriefing_apply_first_win_in_day_mul(exp, debrResult)
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
    foreach (ut in ::g_unit_type.types)
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

::count_whole_reward_in_table <- function count_whole_reward_in_table(table, currency, specParam = null)
{
  if (!table || table.len() == 0)
    return 0

  local reward = 0
  local upCur = ::g_string.toUpper(currency, 1)
  local searchArray = specParam || ["noBonus", "premMod", "premAcc", "booster"]
  foreach(cur in searchArray)
    reward += ::getTblValue(cur + upCur, table, 0)
  return reward
}

::get_table_name_by_id <- function get_table_name_by_id(row)
{
  return "tbl" + row.getRewardId()
}

::recount_debriefing_result <- function recount_debriefing_result()
{
  local gm = ::get_game_mode()
  local gt = ::get_game_type()

  foreach(row in ::debriefing_rows)
  {
    row.show = row.isVisible(gm, gt, isDebriefingResultFull)
    row.showInTooltips = row.show || row.isVisible(gm, gt, isDebriefingResultFull, true)
    if (!row.show && !row.showInTooltips)
      continue

    local isRowEmpty = true
    foreach(currency in ["wp", "exp", "gold"])
    {
      local id = currency + row.getRewardId()
      local result = ::getTblValue(id, ::debriefing_result.exp, 0)
      row[currency] <- result
      isRowEmpty = isRowEmpty && !result
    }

    if (row.getValueFunc)
      row.value = row.getValueFunc()
    else if (row.customValueName)
      row.value = ::getTblValue(row.customValueName, ::debriefing_result.exp, 0)
    else
      row.value = ::getTblValue(row.type + row.getRewardId(), ::debriefing_result.exp, 0)
    isRowEmpty = isRowEmpty && !row.value

    local isHide = (row.showByValue && !row.showByValue(row.value))
      || (isRowEmpty && !row.isVisibleWhenEmpty())

    if (isHide)
    {
      row.show = false
      row.showInTooltips = false
    }
  }

  foreach(row in ::debriefing_rows)
  {
    if (row.rewardType in row)
      row.reward = row[row.rewardType]

    if (row.reward > 0 && (row.value > 0 || !row.canShowRewardAsValue))
      ::debriefing_result.needRewardColumn = true
  }
}

::delayed_rankUp_wnd <- []
::checkRankUpWindow <- function checkRankUpWindow(country, old_rank, new_rank, unlockData = null)
{
  if (country == "country_0" || country == "")
    return false
  if (new_rank <= old_rank)
    return false

  local gained_ranks = [];
  for (local i = old_rank+1; i<=new_rank; i++)
    gained_ranks.append(i);
  local config = { country = country, ranks = gained_ranks, unlockData = unlockData }
  if (::isHandlerInScene(::gui_handlers.RankUpModal))
    ::delayed_rankUp_wnd.append(config) //better to refactor this to wrok by showUnlockWnd completely
  else
    ::gui_start_modal_wnd(::gui_handlers.RankUpModal, config)
  ::debriefing_countries[country] <- new_rank
  return true
}

::getTournamentRewardData <- function getTournamentRewardData(log)
{
  local res = []

  if (!::getTblValue("rewardTS", log))
    return []

  foreach(idx, block in log.rewardTS)
  {
    local result = clone block

    result.type <- "TournamentReward"
    result.eventId <- log.name
    result.reason <- ::getTblValue("awardType", block, "")
    local reasonNum = ::getTblValue("fieldValue", block, 0)
    result.reasonNum <- reasonNum
    result.value <- reasonNum
    result[::getTblValue("fieldName", block, result.reason)] <- reasonNum

    res.append(::DataBlockAdapter(result))
  }

  return res
}

::get_pve_reward_trophy_info <- function get_pve_reward_trophy_info(sessionTime, sessionActivity, isSuccess)
{
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

::get_debriefing_gift_items_info <- function get_debriefing_gift_items_info(skipItemId = null)
{
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
