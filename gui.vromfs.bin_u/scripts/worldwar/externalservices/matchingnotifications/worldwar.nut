import "DataBlock" as DataBlock
from "guiMission" import get_current_mission_desc
from "gameplayBinding" import isInFlight
from "worldwar" import wwGetOperationId
from "%globalScripts/wwNativeConsts.nut" import *
from "%scripts/dagui_natives.nut" import get_local_player_country, ww_process_server_notification
from "%scripts/dagui_library.nut" import *
from "%scripts/webRPC.nut" import webRpcRegister
let { g_squad_manager } = require("%scripts/squads/squadManager.nut")
let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { subscribeOperationNotify, unsubscribeOperationNotify } = require("%scripts/worldWar/services/wwService.nut")
let { matchingRpcSubscribe } = require("%scripts/matching/api.nut")
let { chatSystemMessage } = require("%scripts/chat/mpChatModel.nut")
let { setWaitForQueueRoom } = require("%scripts/matchingRooms/sessionLobbyManager.nut")
let { getQueueClass } = require("%scripts/queue/queue/queueClasses.nut")
let { afterLeaveQueue, createQueue, afterJoinQueue } = require("%scripts/queue/queueManager.nut")
let { findQueueByName } = require("%scripts/queue/queueState.nut")

matchingRpcSubscribe("worldwar.on_join_to_battle", function(params) {
  let operationId = params?.operationId ?? ""
  let team = params?.team ?? SIDE_1
  let country = params?.country ?? ""
  let battleIds = (params?.battleIds ?? [])
  foreach (battleId in battleIds) {
    let queue = createQueue({
        operationId = operationId
        battleId = battleId
        country = country
        team = team
      }, true)
    afterJoinQueue(queue)
  }
  g_squad_manager.cancelWwBattlePrepare()
})

matchingRpcSubscribe("worldwar.on_leave_from_battle", function(params) {
  let queue = findQueueByName(getQueueClass("WwBattle").getName(params))
  if (!queue)
    return

  let reason = params?.reason ?? ""
  let isBattleStarted = reason == "battle-started"
  let msgText = !isBattleStarted
    ? loc($"worldWar/leaveBattle/{reason}", "")
    : ""

  afterLeaveQueue(queue, msgText.len() ? msgText : null)
  if (isBattleStarted)
    setWaitForQueueRoom(true)
})

matchingRpcSubscribe("worldwar.notify", function(params) {
  let messageType = params?.type
  if (!messageType)
    return

  if (messageType == "wwNotification") {
    ww_process_server_notification(params)
    return
  }

  if (!isInFlight())
    return

  let operationId = params?.operationId
  if (!operationId || operationId != wwGetOperationId())
    return

  let isOwnSide = (get_local_player_country() == params?.activeSideCountry)
  local text = ""
  if (messageType == "operation_finished") {
    let operation = getOperationById(operationId)
    text = operation ? loc("worldwar/operation_complete_battle_results_ignored_full_text",
      { operationInfo = operation.getNameText() })
                     : loc("worldwar/operation_complete_battle_results_ignored")
  }
  else if (messageType == "zone_captured") {
    text = loc(isOwnSide ? "worldwar/operation_zone_captured"
                           : "worldwar/operation_zone_lost",
      { zoneName = params?.customParam ?? "" })
  }
  else if (messageType == "reinforcements_arrived") {
    let misBlk = DataBlock()
    get_current_mission_desc(misBlk)
    if (params?.customParam == misBlk?.customRules.battleId)
      text = loc(isOwnSide ? "worldwar/operation_air_reinforcements_arrived_our"
                             : "worldwar/operation_air_reinforcements_arrived_enemy")
  }
  else if (messageType == "battle_finished") {
    text = loc(isOwnSide ? "worldwar/operation_battle_won_our"
                           : "worldwar/operation_battle_won_enemy",
      { zoneName = params?.customParam ?? "" })
  }

  if (text != "")
    chatSystemMessage(text)
})

webRpcRegister("worldwar_forced_subscribe", function(params) {
  let operationId = params?.id
  if (!operationId)
    return

  if (params?.subscribe ?? false)
    subscribeOperationNotify(operationId)
  else
    unsubscribeOperationNotify(operationId)
})
