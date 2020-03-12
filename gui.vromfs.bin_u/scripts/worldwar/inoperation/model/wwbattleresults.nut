local wwActionsWithUnitsList = require("scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")

class ::WwBattleResults
{
  id = ""
  winner = ::SIDE_NONE
  operationId = null
  playerSide = ::SIDE_NONE
  playerCountry = ""
  time = 0
  updateAppliedOnHost = -1
  locName = ""
  ordinalNumber = 0
  zoneName = ""
  isBattleResultsIgnored = false
  teams = null
  sessionId = ""

  view = null

  static teamDefaults = {
    name            = ""
    side            = ::SIDE_NONE
    country         = ""
    armies          = []
    armyStates      = {}
    unitsInitial    = []
    unitsCasualties = []
    unitsRemain     = []
  }

  constructor(blk = null)
  {
    teams = {}
    if (!blk)
      return

    local battleBlk = blk?.battle
    local armiesBlk = blk?.armies
    local armyStatesBlk = blk?.armyStates
    if (!battleBlk || !armiesBlk || !armyStatesBlk)
      return

    id = battleBlk?.id ?? ""
    time = blk?.time ?? 0
    updateAppliedOnHost = battleBlk?.updateAppliedOnHost ?? -1
    locName = battleBlk?.desc?.locName ?? ""
    ordinalNumber = battleBlk?.ordinalNumber ?? 0
    zoneName = blk?.zoneInfo?.zoneName ?? ""
    sessionId = battleBlk?.desc?.sessionId ?? ""

    local wwArmies = getArmies(armiesBlk)
    updateTeamsInfo(battleBlk, armyStatesBlk, wwArmies)

    applyBattleUpdates(battleBlk)
  }

  function isValid()
  {
    return id != ""
  }

  function getView()
  {
    if (!view)
      view = ::WwBattleResultsView(this)
    return view
  }

  function getArmies(armiesBlk)
  {
    local wwArmies = {}
    foreach (armyBlk in armiesBlk)
      wwArmies[armyBlk.name] <- ::WwArmy(armyBlk.name, armyBlk)
    return wwArmies
  }

  function getSessionId()
  {
    return sessionId
  }

  function updateTeamsInfo(battleBlk, armyStatesBlk, wwArmies)
  {
    teams = {}

    local teamsBlk = battleBlk.getBlockByName("teams")
    local descBlk = battleBlk.getBlockByName("desc")
    local teamsInfoBlk = descBlk ? descBlk.getBlockByName("teamsInfo") : null
    if (!teamsBlk || !teamsInfoBlk)
      return

    for (local i = 0; i < teamsBlk.blockCount(); ++i)
    {
      local teamBlk = teamsBlk.getBlock(i)
      local teamName = teamBlk.getBlockName() ?? ""
      if (teamName.len() == 0)
        continue

      local sideName = teamBlk?.side ?? ""
      if (sideName.len() == 0)
        continue
      local side = ::ww_side_name_to_val(sideName)

      if (teamBlk?.isWinner)
        winner = side

      local armyNamesBlk = teamBlk.getBlockByName("armyNames")
      local teamCountry = ""
      local teamArmiesList = []
      local teamArmyStates = {}
      if (armyNamesBlk)
      {
        for (local j = 0; j < armyNamesBlk.paramCount(); ++j)
        {
          local armyName = armyNamesBlk.getParamValue(j) || ""
          if (armyName.len() == 0)
            continue

          local army =::getTblValue(armyName, wwArmies)
          local armyState = armyStatesBlk?[armyName].state ?? "EASAB_UNKNOWN"

          if (teamCountry == "")
            teamCountry = army.owner.country
          teamArmiesList.append(army)
          teamArmyStates[armyName] <- armyState
        }
      }

      teamArmiesList.sort(::WwArmy.sortArmiesByUnitType)

      local teamInfoBlk = teamsInfoBlk?[teamName]
      local unitsInitialBlk = teamInfoBlk?.units

      local unitsInitial = wwActionsWithUnitsList.loadUnitsFromBlk(unitsInitialBlk)
      unitsInitial.extend(wwActionsWithUnitsList.getFakeUnitsArray(teamInfoBlk))

      local unitsRemain = wwActionsWithUnitsList.loadUnitsFromBlk(teamBlk?.unitsRemain)
      unitsRemain.extend(wwActionsWithUnitsList.getFakeUnitsArray(teamBlk))

      local unitsCasualties = wwActionsWithUnitsList.loadUnitsFromBlk(teamBlk?.casualties)

      teams[teamName] <- ::u.extend({}, teamDefaults, {
        name            = teamName
        side            = side
        country         = teamCountry
        armies          = teamArmiesList
        armyStates      = teamArmyStates
        unitsInitial    = unitsInitial
        unitsCasualties = unitsCasualties
        unitsRemain     = unitsRemain
      })
    }
  }

  function applyBattleUpdates(battleBlk)
  {
    local updatesBlk = battleBlk.getBlockByName("battleUpdates")
    if (!updatesBlk)
      return

    for (local i = 0; i < updatesBlk.blockCount(); i++)
    {
      local updateBlk = updatesBlk.getBlock(i)
      local isNeedUpdateUnitsRemain = (updateBlk?.updateId ?? -1) > updateAppliedOnHost

      local teamsBlk = updateBlk?.teams
      if (!teamsBlk)
        continue
      for (local j = 0; j < teamsBlk.blockCount(); j++)
      {
        local teamBlk = teamsBlk.getBlock(j)
        local team = ::getTblValue(teamBlk.getBlockName() || "", teams)
        if (!team)
          continue

        local wwUnitsAdded = wwActionsWithUnitsList.loadUnitsFromBlk(teamBlk?.unitsAdded)

        local teamUnitsLists = isNeedUpdateUnitsRemain ?
          [ team.unitsInitial, team.unitsRemain ] :
          [ team.unitsInitial ]

        foreach (unitsList in teamUnitsLists)
        {
          foreach (wwUnitNew in wwUnitsAdded)
          {
            local unitName = wwUnitNew.name
            local hasUnit = false
            foreach (wwUnit in unitsList)
              if (wwUnit.name == unitName)
              {
                hasUnit = true
                wwUnit.count         += wwUnitNew.count
                wwUnit.inactiveCount += wwUnitNew.inactiveCount
                wwUnit.weaponCount   += wwUnitNew.weaponCount
                break
              }
            if (!hasUnit)
              unitsList.append(wwUnitNew)
          }
        }
      }
    }
  }

  function isWinner()
  {
    return winner != ::SIDE_NONE && winner == playerSide
  }

  function getOperationId()
  {
    return operationId
  }

  function getPlayerCountry()
  {
    return playerCountry
  }

  /**
  Fills WwBattleResults with data from mission result Userlog.
  Such userlog contains most data in sub tables wwSharedPool and wwBattleResult,
  and some data in userlog root table.
  It operation was finished during the battle, there will be no wwBattleResult block.
  */
  function updateFromUserlog(userlog)
  {
    local wwSharedPool = ::getTblValue("wwSharedPool", userlog)
    local wwBattleResult = ::getTblValue("wwBattleResult", userlog, {})
    if (!wwSharedPool)
      return this

    local initialArmies = ::getTblValue("initialArmies", wwSharedPool, [])
    local teamsCasualties = ::getTblValue("casualties", wwSharedPool, [])

    // Restoring team sides

    local localTeam  = ::getTblValue("localTeam", wwSharedPool, "")
    local sidesOrder = ::g_world_war.getSidesOrder() // [ player, enemy ]
    local winnerSide = ::getTblValue("win", userlog) ? sidesOrder[0] : sidesOrder[1]

    local sideInBattle = ::SIDE_NONE
    local countryInBattle = ""
    local teamBySide = {}
    foreach (armyName, initialArmy in initialArmies)
    {
      local teamName = ::getTblValue("team", initialArmy, "")
      local side = teamName == localTeam ? sidesOrder[0] : sidesOrder[1]
      teamBySide[side] <- teamName
      initialArmy.side <- ::ww_side_val_to_name(side)
      if (teamName == localTeam)
      {
        sideInBattle = side
        countryInBattle = initialArmy.country
      }
    }

    // Collecting armies

    local wwArmies = ::u.mapAdvanced(initialArmies, (@(userlog) function(val, armyName, ...) {
      local initialArmy = userlog?.wwSharedPool.initialArmies[armyName] ?? {}
      local armyState = userlog?.wwBattleResult.armyStates[armyName] ?? {}

      local side  = ::ww_side_name_to_val(::getTblValue("side", initialArmy, ""))
      local country = ::getTblValue("country", initialArmy, "")
      local clanTag = ::getTblValue("armyGroupName", armyState, "")
      local unitTypeTextCode = ::getTblValue("unitType", initialArmy, "")
      local wwUnitType = ::g_ww_unit_type.getUnitTypeByTextCode(unitTypeTextCode)

      local armyView = {
        getTeamColor      = side == sideInBattle ? "blue" : "red"
        isBelongsToMyClan = clanTag == ::clan_get_my_clan_tag()
        getTextAfterIcon  = clanTag
        getUnitTypeText   = wwUnitType.fontIcon
        getUnitTypeCustomText = wwUnitType.fontIcon
      }

      return {
        name = armyName
        side = side
        country = country
        unitType = wwUnitType.code
        deathReason = ""
        getView = @() armyView
      }
    })(userlog))

    // Updating

    local wwOperationId = wwSharedPool?.operationId
    id = ::getTblValue("battleId", wwSharedPool, "")
    if (wwOperationId)
      operationId = wwOperationId.tointeger()
    winner = winnerSide
    playerSide = sideInBattle
    playerCountry = countryInBattle
    locName = ::getTblValue("locName", userlog, "")
    isBattleResultsIgnored = ::g_world_war.isCurrentOperationFinished()

    teams = {}
    foreach (side in sidesOrder)
    {
      local teamName = teamBySide[side]
      local teamArmiesList = ::u.filter(wwArmies, (@(side) function(army) { return army.side == side })(side))
      teamArmiesList.sort(function (a, b) { return a.unitType - b.unitType })

      local teamCountry = ""
      local teamArmyStates = {}
      local teamUnits = {}
      foreach (army in teamArmiesList)
      {
        if (teamCountry == "")
          teamCountry = army.country

        teamArmyStates[army.name] <- wwBattleResult?.armyStates[army.name].state ?? "EASAB_UNKNOWN"

        local armyUnits = initialArmies?[army.name].units ?? {}
        teamUnits = ::u.tablesCombine(teamUnits, armyUnits, function(a, b) { return a + b }, 0)
      }

      local teamCasualties = ::getTblValue(teamName, teamsCasualties, {})
      local teamUnitStats  = ::u.mapAdvanced(teamUnits, (@(teamCasualties) function(initial, unitName, ...) {
        local casualties = ::getTblValue(unitName, teamCasualties, 0)
        return {
          initial    = initial
          remain     = initial - casualties
          casualties = casualties
        }
      })(teamCasualties))

      teams[teamName] <- ::u.extend({}, teamDefaults, {
        name            = teamName
        side            = side
        country         = teamCountry
        armies          = teamArmiesList
        armyStates      = teamArmyStates
        unitsInitial    = wwActionsWithUnitsList.loadUnitsFromNameCountTbl(
          ::u.map(teamUnitStats, function(stats) { return stats.initial }))
        unitsCasualties = wwActionsWithUnitsList.loadUnitsFromNameCountTbl(
          ::u.map(teamUnitStats, function(stats) { return stats.casualties }))
        unitsRemain     = wwActionsWithUnitsList.loadUnitsFromNameCountTbl(
          ::u.map(teamUnitStats, function(stats) { return stats.remain }))
      })
    }

    return this
  }
}
