local u = require("sqStdLibs/helpers/u.nut")
local wwActionsWithUnitsList = require("scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")
local { getOperationById } = require("scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")

local WwGlobalBattle = class extends ::WwBattle
{
  operationId = -1
  sidesByCountry = null

  function updateParams(blk, params)
  {
    sidesByCountry = {}

    local teamsBlk = blk.getBlockByName("teams")
    if (!teamsBlk)
      return

    local countries = params?.countries
    for (local i = 0; i < teamsBlk.blockCount(); i++)
    {
      local teamBlk = teamsBlk.getBlock(i)
      local teamSide = teamBlk?.side
      local teamCountry = countries?[teamSide]
      if (teamSide && teamCountry)
        sidesByCountry[teamCountry] <- ::ww_side_name_to_val(teamSide)
    }
  }

  function updateTeamsInfo(blk)
  {
    teams = {}
    totalPlayersNumber = 0
    maxPlayersNumber = 0
    unitTypeMask = 0

    local teamsBlk = blk.getBlockByName("teams")
    if (!teamsBlk)
      return

    local updatesBlk = blk.getBlockByName("battleUpdates")
    local updatedTeamsBlk = updatesBlk ? updatesBlk.getBlockByName("teams") : null
    for (local i = 0; i < teamsBlk.blockCount(); ++i)
    {
      local teamBlk = teamsBlk.getBlock(i)
      local teamName = teamBlk.getBlockName() || ""
      if (teamName.len() == 0)
        continue

      local teamSideName = teamBlk?.side ?? ""
      if (teamSideName.len() == 0)
        continue

      local numPlayers = teamBlk?.players ?? 0
      local teamMaxPlayers = teamBlk?.maxPlayers ?? 0
      local teamUnitTypes = []

      local teamUnitsRemain = []
      local unitsRemainBlk = teamBlk.getBlockByName("unitsRemain")
      teamUnitsRemain.extend(wwActionsWithUnitsList.loadUnitsFromBlk(unitsRemainBlk))

      if (updatedTeamsBlk)
      {
        local updatedTeamBlk = updatedTeamsBlk.getBlockByName(teamName)
        if (updatedTeamBlk)
          teamUnitsRemain.extend(
            wwActionsWithUnitsList.loadUnitsFromBlk(updatedTeamBlk.getBlockByName("unitsAdded")))
      }

      teamUnitsRemain.sort(@(a, b) a.wwUnitType.sortCode <=> b.wwUnitType.sortCode)
      foreach(unit in teamUnitsRemain)
        if (!unit.isControlledByAI())
        {
          u.appendOnce(unit.wwUnitType.code, teamUnitTypes)
          unitTypeMask = unitTypeMask | unitTypes.getByEsUnitType(unit.wwUnitType.esUnitCode).bit
        }
      local teamInfo = {name = teamName
                        players = numPlayers
                        maxPlayers = teamMaxPlayers
                        minPlayers = minPlayersPerArmy
                        side = ::ww_side_name_to_val(teamSideName)
                        unitsRemain = teamUnitsRemain
                        unitTypes = teamUnitTypes}
      teams[teamName] <- teamInfo
      totalPlayersNumber += numPlayers
      maxPlayersNumber += teamMaxPlayers
    }
  }

  function isStillInOperation()
  {
    return true
  }

  function hasSideCountry(country)
  {
    return sidesByCountry?[country]
  }

  function getMyAssignCountry()
  {
    local operation = getOperationById(operationId)
    return operation ? operation.getMyAssignCountry() : null
  }

  function isOperationMapAvaliable()
  {
    local operation = getOperationById(operationId)
    if (!operation)
      return false

    local map = operation.getMap()
    if (!map)
      return false

    return map.isVisible()
  }

  function isAvaliableForMap(mapName)
  {
    local operation = getOperationById(operationId)
    if (!operation)
      return false

    local map = operation.getMap()
    if (!map)
      return false

    return map.name == mapName
  }

  function setOperationId(operId)
  {
    operationId = operId
  }

  function getOperationId()
  {
    return operationId
  }

  function getSectorName()
  {
    return ""
  }

  function getSide(country = null)
  {
    return getSideByCountry(country)
  }

  function getSideByCountry(country = null)
  {
    if (!country)
      return ::SIDE_NONE

    return sidesByCountry?[country] ?? ::SIDE_NONE
  }
}

u.registerClass("WwGlobalBattle", WwGlobalBattle, @(b1, b2) b1.id == b2.id)

return WwGlobalBattle
