from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let time = require("%scripts/time.nut")
let wwOperationUnitsGroups = require("%scripts/worldWar/inOperation/wwOperationUnitsGroups.nut")
let { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { getMissionLocName } = require("%scripts/missions/missionsUtilsModule.nut")

enum UNIT_STATS {
  INITIAL
  KILLED
  INACTIVE
  REMAIN
  TOTAL // enum size
}

::WwBattleResultsView <- class
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

  constructor(v_battleRes)
  {
    this.battleRes = v_battleRes

    this.loadBattleUnitTypesData()
    this.teamBlock = this.getTeamBlock()
  }

  function loadBattleUnitTypesData()
  {
    this.battleUnitTypes   = []
    this.inactiveUnitTypes = []

    foreach (team in this.battleRes.teams)
    {
      foreach (wwUnit in team.unitsInitial)
      {
        if (wwUnit.getWwUnitType() == ::g_ww_unit_type.UNKNOWN)
        {
          let unitName = wwUnit.name // warning disable: -declared-never-used
          ::script_net_assert_once("UNKNOWN wwUnitType", "wwUnitType is UNKNOWN in wwBattleResultsView")
          continue
        }
        ::u.appendOnce(wwUnit.getWwUnitType().code, this.battleUnitTypes)
      }
      foreach (wwUnit in team.unitsRemain)
        if (wwUnit.inactiveCount > 0)
          ::u.appendOnce(wwUnit.getWwUnitType().code, this.inactiveUnitTypes)
    }

    this.battleUnitTypes.sort()
    this.inactiveUnitTypes.sort()
  }

  function getLocName()
  {
    return getMissionLocName({ locId = this.battleRes.locName })
  }

  function getBattleTitle()
  {
    let localizedName = this.getLocName()
    let missionTitle = (localizedName != "") ? localizedName : loc("worldwar/autoModeBattle")
    let battleName = loc("worldWar/battleName", { number = this.battleRes.ordinalNumber })
    return battleName + " " + missionTitle
  }

  function getBattleDescText()
  {
    let operationName = this.getOperation()?.getNameText() ?? ""
    let zoneName = this.battleRes.zoneName != "" ? (loc("options/dyn_zone") + " " + this.battleRes.zoneName) : ""
    let dateTime = time.buildDateStr(this.battleRes.time) + " " + time.buildTimeStr(this.battleRes.time)
    return ::g_string.implode([ operationName, zoneName, dateTime ], loc("ui/semicolon"))
  }

  function getBattleResultText()
  {
    let isWinner = this.battleRes.isWinner()
    let color = isWinner ? "wwTeamAllyColor" : "wwTeamEnemyColor"
    let result = loc("worldwar/log/battle_finished" + (isWinner ? "_win" : "_lose"))
    return colorize(color, result)
  }

  function isBattleResultsIgnored()
  {
    return this.battleRes.isBattleResultsIgnored
  }

  function getArmyStateText(wwArmy, armyState)
  {
    local res = loc(getTblValue(armyState, this.armyStateTexts, ""))
    if (armyState == "EASAB_DEAD" && wwArmy.deathReason != "")
      res += loc("ui/parentheses/space", { text = loc("worldwar/log/army_died_" + wwArmy.deathReason) })
    return res
  }

  function getTeamBySide(side)
  {
    return ::u.search(this.battleRes.teams, (@(side) function (team) {
      return team.side == side
    })(side))
  }

  function getTeamStats(teamInfo, unitTypesBattle, unitTypesInactive)
  {
    let res = {
      unitTypes = []
      units     = []
    }

    let unitTypeStats = {}
    foreach (wwUnitTypeCode in unitTypesBattle)
      unitTypeStats[wwUnitTypeCode] <- array(UNIT_STATS.TOTAL, 0)

    // unitsInitial shows unit counts at the moment armies joins the battle.
    // unitsCasualties snapshot is taken exactly at battle finish time.
    // unitsRemain snapshot is taken some moments AFTER the battle finish time, and its counts can be lower
    //   than it should, because army loses extra units while retreating. Thats why unitsRemain is unreliable.

    // Vehicle units have unitsInitial, unitsCasualties, and unitsRemain which is unreliable (must be calculated as initial-casualties).
    // But anyway, vehicle units must extract remainInactive from that unreliable unitsRemain (it can be non-zero for Aircrafts).

    let unitsGroups = wwOperationUnitsGroups.getUnitsGroups()
    let needShowUnitsByGroups = unitsGroups != null
    teamInfo.unitsInitial.sort(::g_world_war.sortUnitsByTypeAndCount)
    foreach (wwUnit in teamInfo.unitsInitial)
    {
      let unitName = wwUnit.name
      let wwUnitType = wwUnit.getWwUnitType()
      let wwUnitTypeCode = wwUnitType.code

      let initialActive = wwUnit.count
      let initialInactive = wwUnit.inactiveCount

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

      let remainActive = (initialActive + initialInactive) - casualties - remainInactive // Fixes vehicle units remain counts
      let inactiveAdded = remainInactive - initialInactive

      if (wwUnitTypeCode in unitTypeStats)
      {
        let stats = unitTypeStats[wwUnitTypeCode]
        stats[UNIT_STATS.INITIAL]   += initialActive
        stats[UNIT_STATS.KILLED]    += casualties
        stats[UNIT_STATS.INACTIVE]  += inactiveAdded
        stats[UNIT_STATS.REMAIN]    += remainActive
      }

      if (wwUnitType.esUnitCode == ES_UNIT_TYPE_INVALID) // fake unit
        continue

      let isShowInactiveCount = isInArray(wwUnitTypeCode, unitTypesInactive)

      let stats = array(UNIT_STATS.TOTAL, 0)
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
        row = this.getStatsRowView(stats, isShowInactiveCount)
      })
    }

    foreach (wwUnitTypeCode, stats in unitTypeStats)
    {
      if (!stats)
        continue

      let wwUnitType = ::g_ww_unit_type.getUnitTypeByCode(wwUnitTypeCode)
      let isShowInactiveCount = isInArray(wwUnitTypeCode, unitTypesInactive)

      res.unitTypes.append({
        name = "#debriefing/ww_total_" + wwUnitType.name
        row = this.getStatsRowView(stats, isShowInactiveCount)
      })
    }

    return res
  }

  function getStatsRowView(stats, isShowInactiveCount = false)
  {
    let columnsMap = [
      [UNIT_STATS.INITIAL],
      isShowInactiveCount ? [UNIT_STATS.KILLED, UNIT_STATS.INACTIVE] : [UNIT_STATS.KILLED],
      isShowInactiveCount ? [UNIT_STATS.REMAIN] : [UNIT_STATS.REMAIN, UNIT_STATS.INACTIVE],
    ]

    let row = []
    foreach (valueIds in columnsMap)
    {
      let values = ::u.map(valueIds, (@(stats) function(id) { return stats[id] })(stats))
      let valuesSum = values.reduce(@(sum, v) sum + v, 0)

      let val = isShowInactiveCount ? ::g_string.implode(values, " + ") : valuesSum.tostring()

      local tooltip = null
      if (isShowInactiveCount && values.len() == 2 && valuesSum > 0)
          tooltip = loc("debriefing/destroyed") + loc("ui/colon") + values[0] +
            "\n" + loc("debriefing/ww_inactive/Aircraft") + loc("ui/colon") + values[1]

      row.append({
        col = val
        tooltip = tooltip
      })
    }
    return row
  }

  function getTeamBlock()
  {
    let mapName = this.getOperation()?.getMapId() ?? ""
    let teams = []
    foreach(sideIdx, side in ::g_world_war.getSidesOrder())
    {
      let team = this.getTeamBySide(side)
      if (!team)
        continue

      let armies = []
      foreach (army in team.armies)
        armies.append({
          armyView = army.getView()
          armyStateText = this.getArmyStateText(army, getTblValue(army.name, team.armyStates))
        })

      teams.append({
        invert = sideIdx != 0
        countryIcon = getCustomViewCountryData(team.country, mapName).icon
        armies = armies
        statistics = this.getTeamStats(team, this.battleUnitTypes, this.inactiveUnitTypes)
      })
    }

    return teams
  }

  function hasReplay()
  {
    return !::u.isEmpty(this.battleRes.getSessionId()) &&
           hasFeature("WorldWarReplay")
  }

  function getReplayBtnTooltip()
  {
    return loc("mainmenu/btnViewReplayTooltip", {sessionID = this.battleRes.getSessionId()})
  }

  function getOperation()
  {
    return getOperationById(this.battleRes.getOperationId() ?? ::ww_get_operation_id())
  }
}
