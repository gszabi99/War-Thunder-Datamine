from "%scripts/dagui_library.nut" import *

let DataBlock  = require("DataBlock")
let wwEvent = require("%scripts/worldWar/wwEvent.nut")
let { wwGetArmyGroupsInfo, wwGetBattlesInfo, wwGetOperationId } = require("worldwar")
let { WwArmyGroup } = require("%scripts/worldWar/inOperation/model/wwArmyGroup.nut")
let WwBattle = require("%scripts/worldWar/inOperation/model/wwBattle.nut")
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
    let group   = WwArmyGroup(itemBlk)
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
    let battle   = WwBattle(itemBlk)

    if (battle.isValid())
      battles.append(battle)
  }
}

function getBattles(filterFunc = null, forced = false) {
  updateBattles(forced)
  return filterFunc ? battles.filter(filterFunc) : battles
}


function getBattleById(battleId) {
  return getBattles(@(checkedBattle) checkedBattle.id == battleId)?[0] ?? WwBattle()
}


function getCurMissionWWBattleName() {
  let misBlk = DataBlock()
  get_current_mission_desc(misBlk)

  let battleId = misBlk?.customRules.battleId
  if (!battleId)
    return ""

  return getBattleById(battleId).getBattleName()
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
}
