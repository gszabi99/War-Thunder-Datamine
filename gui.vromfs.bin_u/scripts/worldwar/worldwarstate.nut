from "%scripts/dagui_library.nut" import *

let DataBlock  = require("DataBlock")
let { search } = require("%sqStdLibs/helpers/u.nut")
let { userIdInt64 } = require("%scripts/user/profileStates.nut")
let wwEvent = require("%scripts/worldWar/wwEvent.nut")
let { wwGetArmyGroupsInfo, wwGetBattlesInfo, wwGetOperationId } = require("worldwar")
let { request_nick_by_uid_batch } = require("%scripts/matching/requests.nut")
let { get_current_mission_desc } = require("guiMission")


let isLastFlightWasWwBattle = Watched(false)
let armyGroups = []
let battles = []
let baseWWState = {
  isArmyGroupsValid = false
  isBattlesValid = false
  isDebugMode = false
}

local WwArmyGroupClass = null
local WwBattleClass = null

local armyManagersNames = {}
local currentOperationID = 0

function updateArmyManagersNames(namesByUids) {
  foreach (uid, name in namesByUids)
    armyManagersNames[uid.tointeger()] <- { name = name }
}

function updateArmyManagers(wwArmyGroups) {
  foreach (group in wwArmyGroups)
    group.updateManagerStat(armyManagersNames)
}

function updateManagers() {
  let operationID = wwGetOperationId()
  if (operationID != currentOperationID) {
    currentOperationID = operationID
    armyManagersNames = {}
  }

  let reqUids = []
  foreach (group in armyGroups)
    reqUids.extend(group.getUidsForNickRequest(armyManagersNames))

  if (reqUids.len() > 0)
    request_nick_by_uid_batch(reqUids, function(resp) {
      let namesByUids = resp?.result
      if (namesByUids == null)
        return

      updateArmyManagersNames(namesByUids)
      updateArmyManagers(armyGroups)
      wwEvent("ArmyManagersInfoUpdated")
    })
  else {
    updateArmyManagers(armyGroups)
    wwEvent("ArmyManagersInfoUpdated")
  }
}


function updateArmyGroups() {
  if (WwArmyGroupClass == null) {
    logerr("[worldWarState] missing WwArmyGroupClass")
    return
  }
  if (baseWWState.isArmyGroupsValid)
    return

  baseWWState.isArmyGroupsValid = true
  armyGroups.clear()

  let blk = DataBlock()
  wwGetArmyGroupsInfo(blk)
  if ("armyGroups" not in blk)
    return

  for (local i = 0; i < blk.armyGroups.blockCount(); i++) {
    let itemBlk = blk.armyGroups.getBlock(i)
    let group   = WwArmyGroupClass(itemBlk)
    if (group.isValid())
      armyGroups.append(group)
  }
  updateManagers()
}

function getArmyGroups(filterFunc = null) {
  updateArmyGroups()
  return filterFunc ? armyGroups.filter(filterFunc) : armyGroups
}


function getArmyGroupsBySide(side, filterFunc = null) {
  return getArmyGroups(
     function (group) {
      if (group.owner.side != side)
        return false

      return filterFunc ? filterFunc(group) : true
    }
  )
}


function updateBattles(forced = false) {
  if (WwArmyGroupClass == null) {
    logerr("[worldWarState] missing WwBattleClass")
    return
  }
  if (baseWWState.isBattlesValid && !forced)
    return

  baseWWState.isBattlesValid = true
  battles.clear()

  let blk = DataBlock()
  wwGetBattlesInfo(blk)
  if (!("battles" in blk))
    return

  let itemCount = blk.battles.blockCount()
  for (local i = 0; i < itemCount; i++) {
    let itemBlk = blk.battles.getBlock(i)
    let battle   = WwBattleClass(itemBlk)

    if (battle.isValid())
      battles.append(battle)
  }
}

function getBattles(filterFunc = null, forced = false) {
  updateBattles(forced)
  return filterFunc ? battles.filter(filterFunc) : battles
}


function getBattleById(battleId) {
  return getBattles(@(checkedBattle) checkedBattle.id == battleId)?[0] ?? WwBattleClass()
}


function getCurMissionWWBattleName() {
  let misBlk = DataBlock()
  get_current_mission_desc(misBlk)

  let battleId = misBlk?.customRules.battleId
  if (!battleId)
    return ""

  return getBattleById(battleId).getBattleName()
}


function getArmyGroupByArmy(army) {
  return search(getArmyGroups(),
     function (group) {
      return group.isMyArmy(army)
    }
  )
}

function getMyArmyGroup() {
  return search(getArmyGroups(),
      function(group) {
        return isInArray(userIdInt64.get(), group.observerUids)
      }
    )
}

function getBattleForArmy(army, _playerSide = SIDE_NONE) {
  if (!army)
    return null

  return search(getBattles(), @(battle)
    !battle.isFinished() && battle.isArmyJoined(army.name))
}

return {
  baseWWState
  armyGroups
  battles
  isLastFlightWasWwBattle
  getArmyGroups
  getArmyGroupsBySide
  getBattles
  getBattleById
  getCurMissionWWBattleName
  getArmyGroupByArmy
  getMyArmyGroup
  getBattleForArmy
  registerWwArmyGroupClass = @(armyGroupClass) WwArmyGroupClass = armyGroupClass
  registerWwBattleClass = @(battleClass) WwBattleClass = battleClass
}
