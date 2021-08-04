local time = require("scripts/time.nut")
local wwOperationUnitsGroups = require("scripts/worldWar/inOperation/wwOperationUnitsGroups.nut")
local { getCustomViewCountryData } = require("scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
local { getOperationById } = require("scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
local { getMissionLocName } = require("scripts/missions/missionsUtilsModule.nut")

enum UNIT_STATS {
  INITIAL
  KILLED
  INACTIVE
  REMAIN
  TOTAL // enum size
}

class ::WwBattleResultsView
{
  battleRes = null

  battleUnitTypes   = null
  inactiveUnitTypes = null

  teamBlock = null

  static armyStateTexts = {
    EASAB_UNKNOWN     = "debriefing/ww_army_state_unknown"
    EASAB_UNCHANGED   = "debriefing/ww_army_state_unchanged"
    EASAB_RETREATING  = "debriefing/ww_army_state_retreating"
    EASAB_DEAD        = "debriefing/ww_army_state_dead"
  }

  constructor(_battleRes)
  {
    battleRes = _battleRes

    loadBattleUnitTypesData()
    teamBlock = getTeamBlock()
  }

  function loadBattleUnitTypesData()
  {
    battleUnitTypes   = []
    inactiveUnitTypes = []

    foreach (team in battleRes.teams)
    {
      foreach (wwUnit in team.unitsInitial)
      {
        if (wwUnit.getWwUnitType() == ::g_ww_unit_type.UNKNOWN)
        {
          local unitName = wwUnit.name // warning disable: -declared-never-used
          ::script_net_assert_once("UNKNOWN wwUnitType", "wwUnitType is UNKNOWN in wwBattleResultsView")
          continue
        }
        ::u.appendOnce(wwUnit.getWwUnitType().code, battleUnitTypes)
      }
      foreach (wwUnit in team.unitsRemain)
        if (wwUnit.inactiveCount > 0)
          ::u.appendOnce(wwUnit.getWwUnitType().code, inactiveUnitTypes)
    }

    battleUnitTypes.sort()
    inactiveUnitTypes.sort()
  }

  function getLocName()
  {
    return getMissionLocName({ locId = battleRes.locName })
  }

  function getBattleTitle()
  {
    local localizedName = getLocName()
    local missionTitle = (localizedName != "") ? localizedName : ::loc("worldwar/autoModeBattle")
    local battleName = ::loc("worldWar/battleName", { number = battleRes.ordinalNumber })
    return battleName + " " + missionTitle
  }

  function getBattleDescText()
  {
    local operationName = getOperation()?.getNameText() ?? ""
    local zoneName = battleRes.zoneName != "" ? (::loc("options/dyn_zone") + " " + battleRes.zoneName) : ""
    local dateTime = time.buildDateStr(battleRes.time) + " " + time.buildTimeStr(battleRes.time)
    return ::g_string.implode([ operationName, zoneName, dateTime ], ::loc("ui/semicolon"))
  }

  function getBattleResultText()
  {
    local isWinner = battleRes.isWinner()
    local color = isWinner ? "wwTeamAllyColor" : "wwTeamEnemyColor"
    local result = ::loc("worldwar/log/battle_finished" + (isWinner ? "_win" : "_lose"))
    return ::colorize(color, result)
  }

  function isBattleResultsIgnored()
  {
    return battleRes.isBattleResultsIgnored
  }

  function getArmyStateText(wwArmy, armyState)
  {
    local res = ::loc(::getTblValue(armyState, armyStateTexts, ""))
    if (armyState == "EASAB_DEAD" && wwArmy.deathReason != "")
      res += ::loc("ui/parentheses/space", { text = ::loc("worldwar/log/army_died_" + wwArmy.deathReason) })
    return res
  }

  function getTeamBySide(side)
  {
    return ::u.search(battleRes.teams, (@(side) function (team) {
      return team.side == side
    })(side))
  }

  function getTeamStats(teamInfo, unitTypesBattle, unitTypesInactive)
  {
    local res = {
      unitTypes = []
      units     = []
    }

    local unitTypeStats = {}
    foreach (wwUnitTypeCode in unitTypesBattle)
      unitTypeStats[wwUnitTypeCode] <- array(UNIT_STATS.TOTAL, 0)

    // unitsInitial shows unit counts at the moment armies joins the battle.
    // unitsCasualties snapshot is taken exactly at battle finish time.
    // unitsRemain snapshot is taken some moments AFTER the battle finish time, and its counts can be lower
    //   than it should, because army loses extra units while retreating. Thats why unitsRemain is unreliable.

    // Vehicle units have unitsInitial, unitsCasualties, and unitsRemain which is unreliable (must be calculated as initial-casualties).
    // But anyway, vehicle units must extract remainInactive from that unreliable unitsRemain (it can be non-zero for Aircrafts).

    local unitsGroups = wwOperationUnitsGroups.getUnitsGroups()
    local needShowUnitsByGroups = unitsGroups != null
    teamInfo.unitsInitial.sort(::g_world_war.sortUnitsByTypeAndCount)
    foreach (wwUnit in teamInfo.unitsInitial)
    {
      local unitName = wwUnit.name
      local wwUnitType = wwUnit.getWwUnitType()
      local wwUnitTypeCode = wwUnitType.code

      local initialActive = wwUnit.count
      local initialInactive = wwUnit.inactiveCount

      local remainInactive = 0
      foreach (u in teamInfo.unitsRemain)
        if (u.name == unitName)
        {
          remainInactive = u.inactiveCount
          break
        }

      local casualties = 0
      foreach (u in teamInfo.unitsCasualties)
        if (u.name == unitName)
        {
          casualties = u.count + u.inactiveCount
          break
        }

      local remainActive = (initialActive + initialInactive) - casualties - remainInactive // Fixes vehicle units remain counts
      local inactiveAdded = remainInactive - initialInactive

      if (wwUnitTypeCode in unitTypeStats)
      {
        local stats = unitTypeStats[wwUnitTypeCode]
        stats[UNIT_STATS.INITIAL]   += initialActive
        stats[UNIT_STATS.KILLED]    += casualties
        stats[UNIT_STATS.INACTIVE]  += inactiveAdded
        stats[UNIT_STATS.REMAIN]    += remainActive
      }

      if (wwUnitType.esUnitCode == ::ES_UNIT_TYPE_INVALID) // fake unit
        continue

      local isShowInactiveCount = ::isInArray(wwUnitTypeCode, unitTypesInactive)

      local stats = array(UNIT_STATS.TOTAL, 0)
      stats[UNIT_STATS.INITIAL]   = initialActive
      stats[UNIT_STATS.KILLED]    = casualties
      stats[UNIT_STATS.INACTIVE]  = inactiveAdded
      stats[UNIT_STATS.REMAIN]    = remainActive

      local wwUnitViewParams = wwUnit.getShortStringView({ hideZeroCount = false })
      if (needShowUnitsByGroups)
        wwUnitViewParams = wwOperationUnitsGroups.overrideUnitViewParamsByGroups(
          wwUnitViewParams, unitsGroups)

      res.units.append({
        unitString = wwUnitViewParams
        row = getStatsRowView(stats, isShowInactiveCount)
      })
    }

    foreach (wwUnitTypeCode, stats in unitTypeStats)
    {
      if (!stats)
        continue

      local wwUnitType = ::g_ww_unit_type.getUnitTypeByCode(wwUnitTypeCode)
      local isShowInactiveCount = ::isInArray(wwUnitTypeCode, unitTypesInactive)

      res.unitTypes.append({
        name = "#debriefing/ww_total_" + wwUnitType.name
        row = getStatsRowView(stats, isShowInactiveCount)
      })
    }

    return res
  }

  function getStatsRowView(stats, isShowInactiveCount = false)
  {
    local columnsMap = [
      [UNIT_STATS.INITIAL],
      isShowInactiveCount ? [UNIT_STATS.KILLED, UNIT_STATS.INACTIVE] : [UNIT_STATS.KILLED],
      isShowInactiveCount ? [UNIT_STATS.REMAIN] : [UNIT_STATS.REMAIN, UNIT_STATS.INACTIVE],
    ]

    local row = []
    foreach (valueIds in columnsMap)
    {
      local values = ::u.map(valueIds, (@(stats) function(id) { return stats[id] })(stats))
      local valuesSum = values.reduce(@(sum, v) sum + v, 0)

      local val = isShowInactiveCount ? ::g_string.implode(values, " + ") : valuesSum.tostring()

      local tooltip = null
      if (isShowInactiveCount && values.len() == 2 && valuesSum > 0)
          tooltip = ::loc("debriefing/destroyed") + ::loc("ui/colon") + values[0] +
            "\n" + ::loc("debriefing/ww_inactive/Aircraft") + ::loc("ui/colon") + values[1]

      row.append({
        col = val
        tooltip = tooltip
      })
    }
    return row
  }

  function getTeamBlock()
  {
    local mapName = getOperation()?.getMapId() ?? ""
    local teams = []
    foreach(sideIdx, side in ::g_world_war.getSidesOrder())
    {
      local team = getTeamBySide(side)
      if (!team)
        continue

      local armies = []
      foreach (army in team.armies)
        armies.append({
          armyView = army.getView()
          armyStateText = getArmyStateText(army, ::getTblValue(army.name, team.armyStates))
        })

      teams.append({
        invert = sideIdx != 0
        countryIcon = getCustomViewCountryData(team.country, mapName).icon
        armies = armies
        statistics = getTeamStats(team, battleUnitTypes, inactiveUnitTypes)
      })
    }

    return teams
  }

  function hasReplay()
  {
    return !::u.isEmpty(battleRes.getSessionId()) &&
           ::has_feature("WorldWarReplay")
  }

  function getReplayBtnTooltip()
  {
    return ::loc("mainmenu/btnViewReplayTooltip", {sessionID = battleRes.getSessionId()})
  }

  function getOperation()
  {
    return getOperationById(battleRes.getOperationId() ?? ::ww_get_operation_id())
  }
}
