import "DataBlock" as DataBlock
from "%scripts/squads/squadManager.nut" import g_squad_manager
from "%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut" import getOperationById
from "%scripts/worldWar/services/wwService.nut" import subscribeOperationNotify, unsubscribeOperationNotify
from "%scripts/matching/api.nut" import matchingRpcSubscribe
from "%scripts/chat/mpChatModel.nut" import chatSystemMessage
from "%scripts/matchingRooms/sessionLobbyManager.nut" import setWaitForQueueRoom
from "%scripts/queue/queue/queueClasses.nut" import getQueueClass
from "%scripts/queue/queueManager.nut" import afterLeaveQueue, createQueue, afterJoinQueue
from "%scripts/queue/queueState.nut" import findQueueByName
from "guiMission" import get_current_mission_desc
from "gameplayBinding" import isInFlight
from "worldwar" import wwGetOperationId
from "%globalScripts/wwNativeConsts.nut" import *
from "%scripts/dagui_natives.nut" import get_local_player_country, ww_process_server_notification
from "%scripts/dagui_library.nut" import *
from "%scripts/webRPC.nut" import webRpcRegister

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
