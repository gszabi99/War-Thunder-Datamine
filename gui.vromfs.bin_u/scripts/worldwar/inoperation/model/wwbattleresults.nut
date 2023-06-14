//checked for plus_string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")


let wwActionsWithUnitsList = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")

::WwBattleResults <- class {
  id = ""
  winner = SIDE_NONE
  operationId = null
  playerSide = SIDE_NONE
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
    side            = SIDE_NONE
    country         = ""
    armies          = []
    armyStates      = {}
    unitsInitial    = []
    unitsCasualties = []
    unitsRemain     = []
  }

  constructor(blk = null) {
    this.teams = {}
    if (!blk)
      return

    let battleBlk = blk?.battle
    let armiesBlk = blk?.armies
    let armyStatesBlk = blk?.armyStates
    if (!battleBlk || !armiesBlk || !armyStatesBlk)
      return

    this.id = battleBlk?.id ?? ""
    this.time = blk?.time ?? 0
    this.updateAppliedOnHost = battleBlk?.updateAppliedOnHost ?? -1
    this.locName = battleBlk?.desc?.locName ?? ""
    this.ordinalNumber = battleBlk?.ordinalNumber ?? 0
    this.zoneName = blk?.zoneInfo?.zoneName ?? ""
    this.sessionId = battleBlk?.desc?.sessionId ?? ""

    let wwArmies = this.getArmies(armiesBlk)
    this.updateTeamsInfo(battleBlk, armyStatesBlk, wwArmies)

    this.applyBattleUpdates(battleBlk)
  }

  function isValid() {
    return this.id != ""
  }

  function getView() {
    if (!this.view)
      this.view = ::WwBattleResultsView(this)
    return this.view
  }

  function getArmies(armiesBlk) {
    let wwArmies = {}
    foreach (armyBlk in armiesBlk)
      wwArmies[armyBlk.name] <- ::WwArmy(armyBlk.name, armyBlk)
    return wwArmies
  }

  function getSessionId() {
    return this.sessionId
  }

  function updateTeamsInfo(battleBlk, armyStatesBlk, wwArmies) {
    this.teams = {}

    let teamsBlk = battleBlk.getBlockByName("teams")
    let descBlk = battleBlk.getBlockByName("desc")
    let teamsInfoBlk = descBlk ? descBlk.getBlockByName("teamsInfo") : null
    if (!teamsBlk || !teamsInfoBlk)
      return

    for (local i = 0; i < teamsBlk.blockCount(); ++i) {
      let teamBlk = teamsBlk.getBlock(i)
      let teamName = teamBlk.getBlockName() ?? ""
      if (teamName.len() == 0)
        continue

      let sideName = teamBlk?.side ?? ""
      if (sideName.len() == 0)
        continue
      let side = ::ww_side_name_to_val(sideName)

      if (teamBlk?.isWinner)
        this.winner = side

      let armyNamesBlk = teamBlk.getBlockByName("armyNames")
      local teamCountry = ""
      let teamArmiesList = []
      let teamArmyStates = {}
      if (armyNamesBlk) {
        for (local j = 0; j < armyNamesBlk.paramCount(); ++j) {
          let armyName = armyNamesBlk.getParamValue(j) || ""
          if (armyName.len() == 0)
            continue

          let army = getTblValue(armyName, wwArmies)
          let armyState = armyStatesBlk?[armyName].state ?? "EASAB_UNKNOWN"

          if (teamCountry == "")
            teamCountry = army.owner.country
          teamArmiesList.append(army)
          teamArmyStates[armyName] <- armyState
        }
      }

      teamArmiesList.sort(::WwArmy.sortArmiesByUnitType)

      let teamInfoBlk = teamsInfoBlk?[teamName]
      let unitsInitialBlk = teamInfoBlk?.units

      let unitsInitial = wwActionsWithUnitsList.loadUnitsFromBlk(unitsInitialBlk)
      unitsInitial.extend(wwActionsWithUnitsList.getFakeUnitsArray(teamInfoBlk))

      let unitsRemain = wwActionsWithUnitsList.loadUnitsFromBlk(teamBlk?.unitsRemain)
      unitsRemain.extend(wwActionsWithUnitsList.getFakeUnitsArray(teamBlk))

      let unitsCasualties = wwActionsWithUnitsList.loadUnitsFromBlk(teamBlk?.casualties)

      this.teams[teamName] <- u.extend({}, this.teamDefaults, {
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

  function applyBattleUpdates(battleBlk) {
    let updatesBlk = battleBlk.getBlockByName("battleUpdates")
    if (!updatesBlk)
      return

    for (local i = 0; i < updatesBlk.blockCount(); i++) {
      let updateBlk = updatesBlk.getBlock(i)
      let isNeedUpdateUnitsRemain = (updateBlk?.updateId ?? -1) > this.updateAppliedOnHost

      let teamsBlk = updateBlk?.teams
      if (!teamsBlk)
        continue
      for (local j = 0; j < teamsBlk.blockCount(); j++) {
        let teamBlk = teamsBlk.getBlock(j)
        let team = getTblValue(teamBlk.getBlockName() || "", this.teams)
        if (!team)
          continue

        let wwUnitsAdded = wwActionsWithUnitsList.loadUnitsFromBlk(teamBlk?.unitsAdded)

        let teamUnitsLists = isNeedUpdateUnitsRemain ?
          [ team.unitsInitial, team.unitsRemain ] :
          [ team.unitsInitial ]

        foreach (unitsList in teamUnitsLists) {
          foreach (wwUnitNew in wwUnitsAdded) {
            let unitName = wwUnitNew.name
            local hasUnit = false
            foreach (wwUnit in unitsList)
              if (wwUnit.name == unitName) {
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

  function isWinner() {
    return this.winner != SIDE_NONE && this.winner == this.playerSide
  }

  function getOperationId() {
    return this.operationId
  }

  function getPlayerCountry() {
    return this.playerCountry
  }

  /**
  Fills WwBattleResults with data from mission result Userlog.
  Such userlog contains most data in sub tables wwSharedPool and wwBattleResult,
  and some data in userlog root table.
  It operation was finished during the battle, there will be no wwBattleResult block.
  */
  function updateFromUserlog(userlog) {
    let wwSharedPool = getTblValue("wwSharedPool", userlog)
    let wwBattleResult = getTblValue("wwBattleResult", userlog, {})
    if (!wwSharedPool)
      return this

    let initialArmies = getTblValue("initialArmies", wwSharedPool, [])
    let teamsCasualties = getTblValue("casualties", wwSharedPool, [])

    // Restoring team sides

    let localTeam  = getTblValue("localTeam", wwSharedPool, "")
    let sidesOrder = ::g_world_war.getSidesOrder() // [ player, enemy ]
    let winnerSide = getTblValue("win", userlog) ? sidesOrder[0] : sidesOrder[1]

    local sideInBattle = SIDE_NONE
    local countryInBattle = ""
    let teamBySide = {}
    foreach (_armyName, initialArmy in initialArmies) {
      let teamName = getTblValue("team", initialArmy, "")
      let side = teamName == localTeam ? sidesOrder[0] : sidesOrder[1]
      teamBySide[side] <- teamName
      initialArmy.side <- ::ww_side_val_to_name(side)
      if (teamName == localTeam) {
        sideInBattle = side
        countryInBattle = initialArmy.country
      }
    }

    // Collecting armies

    let wwArmies = initialArmies.map(function(initialArmy, armyName) {
      let armyState = wwBattleResult?.armyStates[armyName] ?? {}

      let side  = ::ww_side_name_to_val(getTblValue("side", initialArmy, ""))
      let country = getTblValue("country", initialArmy, "")
      let clanTag = getTblValue("armyGroupName", armyState, "")
      let unitTypeTextCode = getTblValue("unitType", initialArmy, "")
      let wwUnitType = ::g_ww_unit_type.getUnitTypeByTextCode(unitTypeTextCode)
      let wwArmy = ::g_world_war.getArmyByName(armyName)
      let hasFoundArmy = wwArmy.getUnitType() != ::g_ww_unit_type.UNKNOWN.code

      let armyView = {
        getTeamColor      = side == sideInBattle ? "blue" : "red"
        isBelongsToMyClan = clanTag == ::clan_get_my_clan_tag()
        getTextAfterIcon  = clanTag
        getUnitTypeText   = hasFoundArmy ? wwArmy.getView().getUnitTypeText() : wwUnitType.fontIcon
        getUnitTypeCustomText = hasFoundArmy ? wwArmy.getView().getUnitTypeCustomText() : wwUnitType.fontIcon
      }

      return {
        name = armyName
        side = side
        country = country
        unitType = wwUnitType.code
        deathReason = ""
        getView = @() armyView
      }
    })

    // Updating

    let wwOperationId = wwSharedPool?.operationId
    this.id = getTblValue("battleId", wwSharedPool, "")
    if (wwOperationId)
      this.operationId = wwOperationId.tointeger()
    this.winner = winnerSide
    this.playerSide = sideInBattle
    this.playerCountry = countryInBattle
    this.locName = getTblValue("locName", userlog, "")
    this.isBattleResultsIgnored = ::g_world_war.isCurrentOperationFinished()

    this.teams = {}
    foreach (side in sidesOrder) {
      let teamName = teamBySide[side]
      let teamSide = side
      let teamArmiesList = u.filter(wwArmies, (@(army) army.side == teamSide))
      teamArmiesList.sort(function (a, b) { return a.unitType - b.unitType })

      local teamCountry = ""
      let teamArmyStates = {}
      local teamUnits = {}
      foreach (army in teamArmiesList) {
        if (teamCountry == "")
          teamCountry = army.country

        teamArmyStates[army.name] <- wwBattleResult?.armyStates[army.name].state ?? "EASAB_UNKNOWN"

        let armyUnits = initialArmies?[army.name].units ?? {}
        teamUnits = u.tablesCombine(teamUnits, armyUnits, function(a, b) { return a + b }, 0)
      }

      let teamCasualties = getTblValue(teamName, teamsCasualties, {})
      let teamUnitStats  = u.mapAdvanced(teamUnits, function(initial, unitName, ...) {
        let casualties = getTblValue(unitName, teamCasualties, 0)
        return {
          initial    = initial
          remain     = initial - casualties
          casualties = casualties
        }
      })

      this.teams[teamName] <- u.extend({}, this.teamDefaults, {
        name            = teamName
        side            = side
        country         = teamCountry
        armies          = teamArmiesList
        armyStates      = teamArmyStates
        unitsInitial    = wwActionsWithUnitsList.loadUnitsFromNameCountTbl(
          u.map(teamUnitStats, function(stats) { return stats.initial }))
        unitsCasualties = wwActionsWithUnitsList.loadUnitsFromNameCountTbl(
          u.map(teamUnitStats, function(stats) { return stats.casualties }))
        unitsRemain     = wwActionsWithUnitsList.loadUnitsFromNameCountTbl(
          u.map(teamUnitStats, function(stats) { return stats.remain }))
      })
    }

    return this
  }
}
