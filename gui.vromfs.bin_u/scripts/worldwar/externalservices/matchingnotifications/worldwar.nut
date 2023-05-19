//-file:plus-string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { subscribeOperationNotify, unsubscribeOperationNotify } = require("%scripts/worldWar/services/wwService.nut")
let DataBlock  = require("DataBlock")
let { matchingRpcSubscribe } = require("%scripts/matching/api.nut")

matchingRpcSubscribe("worldwar.on_join_to_battle", function(params) {
  let operationId = params?.operationId ?? ""
  let team = params?.team ?? SIDE_1
  let country = params?.country ?? ""
  let battleIds = getTblValue("battleIds", params, [])
  foreach (battleId in battleIds) {
    let queue = ::queues.createQueue({
        operationId = operationId
        battleId = battleId
        country = country
        team = team
      }, true)
    ::queues.afterJoinQueue(queue)
  }
  ::g_squad_manager.cancelWwBattlePrepare()
})

matchingRpcSubscribe("worldwar.on_leave_from_battle", function(params) {
  let queue = ::queues.findQueueByName(::queue_classes.WwBattle.getName(params))
  if (!queue)
    return

  let reason = params?.reason ?? ""
  let isBattleStarted = reason == "battle-started"
  let msgText = !isBattleStarted
    ? loc("worldWar/leaveBattle/" + reason, "")
    : ""

  ::queues.afterLeaveQueue(queue, msgText.len() ? msgText : null)
  if (isBattleStarted)
    ::SessionLobby.setWaitForQueueRoom(true)
})

matchingRpcSubscribe("worldwar.notify", function(params) {
  let messageType = params?.type
  if (!messageType)
    return

  if (messageType == "wwNotification") {
    ::ww_process_server_notification(params)
    return
  }

  if (!::is_in_flight())
    return

  let operationId = params?.operationId
  if (!operationId || operationId != ::ww_get_operation_id())
    return

  let isOwnSide = (::get_local_player_country() == params?.activeSideCountry)
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
    ::get_current_mission_desc(misBlk)
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
    ::chat_system_message(text)
})

::web_rpc.register_handler("worldwar_forced_subscribe", function(params) {
  let operationId = params?.id
  if (!operationId)
    return

  if (params?.subscribe ?? false)
    subscribeOperationNotify(operationId)
  else
    unsubscribeOperationNotify(operationId)
})
