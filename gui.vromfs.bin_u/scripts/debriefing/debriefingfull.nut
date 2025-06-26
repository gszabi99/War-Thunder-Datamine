from "%scripts/dagui_natives.nut" import is_user_log_for_current_room, get_player_army_for_hud, get_user_logs_count, get_local_player_country, get_user_log_blk_body, get_race_winners_count
from "%scripts/dagui_library.nut" import *
from "%scripts/debriefing/debriefingConsts.nut" import debrState
from "%scripts/teams.nut" import g_team
from "%scripts/utils_sa.nut" import is_multiplayer, is_mode_with_teams

let { g_mission_type } = require("%scripts/missions/missionType.nut")
let { get_pve_trophy_name } = require("%appGlobals/ranks_common_shared.nut")
let { Cost, Money, money_type } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { fabs } = require("math")
let DataBlock = require("DataBlock")
let { get_mp_session_id_str, is_mplayer_peer } = require("multiplayer")
let { getLogForBanhammer } = require("%scripts/chat/mpChatModel.nut")
let { getGameChatLogText } = require("%scripts/chat/mpChat.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getRewardSources } = require("%scripts/debriefing/rewardSources.nut")
let { MISSION_OBJECTIVE } = require("%scripts/missions/missionsUtilsModule.nut")
let { isGameModeVersus } = require("%scripts/matchingRooms/matchingGameModesUtils.nut")
let { havePremium } = require("%scripts/user/premium.nut")
let { is_replay_playing } = require("replays")
let { eventbus_subscribe } = require("eventbus")
let { getSkillBonusTooltipText } = require("%scripts/statistics/mpStatisticsInfo.nut")
let { getMplayersList } = require("%scripts/statistics/mplayersList.nut")
let { is_benchmark_game_mode, get_game_mode, get_game_type, get_mp_local_team } = require("mission")
let { get_mission_difficulty_int, stat_get_benchmark,
  get_race_best_lap_time, get_race_lap_times,
  get_mission_restore_type, get_mp_tbl_teams, get_mission_status } = require("guiMission")
let { dynamicApplyStatus } = require("dynamicMission")
let { capitalize } = require("%sqstd/string.nut")
let { getRomanNumeralRankByUnitName } = require("%scripts/unit/unitInfo.nut")
let { get_current_mission_info_cached, get_warpoints_blk, get_ranks_blk } = require("blkGetters")
let { isInSessionRoom, getSessionLobbyIsSpectator, getSessionLobbyPublicParam, getSessionLobbyPlayersInfo
} = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { getEventEconomicName } = require("%scripts/events/eventInfo.nut")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let { findItemById } = require("%scripts/items/itemsManager.nut")
let { isMissionExtr } = require("%scripts/missions/missionsUtils.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getModItemName } = require("%scripts/weaponry/weaponryDescription.nut")
let { getModificationByName } = require("%scripts/weaponry/modificationInfo.nut")
let { getUserLogsList } = require("%scripts/userLog/userlogUtils.nut")
let { getRoomEvent, getRoomUnitTypesMask } = require("%scripts/matchingRooms/sessionLobbyInfo.nut")
let destroySessionScripted = require("%scripts/matchingRooms/destroySessionScripted.nut")

const TOOLTIP_MINIMIZE_SCREEN_WIDTH_PERCENT = 0.95

local debriefingResult = null
local dynamicResult = -1
let rewardsBonusTypes = ["noBonus", "premAcc", "premMod", "booster"]

function countWholeRewardInTable(table, currency, specParam = null) {
  if (!table || table.len() == 0)
    return 0

  local reward = 0
  let upCur = capitalize(currency)
  let searchArray = specParam || ["noBonus", "premMod", "premAcc", "booster"]
  foreach (cur in searchArray)
    reward += getTblValue(cur + upCur, table, 0)
  return reward
}

function getMissionRewardSources(rewardSources, skillBonusLevel, paramsOvr = {}) {
  let { noBonusExpTotal = 0, premAccExpTotal = 0, boosterExpTotal = 0,
    premModExpTotal = 0, expSkillBonus = 0 } = rewardSources
  return getRewardSources({
      noBonus = noBonusExpTotal
      premAcc = premAccExpTotal
      booster = boosterExpTotal
      premMod = premModExpTotal
      skillBonus = expSkillBonus
      skillBonusLevel = skillBonusLevel ?? 0
  }, { currencyImg = "#ui/gameuiskin#item_type_RP.svg" }.__merge(paramsOvr))
}

function adjustTooltipSize(obj) {
  let [tooltipWidth] = obj.getSize()
  if (tooltipWidth >= screen_width() * TOOLTIP_MINIMIZE_SCREEN_WIDTH_PERCENT)
    obj.findObject("battle_reward_table").minimized = "yes"
}

let getTableNameById = @(row) $"tbl{row.getRewardId()}"

let cellNoValSymbol = loc("ui/mdash")

let debriefingRowDefault = {
  id = ""
  rewardId = null
  showEvenEmpty = false 
  showByValue = null  
  rowProps = null 
  showByModes = null 
  showByTypes = null 
  isShowOnlyInTooltips = false 
  canShowRewardAsValue = false  
  showOnlyWhenFullResult = false
  joinRows = null 
  customValueName = null
  getValueFunc = null
  icon = "icon/summation" 
  getIcon = @() loc(this.icon, "")
  fillTooltipFunc = null 
  tooltipExtraRows = null 
  tooltipComment = null  
  tooltipRowBonuses = @(_unitId, _unitData) null
  hideTooltip = false
  hideUnitSessionTimeInTooltip = false
  isCountedInUnits = true
  isFreeRP = false  

  
  
  isOverall = false  
  isUsedInRecount = true
  

  
  value = 0
  rowType = "num"  
  wp = 0
  gold = 0
  exp = 0
  reward = 0
  rewardType = "wp"
  show = false
  showInTooltips = false

  getRewardId = function() { return this.rewardId || this.id }
  isVisible = function(gameMode, gameType, isDebriefingFull, isTooltip = false) {
    if (this.showByModes && !this.showByModes(gameMode))
      return false
    if (this.showByTypes && !this.showByTypes(gameType))
      return false
    return (isDebriefingFull || !this.showOnlyWhenFullResult) && (isTooltip || !this.isShowOnlyInTooltips)
  }
  isVisibleWhenEmpty = function() { return this.showEvenEmpty }
  getName = function() { return loc(getTblValue("text", this,$"debriefing/{this.id}")) }
  getNameIcon = null
}

local debriefingRows = [] 
debriefingRows = [
  { id = "AirKills"
    showByModes = isGameModeVersus
    showByTypes = function(gt) { return (!(gt & GT_RACE) && !(gt & GT_FOOTBALL)) }
    text = "multiplayer/air_kills"
    icon = "icon/mpstats/kills"
    isVisibleWhenEmpty = @() !!(g_mission_type.getCurrentObjectives() & MISSION_OBJECTIVE.KILLS_AIR)
  }
  { id = "GroundKills"
    showByTypes = function(gt) { return (!(gt & GT_RACE) && !(gt & GT_FOOTBALL)) }
    showByModes = isGameModeVersus
    getName = @() loc("multiplayer/ground_kills")
    getIcon = @() loc("icon/mpstats/groundKills", "")
    isVisibleWhenEmpty = @() !!(g_mission_type.getCurrentObjectives() & MISSION_OBJECTIVE.KILLS_GROUND)
  }
  { id = "AwardDamage"
    showByTypes = function(gt) { return (!(gt & GT_RACE) && !(gt & GT_FOOTBALL)) }
    showByModes = function(gm) { return gm != GM_SKIRMISH }
    text = "multiplayer/naval_damage"
    icon = "icon/mpstats/navalDamage"
    isVisibleWhenEmpty = @() !!(g_mission_type.getCurrentObjectives() & MISSION_OBJECTIVE.KILLS_NAVAL)
  }
  { id = "NavalKills"
    showByTypes = function(gt) { return (!(gt & GT_RACE) && !(gt & GT_FOOTBALL)) }
    showByModes = isGameModeVersus
    text = "multiplayer/naval_kills"
    icon = "icon/mpstats/navalKills"
    isVisibleWhenEmpty = @() !!(g_mission_type.getCurrentObjectives() & MISSION_OBJECTIVE.KILLS_NAVAL)
  }
  "GroundKillsF"
  "NavalKillsF"
  { id = "Assist"
    showByModes = isGameModeVersus
    text = "multiplayer/assists"
    icon = "icon/mpstats/assists"
  }
  { id = "AirSevereDamage"
    showByModes = isGameModeVersus
    showByTypes = function(gt) { return (!(gt & GT_RACE) && !(gt & GT_FOOTBALL)) }
    icon = "icon/mpstats/kills"
  }
  "Critical"
  "Hit"
  { id = "Scouting"
    showByTypes = function(gt) { return (!(gt & GT_RACE) && !(gt & GT_FOOTBALL)) }
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
    rowType = "num"
    showByModes = isGameModeVersus
    text = "multiplayer/zone_captures"
    icon = "icon/mpstats/captureZone"
  }
  "Landings"
  "Takeoffs"
  { id = "MissileEvade"
    showByModes = isGameModeVersus
    text = "multiplayer/missileEvade"
    icon = "icon/mpstats/missileEvade"
  }
  { id = "ShellInterception"
    showByModes = isGameModeVersus
    text = "multiplayer/shellInterception"
    icon = "icon/mpstats/shellInterception"
  }
  { id = "Sights"
    showByModes = isGameModeVersus
    showByTypes = function(gt) { return (!(gt & GT_RACE) && !(gt & GT_FOOTBALL)) }
  }
  { id = "Damage",
    rowType = "tnt"
    showByModes = isGameModeVersus
    icon = "icon/mpstats/damageZone"
  }
  { id = "Destruction"
    rowType = ""
    showByModes = isGameModeVersus
    icon = "icon/mpstats/damageZone"
  }
  { id = "ReturnSpawnCost"
    rowType = "num"
    showByModes = isGameModeVersus
    customValueName = "numReturnSpawnCost"
    text = "exp_reasons/return_spawn_cost"
  }
  { id = "MissionObjective"
    rowType = ""
    icon = "icon/star"
  }
  { id = "BestLap"
    rowType = "ptm"
    icon = "icon/mpstats/raceBestLapTime"
  }
  { id = "TimedAward"
    rowType = ""
    text = "exp_reasons/timed_award"
  }
  { id = "BattleTime"
    text = "debriefing/activityTime"
    rowType = "tim"
    icon = "icon/hourglass"
    hideUnitSessionTimeInTooltip = true
  }
  { id = "Activity"
    customValueName = "activity"
    rowType = "pct"
    showByModes = function(gm) { return gm == GM_DOMINATION }
    showOnlyWhenFullResult = true
    showEvenEmpty = true
    infoName = "score"
    infoType = ""
  }
  { id = "SkillBonus"
    commentMaxWidth = "@expSkillBonusCommentMaxWidth"
    rewardType = "exp"
    showByModes = function(gm) { return gm == GM_DOMINATION }
    showOnlyWhenFullResult = true
    canShowRewardAsValue = true
    hideUnitSessionTimeInTooltip = true
    getName = function() {
      return loc("expSkillBonus")
    }

    getNameIcon = function() {
      let expSkillBonusLevel = debriefingResult?.exp.expSkillBonusLevel
      return  expSkillBonusLevel ? $"#ui/gameuiskin#skill_bonus_level_{expSkillBonusLevel}.svg" : ""
    }

    tooltipRowBonuses = function(_unitId, unitData) {
      let noBonusExp = unitData.tblTotal.noBonusExp
      let blk = get_ranks_blk()
      let expSkillBonusLevel = debriefingResult?.exp.expSkillBonusLevel

      let eventName = debriefingResult?.roomEvent ? getEventEconomicName(debriefingResult.roomEvent) : "tank_event_in_random_battles_arcade"
      let skillBonusData = blk?.ExpSkillBonus[eventName][$"BonusLevel{expSkillBonusLevel}"]

      return skillBonusData && expSkillBonusLevel ? {
        sources = [
          {
            text = $"{noBonusExp}"
            textColor = "@commonTextColor"
            currencyImg = "#ui/gameuiskin#item_type_RP.svg"
          },
          {
            text = "x"
            textColor = "@chapterUnlockedColor"
          },
          {
            text = $"{skillBonusData.bonusPercent}%"
            currencyImg = $"#ui/gameuiskin#skill_bonus_level_{expSkillBonusLevel}.svg"
            textColor = "@chapterUnlockedColor"
          }
        ]
      } : null
    }

    tooltipComment = function() {
      let eventName = getEventEconomicName(debriefingResult?.roomEvent)
      return getSkillBonusTooltipText(eventName)
    }

    rowProps = function() {
      if (debriefingResult.exp.result == STATS_RESULT_SUCCESS)
        return { winAwardColor = "yes" }
      return null
    }

  }
  { id = "Mission"
    rowType = "exp"
    showByModes = function(gm) { return gm == GM_DOMINATION }
    getName = function() {
      if (!debriefingResult || !("exp" in debriefingResult))
        return loc("debriefing/Mission")

      let checkVal = countWholeRewardInTable(debriefingResult.exp?[getTableNameById(this)],
        this.rowType, ["premMod", "premAcc"])
      if (checkVal < 0)
        return loc("debriefing/MissionNegative")

      if (debriefingResult.exp.result == STATS_RESULT_SUCCESS)
        return loc("debriefing/MissionWinReward")
      else if (debriefingResult.exp.result == STATS_RESULT_FAIL)
        return loc("debriefing/MissionLoseReward")
      return loc("debriefing/Mission")
    }
    rowProps = function() {
        if (debriefingResult.exp.result == STATS_RESULT_SUCCESS)
          return { winAwardColor = "yes" }
        return null
      }
    icon = ""
    canShowRewardAsValue = true
  }
  { id = "MissionCoop"
    rewardId = "Mission"
    isUsedInRecount = false 
    rowType = "exp"
    showByModes = function(gm) { return gm != GM_DOMINATION }
    text = "debriefing/Mission"
    icon = ""
    canShowRewardAsValue = true
  }
  { id = "Unlocks"
    rowType = "exp"
    icon = ""
    isCountedInUnits = false
  }
  { id = "ExpensesCompensation"
    icon = ""
    getName = @() loc("userlog/expenses_compensation")
    tooltipComment = function() { return loc("userlog/expenses_compensation_tooltip") }
    isCountedInUnits = false
  }
  { id = "FriendlyKills"
    showByModes = isGameModeVersus
  }
  { id = "TournamentBaseReward"
    rowType = "exp"
    text = "debriefing/tournamentBaseReward"
    icon = ""
    canShowRewardAsValue = true
  }
  { id = "FirstWinInDay"
    rowType = "exp"
    text = "debriefing/firstWinInDay"
    icon = ""
    tooltipComment = function() {
      let firstWinMulRp = (debriefingResult?.xpFirstWinInDayMul ?? 1.0).tointeger()
      let firstWinMulWp = (debriefingResult?.wpFirstWinInDayMul ?? 1.0).tointeger()
      return "".concat(loc("reward"), loc("ui/colon"), loc("ui/comma").join([
        firstWinMulRp > 1 ? $"x{Cost().setRp(firstWinMulRp).tostring()}" : "",
        firstWinMulWp > 1 ? $"x{Cost(firstWinMulWp).tostring()}" : "",
      ], true))
    }
    canShowRewardAsValue = true
    isCountedInUnits = false
  }
  { id = "Total"
    text = "debriefing/total"
    icon = ""
    rowType = "exp"
    showEvenEmpty = true
    rowProps =  { totalColor = "yes", totalRowStyle = "first" }
    canShowRewardAsValue = true
    showOnlyWhenFullResult = true
    isOverall = true
    tooltipExtraRows = function() {
      let res = []
      foreach (row in debriefingRows)
        if (!row.isCountedInUnits)
          res.append(row.id)
      return res
    }
    tooltipComment = function() {
      let texts = []
      let tournamentWp   = getTblValue("wpTournamentBaseReward",   debriefingResult.exp, 0)
      let tournamentGold = getTblValue("goldTournamentBaseReward", debriefingResult.exp, 0)
      let goldTotal = getTblValue("goldTotal",   debriefingResult.exp, 0)
      if (tournamentWp || tournamentGold)
        texts.append("".concat(loc("debriefing/tournamentBaseReward"), loc("ui/colon"), Cost(tournamentWp, tournamentGold)))
      else if (goldTotal)
        texts.append("".concat(loc("chapters/training"), loc("ui/colon"), Cost(0, goldTotal)))
      let raceWp = getTblValue("wpRace",  debriefingResult.exp, 0)
      let raceRp = getTblValue("expRace", debriefingResult.exp, 0)
      if (raceWp || raceRp)
        texts.append("".concat(loc("events/chapter/race"), loc("ui/colon"), Cost(raceWp, 0, 0, raceRp)))
      return texts.len() ? colorize("commonTextColor", "\n".join(texts, true)) : null
    }
  }
  {
    id = "ModsTotal"
    text = "debriefing/total/modsResearch"
    icon = ""
    rewardType = "exp"
    rowProps =  { totalColor = "yes", totalRowStyle = "first" }
    canShowRewardAsValue = true
    showByModes = function(gm) { return gm == GM_DOMINATION }
    showOnlyWhenFullResult = true
    isOverall = false

    fillTooltipFunc = function(debriefing, obj, handler) {
      if (debriefing.researchPointsUnits.len() == 0) {
        obj["class"] = "empty"
        return
      }

      let unitBonuses = debriefing.researchPointsUnits.map(function(unitBonus) {
        let { noBonusExpTotal = 0, premAccExpTotal = 0, boosterExpTotal = 0,
          premModExpTotal = 0, expSkillBonus = 0, invModuleExp = 0 } = unitBonus
        let  total = noBonusExpTotal + premAccExpTotal + boosterExpTotal + premModExpTotal + expSkillBonus
        return unitBonus.__merge({ overflow = total - invModuleExp })
      })

      local hasOverflow = false
      foreach (r in unitBonuses) {
        if (r.overflow > 0) {
          hasOverflow = true
          break
        }
      }

      let columns = [
        {titleLocId = "options/unit", isFirstCol = true}
        {titleLocId = "debriefing/Mission"}
        {titleLocId = "debriefing/researchedMod"}
        {titleLocId = "debriefing/modResearch"}
        hasOverflow ? {titleLocId = "debriefing/overflow"} : null
      ].filter(@(col) col != null)

      let rows = unitBonuses.map(function(unitBonus, idx) {
        let { unit, overflow, invModuleExp = 0, invModuleName = null} = unitBonus
        let unitModel = getAircraftByName(unit)
        let researchedModName = invModuleName != null
          ? getModItemName(unitModel, getModificationByName(unitModel, invModuleName), false)
          : null

        return {
          isEven = idx % 2 == 0
          cells = [
            { cell = { text = loc($"{unit}_shop") }, isFirstCol = true }
            { cell =
              {
                sources = getMissionRewardSources(unitBonus, debriefingResult?.exp.expSkillBonusLevel, { regularFont = true })
                hasFormula = true
              }
            }
            { cell = { text = researchedModName ?? cellNoValSymbol}}
            { cell = {
                text = invModuleExp || cellNoValSymbol
                image = invModuleExp ? { src = "#ui/gameuiskin#item_type_RP.svg" } : null
                cellType = "tdRight"
              }
            }
            hasOverflow ? {
              cell = {
                text = overflow || cellNoValSymbol
                image = overflow ? { src = "#ui/gameuiskin#item_type_RP.svg" } : null
                cellType = "tdRight"
              }
            } : null
          ].filter(@(cell) cell != null)
        }
      })

      let markup = handyman.renderCached("%gui/userLog/userLogBattleRewardTooltip.tpl", { columns, rows })
      handler.guiScene.replaceContentFromText(obj, markup, markup.len(), handler)
    }
  }
  {
    id = "NewNationBonus"
    rewardType = "exp"
    text = "debriefing/nationResearchBonus"
    rowProps =  { winAwardColor = "yes"}
    hideUnitSessionTimeInTooltip = true
    fillTooltipFunc = function(debriefing, obj, handler) {
      let unitBonuses = debriefing.researchPointsUnits.filter(@(i) i?.newNationBonusExp != null)
      let view = {
        columns = [
          {titleLocId = "options/unit", isFirstCol = true }
          {titleLocId = "debriefing/basicRp"}
          {titleLocId = "debriefing/researched_unit"}
          {titleLocId = "multiplayer/unitRank"}
          {titleLocId = "debriefing/total"}
        ]
        rows = unitBonuses.map(@(bonus, idx) {
          isEven = idx % 2 == 0
          cells = [
            { cell = { text = loc($"{bonus.unit}_shop") }, isFirstCol = true }
            { cell = {
                text =  bonus.noBonusExpTotal
                image = { src = "#ui/gameuiskin#item_type_RP.svg" } }
                cellType = "tdRight"
            }
            { cell = { text = bonus?.invUnitName ? loc($"{bonus.invUnitName}_shop") : cellNoValSymbol }}
            { cell = {
              text = bonus?.invUnitName ? getRomanNumeralRankByUnitName(bonus.invUnitName) : cellNoValSymbol }
              cellType = "tdCenter"
            }
            { cell = {
                cellType = "tdRight"
                text =  "".concat(
                  bonus.noBonusExpTotal, loc("ui/multiply"), bonus.newNationBonusPercent, loc("measureUnits/percent"),
                  "=", bonus?.newNationBonusExp
                )
                image = { src = "#ui/gameuiskin#item_type_RP.svg" }
              }
            }]
          })
      }

      let markup = handyman.renderCached("%gui/userLog/userLogBattleRewardTooltip.tpl", view)
      handler.guiScene.replaceContentFromText(obj, markup, markup.len(), handler)
    }
  }
  { id = "UnitTotal"
    text = "debriefing/total/unitsResearch"
    icon = ""
    rewardType = "exp"
    rowProps =  { totalColor = "yes", totalRowStyle = "last" }
    showOnlyWhenFullResult = true
    isOverall = true

    fillTooltipFunc = function(debriefing, obj, handler) {
      if (debriefing.researchPointsUnits.len() == 0) {
        obj["class"] = "empty"
        return
      }

      let unitBonuses = debriefing.researchPointsUnits.map(function(unitBonus) {
        let { noBonusExpTotal = 0, premAccExpTotal = 0, boosterExpTotal = 0,
          premModExpTotal = 0, expSkillBonus = 0, newNationBonusExp = 0,
          childBonusExp = 0, rankDiffPenaltyExp = 0, invUnitExp = 0
        } = unitBonus

        let total = noBonusExpTotal + premAccExpTotal + boosterExpTotal + premModExpTotal + expSkillBonus
        let overflow = total + newNationBonusExp + childBonusExp - rankDiffPenaltyExp - invUnitExp
        return unitBonus.__merge({ total, overflow })
      })

      local hasOverflow = false
      local hasLinkInResTreeFormula = false
      local hasRankDiffFormuls = false
      foreach (bonus in unitBonuses) {
        if (bonus.overflow > 0)
          hasOverflow = true
        if ((bonus?.childBonusExp ?? 0) > 0)
          hasLinkInResTreeFormula = true
        if ((bonus?.rankDiffPenaltyExp ?? 0) > 0)
          hasRankDiffFormuls = true
      }

      let hasNewNationBonus = debriefing.exp.expNewNationBonus > 0

      let columns = [
        {titleLocId = "options/unit", isFirstCol = true}
        {titleLocId = "debriefing/Mission"}
        hasNewNationBonus ? {titleLocId = "debriefing/newNationBonus"} : null
        {titleLocId = "debriefing/researched_unit"}
        hasLinkInResTreeFormula ? {titleLocId = "debriefing/linkInTree"} : null
        hasRankDiffFormuls ? {titleLocId = "debriefing/ranksDifference"} : null
        {titleLocId = "debriefing/total/unitsResearch"}
        hasOverflow ? {titleLocId = "debriefing/overflow"} : null
      ].filter(@(col) col != null)

      let rows = unitBonuses.map(function(unitBonus, idx) {
        let { newNationBonusExp = 0, childBonusPercent = 0, childBonusExp = 0,
          rankDiffPenaltyExp = 0, rankDiffPenaltyPercent= 0, invUnitExp = 0, unit, invUnitName = null, total, overflow } = unitBonus

        let linkInTheResearchTreeFormula = !childBonusExp ? cellNoValSymbol
          : newNationBonusExp ? $"({total}+{newNationBonusExp}){loc("ui/multiply")}{childBonusPercent}%={childBonusExp}"
          : $"{total}x{childBonusPercent}{loc("measureUnits/percent")}={childBonusExp}"

        let unitRank = getRomanNumeralRankByUnitName(unit)
        let invUnitRank = getRomanNumeralRankByUnitName(invUnitName) ?? cellNoValSymbol

        let ranksDiffFormula = !rankDiffPenaltyExp ? cellNoValSymbol
          : newNationBonusExp  ? $"-({total}+{newNationBonusExp}){loc("ui/multiply")}{rankDiffPenaltyPercent}{loc("measureUnits/percent")}[{unitRank}{loc("icon/arrowRight")}{invUnitRank}]=-{rankDiffPenaltyExp}"
          : $"-{total}{loc("ui/multiply")}{rankDiffPenaltyPercent}{loc("measureUnits/percent")}[{unitRank}{loc("icon/arrowRight")}{invUnitRank}]=-{rankDiffPenaltyExp}"

        return {
          isEven = idx % 2 == 0
          cells = [
            
            { cell = { text = loc($"{unit}_shop") }, isFirstCol = true}
            
            { cell =
              {
                sources = getMissionRewardSources(unitBonus, debriefingResult?.exp.expSkillBonusLevel, {regularFont = true})
                hasFormula = true
              }
            }
            
            hasNewNationBonus ? { cell = {
                text = newNationBonusExp
                  ? newNationBonusExp
                  : cellNoValSymbol
                image = newNationBonusExp ? { src = "#ui/gameuiskin#item_type_RP.svg" } : null
                cellType = "tdRight"
              }
            } : null
            
            { cell = {
                text = invUnitName ? loc($"{unitBonus?.invUnitName}_shop") : cellNoValSymbol
              }
            }
            
            hasLinkInResTreeFormula ? { cell = {
                text = linkInTheResearchTreeFormula
                image = childBonusExp ? { src = "#ui/gameuiskin#item_type_RP.svg" } : null }
                cellType = "tdRight"
            } : null
            
            hasRankDiffFormuls ? { cell = {
                text = ranksDiffFormula
                image = rankDiffPenaltyExp ? { src = "#ui/gameuiskin#item_type_RP.svg" } : null
                cellType = "tdRight"
              }
            } : null
            
            { cell = {
                text = invUnitExp || cellNoValSymbol
                image = invUnitExp ? { src = "#ui/gameuiskin#item_type_RP.svg" } : null
                cellType = "tdRight"
              }
            }
            
            hasOverflow ? {
              cell = {
                text = overflow || cellNoValSymbol
                image = overflow ? { src = "#ui/gameuiskin#item_type_RP.svg" } : null
                cellType = "tdRight"
              }
            } : null
          ].filter(@(cell) cell != null)
        }
      })

      let view = { columns, rows }
      let markup = handyman.renderCached("%gui/userLog/userLogBattleRewardTooltip.tpl", view)
      handler.guiScene.replaceContentFromText(obj, markup, markup.len(), handler)

      adjustTooltipSize(obj)
    }
  }
  { id = "ecSpawnScore"
    text = "debriefing/total/ecSpawnScore"
    icon = "multiplayer/spawnScore/abbr"
    showByValue = function (value) { return value > 0 }
    rowProps = { totalColor = "yes", totalRowStyle = "last" }
    tooltipComment = function() { return loc("debriefing/ecSpawnScore") }
    getValueFunc = function() {
                              let logs = getUserLogsList({
                                show = [
                                  EULT_SESSION_RESULT
                                  EULT_EARLY_SESSION_LEAVE
                                ]
                                currentRoomOnly = true
                              })

                              local result = 0
                              foreach (logObj in logs) {
                                result = getTblValue(this.id, logObj, 0)
                                if (result > 0)
                                  break
                              }

                              return result
                            }
  }
  { id = "wwSpawnScore"
    text = "debriefing/total/wwSpawnScore"
    icon = "multiplayer/spawnScore/abbr"
    showByValue = function (value) { return value > 0 }
    rowProps = { totalColor = "yes", totalRowStyle = "last" }
    tooltipComment = function() { return loc("debriefing/wwSpawnScore") }
    getValueFunc = function() {
                              let logs = getUserLogsList({
                                show = [
                                  EULT_SESSION_RESULT
                                  EULT_EARLY_SESSION_LEAVE
                                ]
                                currentRoomOnly = true
                              })

                              local result = 0
                              foreach (logObj in logs) {
                                result = logObj?[this.id] ?? 0
                                if (result > 0)
                                  break
                              }

                              return result
                            }
  }
  { id = "timePlayed"
    customValueName = "timePlayed"
    rowType = "tim"
    icon = ""
  }
  { id = "sessionTime"
    customValueName = "sessionTime"
    text = "debriefing/missionDuration"
    rowType = "tim"
    icon = ""
    hideTooltip = true
    hideUnitSessionTimeInTooltip = true
    canShowForMissionExtr = true
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



foreach (idx, row in debriefingRows) {
  if (type(row) != "table")
    debriefingRows[idx] = { id = row }
  foreach (param, value in debriefingRowDefault)
    if (!(param in debriefingRows[idx]))
      debriefingRows[idx][param] <- value
}

let isDebriefingResultFull = @() (debriefingResult != null
  && (!debriefingResult.isMp
    || !debriefingResult.useFinalResults
    || debriefingResult.exp.result == STATS_RESULT_SUCCESS
    || debriefingResult.exp.result == STATS_RESULT_FAIL
    || (debriefingResult.gm != GM_DOMINATION
      && !!(debriefingResult.gameType & GT_RACE)
      && debriefingResult.exp.result != STATS_RESULT_IN_PROGRESS
    )
  )
)

function updateDebriefingExpInvestmentData() {
  local gatheredTotalModsExp = 0
  local gatheredTotalUnitExp = 0
  foreach (_airName, airData in debriefingResult.exp.aircrafts) {
    let expModuleTotal = getTblValue("expInvestModuleTotal", airData, 0)
    airData.expModsTotal <- expModuleTotal
    gatheredTotalModsExp += expModuleTotal

    let expUnitTotal = getTblValue("expInvestUnitTotal", airData, 0)
    airData.expUnitTotal <- expUnitTotal
    gatheredTotalUnitExp += expUnitTotal

    airData.expModuleCapped <- expModuleTotal != getTblValue("expInvestModule", airData, 0)
        
  }

  let expTotal = getTblValue("expTotal", debriefingResult.exp, 0)
  debriefingResult.exp.pctUnitTotal <- expTotal > 0 ? gatheredTotalUnitExp.tofloat() / expTotal : 0.0

  debriefingResult.exp.expModsTotal <- gatheredTotalModsExp
  debriefingResult.exp.expUnitTotal <- gatheredTotalUnitExp
}

function getStatReward(row, currency, keysArray = []) {
  if (!keysArray.len()) { 
    let finalId = "".concat(currency, row.getRewardId())
    return getTblValue(finalId, debriefingResult.exp, 0)
  }

  local result = 0
  let tableId = getTableNameById(row)
  let currencyName = capitalize(currency)
  foreach (key in keysArray)
    result += debriefingResult.exp?[tableId][$"{key}{currencyName}"] ?? 0
  return result
}

let getCountedResultId = @(row, state, currency)
  $"{getTableNameById(row)}_debrState{state}_{currency}"

function calculateDebriefingTabularData(addVirtPremAcc = false) {
  let countTable = !addVirtPremAcc ?
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
  foreach (row in debriefingRows) {
    if (!row.isUsedInRecount)
      continue
    if (u.isEmpty(debriefingResult.exp?[getTableNameById(row)]))
      continue

    foreach (currency in [ "wp", "exp" ])
      foreach (state, statsArray in countTable) {
        let key = getCountedResultId(row, state, currency)
        let reward = getStatReward(row, currency, statsArray)
        debriefingResult.counted_result_by_debrState[key] <- reward
      }
  }
}

function recountDebriefingResult() {
  let gm = get_game_mode()
  let gt = get_game_type()
  let isCurMisionExtr = isMissionExtr()

  foreach (row in debriefingRows) {
    row.show = ((isCurMisionExtr && (row?.canShowForMissionExtr ?? false)) || !isCurMisionExtr)
      && row.isVisible(gm, gt, isDebriefingResultFull)
    row.showInTooltips = row.show || row.isVisible(gm, gt, isDebriefingResultFull, true)
    if (!row.show && !row.showInTooltips)
      continue

    local isRowEmpty = true
    foreach (currency in ["wp", "exp", "gold"]) {
      let id = $"{currency}{row.getRewardId()}"
      let result = getTblValue(id, debriefingResult.exp, 0)
      row[currency] <- result
      isRowEmpty = isRowEmpty && !result
    }

    if (row.getValueFunc)
      row.value = row.getValueFunc()
    else if (row.customValueName)
      row.value = getTblValue(row.customValueName, debriefingResult.exp, 0)
    else
      row.value = getTblValue($"{row.rowType}{row.getRewardId()}", debriefingResult.exp, 0)
    isRowEmpty = isRowEmpty && !row.value

    let isHide = (row.showByValue && !row.showByValue(row.value))
      || (isRowEmpty && !row.isVisibleWhenEmpty())

    if (isHide) {
      row.show = false
      row.showInTooltips = false
    }
  }

  foreach (row in debriefingRows) {
    if (row.rewardType in row)
      row.reward = row[row.rewardType]

    if (row.reward > 0 && (row.value > 0 || !row.canShowRewardAsValue))
      debriefingResult.needRewardColumn = true
  }
}




function debriefingResultHaveTeamkills() {
  let logs = getUserLogsList({
    show = [
      EULT_EARLY_SESSION_LEAVE
      EULT_SESSION_RESULT
      EULT_AWARD_FOR_PVE_MODE
    ]
    currentRoomOnly = true
  })
  local result = false
  foreach (logObj in logs)
    result = result || (logObj?.haveTeamkills ?? false)
  return result
}

function getDebriefingBaseTournamentReward() {
  let result = Cost()

  local logs = getUserLogsList({
    show = [
      EULT_SESSION_RESULT
    ]
    currentRoomOnly = true
  })
  if (logs.len()) {
    result.wp   = getTblValue("baseTournamentWp", logs[0], 0)
    result.gold = getTblValue("baseTournamentGold", logs[0], 0)
  }

  if (!result.isZero())
    return result

  logs = getUserLogsList({
    show = [EULT_CHARD_AWARD]
    currentRoomOnly = true
    filters = { rewardType = ["TournamentReward"] }
  })
  if (logs.len()) {
    result.wp   = getTblValue("wpEarned", logs[0], 0)
    result.gold = getTblValue("goldEarned", logs[0], 0)
  }

  return result
}

function getDebriefingActiveBoosters() {
  let logs = getUserLogsList({
    show = [
      EULT_EARLY_SESSION_LEAVE
      EULT_SESSION_RESULT
      EULT_AWARD_FOR_PVE_MODE
    ]
    currentRoomOnly = true
  })
  foreach (logObj in logs) {
    local boosters = logObj?.affectedBoosters.activeBooster ?? []
    if (type(boosters) != "array")
      boosters = [boosters]
    if (boosters.len() > 0)
      return boosters
  }
  return []
}









function getDebriefingActiveWager() {
  
  local logs = getUserLogsList({
    show = [
      EULT_EARLY_SESSION_LEAVE
      EULT_SESSION_RESULT
      EULT_AWARD_FOR_PVE_MODE
    ]
    currentRoomOnly = true
  })
  local wagerIds
  foreach (logObj in logs) {
    wagerIds = logObj?.container.affectedWagers.itemId
    if (wagerIds != null)
      break
  }
  if (wagerIds == null || (type(wagerIds) == "array" && wagerIds.len() == 0)) 
    return null

  let data = {
    wagerInventoryId = null
    wagerShopId = type(wagerIds) == "array" ? wagerIds[0] : wagerIds 
    wagerResult = null
    wagerWpEarned = 0
    wagerGoldEarned = 0
    wagerNumWins = 0
    wagerNumFails = 0
    wagerText = loc("item/wager/endedWager/main")
  }

  
  logs = getUserLogsList({
    show = [
      EULT_CHARD_AWARD
    ]
    currentRoomOnly = true
  })
  foreach (logObj in logs) {
    let wagerShopId = getTblValue("id", logObj)
    if (wagerShopId != data.wagerShopId)
      continue
    let rewardType = getTblValue("rewardType", logObj)
    if (rewardType == null)
      continue
    data.wagerResult = rewardType
    data.wagerInventoryId = getTblValue("uid", logObj)
    data.wagerWpEarned = getTblValue("wpEarned", logObj, 0)
    data.wagerGoldEarned = getTblValue("goldEarned", logObj, 0)
    data.wagerNumWins = getTblValue("numWins", logObj, 0)
    data.wagerNumFails = getTblValue("numFails", logObj, 0)
    break
  }

  if (data.wagerWpEarned != 0 || data.wagerGoldEarned != 0) {
    let money = Money(money_type.cost, data.wagerWpEarned, data.wagerGoldEarned)
    let rewardText = money.tostring()
    let locParams = {
      wagerRewardText = rewardText
    }
    data.wagerText = "\n".concat(data.wagerText, loc("item/wager/endedWager/rewardPart", locParams))
  }

  return data
}

function getDebriefingEventId() {
  let logs = getUserLogsList({
    show = [EULT_SESSION_RESULT]
    currentRoomOnly = true
  })

  return logs.len() ? getTblValue("eventId", logs[0]) : null
}




function debriefingJoinRowsIntoRow(exp, destRowId, srcRowIdsArray) {
  let tables = [ exp ]
  if (exp?.aircrafts)
    foreach (_unitId, tbl in exp.aircrafts)
      tables.append(tbl)

  foreach (tbl in tables)
    foreach (prefix in [ "tbl", "wp", "exp", "num" ]) {
      let keyTo = $"{prefix}{destRowId}"
      if (keyTo in tbl)
        continue
      foreach (srcRowId in srcRowIdsArray) {
        let keyFrom = $"{prefix}{srcRowId}"
        if (!(keyFrom in tbl))
          continue
        let val = tbl[keyFrom]
        let isTable = u.isTable(val)
        if (!(keyTo in tbl))
          tbl[keyTo] <- isTable ? (clone val) : val
        else {
          if (is_numeric(val))
            tbl[keyTo] += val
          else if (isTable)
            foreach (i, v in val)
              if (is_numeric(v))
                tbl[keyTo][i] += v
        }
      }
    }
}






function debriefingApplyFirstWinInDayMul(exp, debrResult) {
  let logs = getUserLogsList({ show = [EULT_SESSION_RESULT], currentRoomOnly = true })
  if (!logs.len())
    return

  let xpFirstWinInDayMul = logs[0]?.xpFirstWinInDayMul ?? 1.0
  let wpFirstWinInDayMul = logs[0]?.wpFirstWinInDayMul ?? 1.0
  if (xpFirstWinInDayMul == 1 && wpFirstWinInDayMul == 1)
    return

  let xpTotalDebr = exp?.expTotal ?? 0
  let xpTotalUserlog = logs[0]?.xpEarned ?? 0
  let xpCheck = xpTotalDebr * xpFirstWinInDayMul
  let isNeedMulXp = (xpCheck > xpTotalDebr && fabs(xpCheck - xpTotalDebr) > fabs(xpCheck - xpTotalUserlog))

  let wpTotalDebr = exp?.wpTotal  ?? 0
  let wpTotalUserlog = logs[0]?.wpEarned ?? 0
  let wpCheck = wpTotalDebr * wpFirstWinInDayMul
  let isNeedMulWp = (wpCheck > wpTotalDebr && fabs(wpCheck - wpTotalDebr) > fabs(wpCheck - wpTotalUserlog))

  if (isNeedMulXp) {
    let keys = [ "expTotal", "expFree", "expInvestUnit", "expInvestUnitTotal" ]
    foreach (ut in unitTypes.types)
      keys.append(
        $"expInvestUnit{ut.name}",
        $"expInvestUnitTotal{ut.name}"
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

    exp.expFirstWinInDay <- max(0, exp.expTotal - xpTotalDebr)
    debrResult.xpFirstWinInDayMul <- xpFirstWinInDayMul
  }

  if (isNeedMulWp) {
    exp.wpTotal <- (wpTotalDebr * wpFirstWinInDayMul).tointeger()
    exp.wpFirstWinInDay <- max(0, exp.wpTotal - wpTotalDebr)
    debrResult.wpFirstWinInDayMul <- wpFirstWinInDayMul
  }
}

function getPveRewardTrophyInfo(sessionTime, sessionActivity, isSuccess) {
  let pveTrophyName = getTblValue("pveTrophyName", get_current_mission_info_cached())
  if (u.isEmpty(pveTrophyName))
    return null

  let warpoints = get_warpoints_blk()

  let isEnoughActivity = sessionActivity >= getTblValue("pveTrophyMinActivity", warpoints, 1)
  let reachedTrophyName = isEnoughActivity ? get_pve_trophy_name(sessionTime, isSuccess) : null
  local receivedTrophyName = null

  if (reachedTrophyName) {
    let logs = getUserLogsList({
      show = [
        EULT_SESSION_RESULT
      ]
      currentRoomOnly = true
    })
    let trophyRewardsList = logs?[0].container.trophies ?? {}
    receivedTrophyName = (reachedTrophyName in trophyRewardsList) ? reachedTrophyName : null
  }

  let victoryStageTime = getTblValue("pveTimeAwardWinVisual", warpoints, 1)
  let stagesTime = []
  for (local i = 0; i <= getTblValue("pveTrophyMaxStage", warpoints, -1); i++) {
    let time = getTblValue($"pveTimeAwardStage{i}", warpoints, -1)
    if (time > 0 && time < victoryStageTime)
      stagesTime.append(time)
  }
  stagesTime.append(victoryStageTime)

  local visSessionTime = isSuccess ? victoryStageTime : sessionTime.tointeger()
  if (!isSuccess) {
    let preVictoryStageTime = stagesTime.len() > 1 ? stagesTime[stagesTime.len() - 2] : 0
    let maxTime = preVictoryStageTime + (victoryStageTime - preVictoryStageTime) / 2
    visSessionTime = min(visSessionTime, maxTime)
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

function getDebriefingGiftItemsInfo(skipItemId = null) {
  let res = []

  
  local logs = getUserLogsList({
    show = [ EULT_INVENTORY_ADD_ITEM ]
    currentRoomOnly = true
    disableVisible = true
  })
  foreach (logObj in logs)
    foreach (data in logObj) {
      if (type(data) != "table" || !("itemDefId" in data))
        continue

      res.append({
        item = data.itemDefId, count = data?.quantity ?? 1, needOpen = false, enableBackground = true })
      findItemById(data.itemDefId) 
    }

  
  logs = getUserLogsList({
    show = [ EULT_SESSION_RESULT ]
    currentRoomOnly = true
    disableVisible = true
  })
  foreach (rewardType in [ "trophies", "items" ]) {
    let rewards = logs?[0]?.container?[rewardType] ?? {}
    foreach (id, count in rewards)
      if (id != skipItemId)
        res.append({ item = id, count = count, needOpen = rewardType == "trophies", enableBackground = true })
  }

  return res.len() ? res : null
}

function updateDebriefingResultGiftItemsInfo() {
  if (debriefingResult == null)
    return

  let { activity = 0, sessionTime = 0 } = debriefingResult?.exp
  let pveRewardInfo = getPveRewardTrophyInfo(sessionTime, activity, debriefingResult?.isSucceed ?? false)
  let giftItemsInfo = getDebriefingGiftItemsInfo(pveRewardInfo?.receivedTrophyName)
  if (giftItemsInfo == null)
    return

  debriefingResult.giftItemsInfo <- giftItemsInfo
}

function gatherReturnSpawnCost() {
  let spawnCostLogs = getUserLogsList({ show = [EULT_SESSION_RESULT], currentRoomOnly = true })
  let returnSpawnCostLogs = spawnCostLogs?[0].container.eventReturnSpawnCost.event ?? []
  debriefingResult.returnSpawnCost <- u.isArray(returnSpawnCostLogs) ? returnSpawnCostLogs : [returnSpawnCostLogs]
  debriefingResult.exp.wpReturnSpawnCost <- debriefingResult.returnSpawnCost
    .reduce(@(total, b) total + (b?.wpNoBonus ?? 0), 0)
  if (debriefingResult.returnSpawnCost.len() == 0)
    return

  let tblReturnSpawnCost = {}
  let totalReturnSpawnCost = {}
  let rewardTypes = ["wp"]
  foreach (data in debriefingResult.returnSpawnCost) {
    let airName = data.unit
    let airStats = debriefingResult.exp.aircrafts?[airName]
    if (airStats == null)
      continue

    if (tblReturnSpawnCost?[airName] == null) {
      tblReturnSpawnCost[airName] <- {}
      totalReturnSpawnCost[airName] <- {}
    }
    airStats.numReturnSpawnCost <- (airStats?.numReturnSpawnCost ?? 0) + 1

    let tblTotal = airStats.tblTotal
    foreach (rewardType in rewardTypes)
      foreach (source in rewardsBonusTypes) {
        let val = data?[$"{rewardType}{capitalize(source)}"] ?? 0
        if (val > 0) {
          let fullRewardTypeName = $"{source}{capitalize(rewardType)}"
          tblReturnSpawnCost[airName][fullRewardTypeName] <- (tblReturnSpawnCost?[airName][fullRewardTypeName] ?? 0) + val
          totalReturnSpawnCost[airName][rewardType] <- (totalReturnSpawnCost[airName]?[rewardType] ?? 0) + val
          if (tblTotal?[fullRewardTypeName])
            tblTotal[fullRewardTypeName] = tblTotal[fullRewardTypeName] + val
          airStats[$"{rewardType}Total"] <- (airStats[$"{rewardType}Total"] ?? 0) + val
        }
      }
  }

  foreach (airName, data in debriefingResult.exp.aircrafts)
    if (tblReturnSpawnCost?[airName]) {
      data["tblReturnSpawnCost"] <- tblReturnSpawnCost[airName]
      foreach (rewardType, val in totalReturnSpawnCost[airName])
        data[$"{rewardType}ReturnSpawnCost"] <- val
    }
}

function gatherDebriefingResult() {
  let gm = get_game_mode()
  if (gm == GM_DYNAMIC)
    dynamicResult = dynamicApplyStatus()

  debriefingResult = {}
  debriefingResult.isSucceed <- (get_mission_status() == MISSION_STATUS_SUCCESS)
  debriefingResult.restoreType <- get_mission_restore_type()
  debriefingResult.gm <- gm
  debriefingResult.gameType <- get_game_type()
  debriefingResult.isTeamplay <- is_mode_with_teams(debriefingResult.gameType)

  debriefingResult.isInRoom <- isInSessionRoom.get()
  debriefingResult.roomEvent <- isInSessionRoom.get() ? getRoomEvent() : null
  debriefingResult.isSpectator <- isInSessionRoom.get() && getSessionLobbyIsSpectator()

  debriefingResult.isMp <- is_multiplayer()
  debriefingResult.isReplay <- is_replay_playing()
  debriefingResult.sessionId <- get_mp_session_id_str()
  debriefingResult.useFinalResults <- getTblValue("useFinalResults", get_current_mission_info_cached(), false)
  debriefingResult.mpTblTeams <- get_mp_tbl_teams()
  debriefingResult.unitTypesMask <- getRoomUnitTypesMask()
  debriefingResult.playersInfo <- clone getSessionLobbyPlayersInfo()
  debriefingResult.missionDifficultyInt <- get_mission_difficulty_int()
  debriefingResult.isSymmetric <- getSessionLobbyPublicParam("symmetricTeams", true)
  debriefingResult.missionObjectives <- g_mission_type.getCurrentObjectives()


  if (is_benchmark_game_mode())
    debriefingResult.benchmark <- stat_get_benchmark()

  debriefingResult.numberOfWinningPlaces <- get_race_winners_count()
  debriefingResult.mplayers_list <- getMplayersList()

  
  let exp = ::stat_get_exp() ?? {}

  debriefingResult.expDump <- u.copy(exp) 

  

  
  if (exp?.numAwardDamage && exp?.expAwardDamage) {
    let tables = [ exp ]
    foreach (a in exp?.aircrafts ?? {})
      tables.append(a)
    foreach (t in tables) {
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
    debriefingResult.exp.result <- STATS_RESULT_FAIL

  debriefingResult.country <- get_local_player_country()
  debriefingResult.localTeam <- get_mp_local_team()
  debriefingResult.friendlyTeam <- get_player_army_for_hud()
  debriefingResult.haveTeamkills <- debriefingResultHaveTeamkills()
  debriefingResult.activeBoosters <- getDebriefingActiveBoosters()
  debriefingResult.activeWager <- getDebriefingActiveWager()
  debriefingResult.eventId <- getDebriefingEventId()
  debriefingResult.chatLog <- getGameChatLogText()
  debriefingResult.logForBanhammer <- getLogForBanhammer()

  debriefingResult.exp.timBattleTime <- getTblValue("battleTime", debriefingResult.exp, 0)
  debriefingResult.needRewardColumn <- false
  debriefingResult.mulsList <- []

  debriefingResult.roomUserlogs <- []
  for (local i = get_user_logs_count() - 1; i >= 0; i--)
    if (is_user_log_for_current_room(i)) {
      let blk = DataBlock()
      get_user_log_blk_body(i, blk)
      debriefingResult.roomUserlogs.append(blk)
    }

  if (!("aircrafts" in debriefingResult.exp))
    debriefingResult.exp.aircrafts <- []

  
  
  
  let aircraftsForDelete = []
  foreach (airName, airData in debriefingResult.exp.aircrafts)
    if (airData.sessionTime == 0 || !getAircraftByName(airName))
      aircraftsForDelete.append(airName)
  foreach (airName in aircraftsForDelete)
    debriefingResult.exp.aircrafts.$rawdelete(airName)

  debriefingResult.exp["tntDamage"] <- getTblValue("numDamage", debriefingResult.exp, 0)
  foreach (_airName, airData in debriefingResult.exp.aircrafts)
    airData["tntDamage"] <- getTblValue("numDamage", airData, 0)

  if (get_game_type() & GT_RACE) {
    debriefingResult.exp.ptmBestLap <- get_race_best_lap_time()
    debriefingResult.exp.ptmLapTimesArray <- get_race_lap_times()
  }

  let sessionTime = getTblValue("sessionTime", debriefingResult.exp, 0)
  local timePlayed = 0.0
  foreach (_airName, airData in debriefingResult.exp.aircrafts) {
    timePlayed += (airData.sessionTime + 0.5).tointeger().tofloat()
    airData.timBattleTime <- airData.battleTime
    airData.pctActivity <- 0
  }
  debriefingResult.exp.timePlayed <- timePlayed
  let sessionActivity = debriefingResult.exp?.activity ?? 0

  let pveRewardInfo = getPveRewardTrophyInfo(sessionTime, sessionActivity, debriefingResult.isSucceed)
  if (pveRewardInfo)
    debriefingResult.pveRewardInfo <- pveRewardInfo
  let giftItemsInfo = getDebriefingGiftItemsInfo(pveRewardInfo?.receivedTrophyName)
  if (giftItemsInfo)
    debriefingResult.giftItemsInfo <- giftItemsInfo

  let trournamentBaseReward = getDebriefingBaseTournamentReward()
  debriefingResult.exp.wpTournamentBaseReward <- trournamentBaseReward.wp
  debriefingResult.exp.goldTournamentBaseReward <- trournamentBaseReward.gold
  debriefingResult.exp.expMission <- getTblValue("expMission", exp, 0) + getTblValue("expRace", exp, 0)
  debriefingResult.exp.wpMission <- getTblValue("wpMission", exp, 0) + getTblValue("wpRace", exp, 0)
  debriefingResult.exp.expSkillBonus <- getTblValue("expSkillBonusTotal", exp, 0)
  gatherReturnSpawnCost()
  let wpTotal = getTblValue("wpTotal", debriefingResult.exp, 0)
  if (wpTotal >= 0)
    debriefingResult.exp.wpTotal <- wpTotal + trournamentBaseReward.wp + debriefingResult.exp.wpReturnSpawnCost

  let resPointsLogs = getUserLogsList({ show = [EULT_SESSION_RESULT], currentRoomOnly = true })?[0].container.researchPoints.unit ?? []
  debriefingResult.researchPointsUnits <- u.isArray(resPointsLogs) ? resPointsLogs : [resPointsLogs]

  debriefingResult.exp.expNewNationBonus <- debriefingResult.researchPointsUnits
    .reduce(@(total, b) total + (b?.newNationBonusExp  ?? 0), 0)

  let missionRules = getCurMissionRules()
  debriefingResult.overrideCountryIconByTeam <- {
    [g_team.A.code] = missionRules.getOverrideCountryIconByTeam(g_team.A.code),
    [g_team.B.code] = missionRules.getOverrideCountryIconByTeam(g_team.B.code)
  }

  updateDebriefingExpInvestmentData()
  calculateDebriefingTabularData(false)
  recountDebriefingResult()

  if (is_mplayer_peer())
    destroySessionScripted("after gather debriefing result")
}

function debriefingAddVirtualPremAccToStatTbl(data, isRoot) {
  let totalVirtPremAccExp = data?.tblTotal.virtPremAccExp ?? 0
  if (totalVirtPremAccExp > 0) {
    let list = isRoot ? [ "expFree" ] : [ "expInvestModuleTotal", "expInvestUnitTotal", "expModsTotal", "expUnitTotal" ]
    if (isRoot)
      foreach (ut in unitTypes.types)
        list.append([$"expInvestUnitTotal{ut.name}"])
    foreach (id in list)
      if (getTblValue(id, data, 0) > 0)
        data[id] += totalVirtPremAccExp
  }

  if (isRoot)
    foreach (ut in unitTypes.types) {
      let typeName = ut.name
      let unitId = getTblValue($"investUnitName{typeName}", data, "")
      if (u.isEmpty(unitId))
        continue
      let unitVirtPremAccExp = data?.aircrafts[unitId].tblTotal.virtPremAccExp ?? 0
      if (unitVirtPremAccExp > 0 && getTblValue($"expInvestUnit{typeName}", data, 0) > 0)
        data[$"expInvestUnit{typeName}"] += unitVirtPremAccExp
    }

  foreach (row in debriefingRows) {
    if (!row.isUsedInRecount)
      continue
    let rowTbl = data?[getTableNameById(row)]
    if ((rowTbl?.len() ?? 0) == 0)
      continue
    foreach (suffix in [ "Exp", "Wp" ]) {
      let virtPremAcc = getTblValue($"virtPremAcc{suffix}", rowTbl, 0)
      if (virtPremAcc <= 0)
        continue
      rowTbl[$"premAcc{suffix}"] <- virtPremAcc

      let precalcResultId = $"{suffix.tolower()}{row.getRewardId()}"
      let origFinal = getTblValue(precalcResultId, data, 0)
      if (origFinal >= 0) {
        data[$"noPremAcc{suffix}"] <- origFinal
        data[precalcResultId] += virtPremAcc
      }
    }
  }
}




function debriefingAddVirtualPremAcc() {
  if (!havePremium.value)
    return

  debriefingAddVirtualPremAccToStatTbl(debriefingResult.exp, true)
  if ("aircrafts" in debriefingResult.exp)
    foreach (unitData in debriefingResult.exp.aircrafts)
      debriefingAddVirtualPremAccToStatTbl(unitData, false)

  updateDebriefingExpInvestmentData()
  calculateDebriefingTabularData(true)
  recountDebriefingResult()
}

function getMoneyFromDebriefingResult() {
  let res = Cost()
  gatherDebriefingResult()
  if (debriefingResult == null)
    return res

  let exp = debriefingResult.exp
  res.wp    = exp?.wpMission ?? 0
  res.gold  = exp?.goldMission ?? 0
  res.frp   = exp?.expMission ?? 0
  return res
}

eventbus_subscribe("onQuitToDebriefing", @(_) gatherDebriefingResult())

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
  updateDebriefingResultGiftItemsInfo
  rewardsBonusTypes
}