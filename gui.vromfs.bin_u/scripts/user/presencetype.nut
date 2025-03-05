from "%scripts/dagui_natives.nut" import get_game_mode_name
from "%scripts/dagui_library.nut" import *

let { format } = require("string")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let g_squad_manager = getGlobalModule("g_squad_manager")
let enums = require("%sqStdLibs/helpers/enums.nut")
let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { get_game_mode } = require("mission")
let { isInFlight } = require("gameplayBinding")
let { isInSessionRoom, getSessionLobbyOperationId, getSessionLobbyWwBattleId
} = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { getEventEconomicName } = require("%scripts/events/eventInfo.nut")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let { isWorldWarEnabled } = require("%scripts/globalWorldWarScripts.nut")
let { getRoomEvent } = require("%scripts/matchingRooms/sessionLobbyInfo.nut")
let { getQueueClass } = require("%scripts/queue/queue/queueClasses.nut")
let { queues } = require("%scripts/queue/queueManager.nut")
let WwOperation = require("%scripts/worldWar/operations/model/wwOperation.nut")

enum presenceCheckOrder {
  IN_GAME_WW
  IN_GAME
  IN_QUEUE
  IN_WW_BATTLE_PREPARE
  IDLE
}

let getGameModeLocName = @(gm) loc(format("multiplayer/%sMode", get_game_mode_name(gm)))

let presenceTypes = {
  types = []
}

presenceTypes.template <- {
  typeName = "" //Generic from type.
  checkOrder = presenceCheckOrder.IDLE
  locId = ""
  locIdShort = ""
  isInBattle = false
  isMatch = @() false
  getParams = function() {
    let params = { presenceId = this.typeName }
    this.updateParams(params)
    return params
  }
  updateParams = @(params) params
  getLocText = @(_presenceParams) loc(this.locId)
  canInviteToWWBattle = true
  getLocStatusShort = @() loc(this.locIdShort)
  getLocTextShort = @(_presenceParams) ""
}

enums.addTypes(presenceTypes, {
  IDLE = {
    checkOrder = presenceCheckOrder.IDLE
    locId = "status/idle"
    locIdShort = "status/idle"
    isMatch = @() true
  }

  IN_QUEUE = {
    checkOrder = presenceCheckOrder.IN_QUEUE
    locId = "status/in_queue"
    locIdShort = "status/in_queue_short"
    queueTypeMask = QUEUE_TYPE_BIT.EVENT | QUEUE_TYPE_BIT.DOMINATION | QUEUE_TYPE_BIT.NEWBIE
    isMatch = @() queues.isAnyQueuesActive(this.queueTypeMask)
    updateParams = function(params) {
      let queue = queues.getActiveQueueWithType(this.queueTypeMask)
      params.eventName <- getEventEconomicName(queues.getQueueEvent(queue))
      params.country <- queues.getQueueCountry(queue)
    }
    getLocText = @(presenceParams) loc(this.locId, {
      gameMode = events.getNameByEconomicName(presenceParams?.eventName ?? "")
      country = loc(presenceParams?.country ?? "")
    })
    getLocTextShort = @(presenceParams) $"{events.getNameByEconomicName(presenceParams?.eventName ?? "")}, {loc(presenceParams?.country ?? "")}"
  }

  IN_GAME = {
    checkOrder = presenceCheckOrder.IN_GAME
    locId = "status/in_game"
    locIdShort = "status/in_game_short"
    isInBattle = true
    isMatch = @() ((isInFlight() && !getCurMissionRules().isWorldWar)
                    || isInSessionRoom.get())
    canInviteToWWBattle = false
    updateParams = function(params) {
      params.gameMod <- get_game_mode()
      params.eventName <- getEventEconomicName(getRoomEvent())
      params.country <- profileCountrySq.value
    }
    getLocText = function (presenceParams) {
      let eventName = presenceParams?.eventName ?? ""
      return loc(this.locId,
        { gameMode = eventName == "" ? getGameModeLocName(presenceParams?.gameMod)
          : events.getNameByEconomicName(presenceParams?.eventName)
          country = loc(presenceParams?.country ?? "")
        })
    }
    getLocTextShort = function (presenceParams) {
      let eventName = presenceParams?.eventName ?? ""
      return $"{eventName == "" ? getGameModeLocName(presenceParams?.gameMod) : events.getNameByEconomicName(presenceParams?.eventName)}, {loc(presenceParams?.country ?? "")}"
    }
  }

  IN_QUEUE_WW = {
    checkOrder = presenceCheckOrder.IN_QUEUE
    locId = "status/in_queue_ww"
    locIdShort = "status/in_queue_short"
    queueTypeMask = QUEUE_TYPE_BIT.WW_BATTLE
    isMatch = @() isWorldWarEnabled() && queues.isAnyQueuesActive(this.queueTypeMask)
    updateParams = function(params) {
      let queue = queues.getActiveQueueWithType(this.queueTypeMask)
      let operationId = queues.getQueueOperationId(queue)
      let battleId = queue instanceof getQueueClass("WwBattle") ? queue.getQueueWwBattleId() : ""
      let operation = ::g_ww_global_status_actions.getOperationById(operationId)
      if (!operation)
        return
      params.operationId <- operationId
      params.battleId <- battleId
      params.mapId <- operation.getMapId()
      params.country <- queues.getQueueCountry(queue)
    }
    getLocText = function(presenceParams) {
      let map = ::g_ww_global_status_actions.getMapByName(presenceParams?.mapId)
      return loc(this.locId,
        { operationName = map
            ? WwOperation.getNameTextByIdAndMapName(presenceParams?.operationId, map.getNameText())
            : ""
          country = loc(presenceParams?.country ?? "")
        })
    }
    getLocTextShort = function(presenceParams) {
      let map = ::g_ww_global_status_actions.getMapByName(presenceParams?.mapId)
      return $"{map ? WwOperation.getNameTextByIdAndMapName(presenceParams?.operationId, map.getNameText()) : ""}, {loc(presenceParams?.country ?? "")}"
    }
  }

  IN_GAME_WW = {
    checkOrder = presenceCheckOrder.IN_GAME_WW
    locId = "status/in_game_ww"
    locIdShort = "status/in_game_short"
    isInBattle = true
    isMatch = @() isWorldWarEnabled() && isInFlight() && getCurMissionRules().isWorldWar
    canInviteToWWBattle = false
    updateParams = function(params) {
      let operationId = getSessionLobbyOperationId()
      let operation = ::g_ww_global_status_actions.getOperationById(operationId)
      if (!operation)
        return
      params.operationId <- operationId
      params.battleId <- getSessionLobbyWwBattleId()
      params.mapId <- operation.getMapId()
      params.country <- operation.getMyClanCountry() || profileCountrySq.value
    }
    getLocText = function(presenceParams) {
      let map = ::g_ww_global_status_actions.getMapByName(presenceParams?.mapId)
      return loc(this.locId,
        { operationName = map
            ? WwOperation.getNameTextByIdAndMapName(presenceParams?.operationId ?? "", map.getNameText())
            : ""
          country = loc(presenceParams?.country ?? "")
        })
    }
    getLocTextShort = function(presenceParams) {
      let map = ::g_ww_global_status_actions.getMapByName(presenceParams?.mapId)
      return $"{map ? WwOperation.getNameTextByIdAndMapName(presenceParams?.operationId ?? "", map.getNameText()) : ""}, {loc(presenceParams?.country ?? "")}"
    }
  }

  IN_WW_BATTLE_PREPARE = {
    checkOrder = presenceCheckOrder.IN_WW_BATTLE_PREPARE
    locId = "status/in_prepare_ww"
    locIdShort = "status/in_prepare_ww_short"
    isMatch = @() isWorldWarEnabled() && g_squad_manager.getWwOperationBattle() != null
    updateParams = function(params) {
      params.operationId <- g_squad_manager.getWwOperationId()
      params.battleId <- g_squad_manager.getWwOperationBattle()
      params.country <- g_squad_manager.getWwOperationCountry()
    }
    getLocText = function(presenceParams) {
      let operationId = presenceParams?.operationId
      let operation = ::g_ww_global_status_actions.getOperationById(operationId)
      if (!operation)
        return ""

      let map = ::g_ww_global_status_actions.getMapByName(operation.getMapId())
      let text = loc(this.locId,
        { operationName = map
            ? WwOperation.getNameTextByIdAndMapName(operationId, map.getNameText()) : ""
          country = loc(presenceParams?.country ?? "")
        })
      return text
    }
    getLocTextShort = function(presenceParams) {
      let operationId = presenceParams?.operationId
      let operation = ::g_ww_global_status_actions.getOperationById(operationId)
      if (!operation)
        return ""

      let map = ::g_ww_global_status_actions.getMapByName(operation.getMapId())
      return $"{map ? WwOperation.getNameTextByIdAndMapName(operationId, map.getNameText()) : ""}, {loc(presenceParams?.country ?? "")}"
    }
  }
}, null, "typeName")

presenceTypes.types.sort(@(a, b) a.checkOrder <=> b.checkOrder)

function getCurrentPresenceType() {
  foreach (presenceType in presenceTypes.types)
    if (presenceType.isMatch())
      return presenceType
  return presenceTypes.IDLE
}

function getByPresenceParams(presenceParams) {
  return presenceTypes?[presenceParams?.presenceId] ?? presenceTypes.IDLE
}

return {
  presenceTypes
  getCurrentPresenceType
  getByPresenceParams
}