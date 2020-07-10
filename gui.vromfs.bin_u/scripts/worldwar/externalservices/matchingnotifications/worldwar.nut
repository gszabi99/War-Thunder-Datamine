local { getOperationById } = require("scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
local { subscribeOperationNotify, unsubscribeOperationNotify } = require("scripts/worldWar/services/wwService.nut")

foreach (notificationName, callback in
  {
    ["worldwar.on_join_to_battle"] = function(params)
      {
        local operationId = params?.operationId ?? ""
        local team = params?.team ?? ::SIDE_1
        local country = params?.country ?? ""
        local battleIds = ::getTblValue("battleIds", params, [])
        foreach (battleId in battleIds)
        {
          local queue = ::queues.createQueue({
              operationId = operationId
              battleId = battleId
              country = country
              team = team
            }, true)
          ::queues.afterJoinQueue(queue)
        }
        ::g_squad_manager.cancelWwBattlePrepare()
      },
    ["worldwar.on_leave_from_battle"] = function(params)
      {
        local queue = ::queues.findQueueByName(::queue_classes.WwBattle.getName(params))
        if (!queue)
          return

        local reason = params?.reason ?? ""
        local isBattleStarted = reason == "battle-started"
        local msgText = !isBattleStarted
          ? ::loc("worldWar/leaveBattle/" + reason, "")
          : ""

        ::queues.afterLeaveQueue(queue, msgText.len() ? msgText : null)
        if (isBattleStarted)
          ::SessionLobby.setWaitForQueueRoom(true)
      },
    ["worldwar.notify"] = function(params)
      {
        local messageType = params?.type
        if (!messageType)
          return

        if (messageType == "wwNotification")
        {
          ::ww_process_server_notification(params)
          return
        }

        if (!::is_in_flight())
          return

        local operationId = params?.operationId
        if (!operationId || operationId != ::ww_get_operation_id())
          return

        local isOwnSide = (::get_local_player_country() == params?.activeSideCountry)
        local text = ""
        if (messageType == "operation_finished")
        {
          local operation = getOperationById(operationId)
          text = operation ? ::loc("worldwar/operation_complete_battle_results_ignored_full_text",
            {operationInfo = operation.getNameText()})
                           : ::loc("worldwar/operation_complete_battle_results_ignored")
        }
        else if (messageType == "zone_captured")
        {
          text = ::loc(isOwnSide ? "worldwar/operation_zone_captured"
                                 : "worldwar/operation_zone_lost",
            {zoneName = params?.customParam ?? ""})
        }
        else if (messageType == "reinforcements_arrived")
        {
          local misBlk = ::DataBlock()
          ::get_current_mission_desc(misBlk)
          if (params?.customParam == misBlk?.customRules.battleId)
            text = ::loc(isOwnSide ? "worldwar/operation_air_reinforcements_arrived_our"
                                   : "worldwar/operation_air_reinforcements_arrived_enemy")
        }
        else if (messageType == "battle_finished")
        {
          text = ::loc(isOwnSide ? "worldwar/operation_battle_won_our"
                                 : "worldwar/operation_battle_won_enemy",
            {zoneName = params?.customParam ?? ""})
        }

        if (text != "")
          ::chat_system_message(text)
      }
  })
  ::matching_rpc_subscribe(notificationName, callback)


foreach (notificationName, callback in
  {
    ["worldwar_forced_subscribe"] = function(params)
      {
        local operationId = params?.id
        if (!operationId)
          return

        if (params?.subscribe ?? false)
          subscribeOperationNotify(operationId)
        else
          unsubscribeOperationNotify(operationId)
      }
  })
  ::web_rpc.register_handler(notificationName, callback)
