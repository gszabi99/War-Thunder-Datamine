from "%scripts/dagui_library.nut" import *

let { request_matching } = require("%scripts/matching/api.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let clustersModule = require("%scripts/clusterSelect.nut")
let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let { getSelSlotsData } = require("%scripts/slotbar/slotbarState.nut")
let { isNewbieEventId } = require("%scripts/myStats.nut")
let { enumsAddTypes } = require("%sqStdLibs/helpers/enums.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { getQueueClass } = require("%scripts/queue/queue/queueClasses.nut")

enum qTypeCheckOrder {
  COMMON
  ANY_EVENT
  UNKNOWN
}

let g_queue_type = {
  types = []
}

g_queue_type.template <- {
  typeName = "" //filled automatically by typeName
  bit = QUEUE_TYPE_BIT.UNKNOWN
  checkOrder = qTypeCheckOrder.COMMON
  getQueueClass = @(_params) getQueueClass("Event")
  useSlots = true

  prepareQueueParams = function(params) {
    if (this.useSlots)
      if (!("slots" in params))
        params.slots <- getSelSlotsData().slots

    if (!("clusters" in params))
      params.clusters <- clustersModule.getCurrentClusters()

    return params
  }

  createQueue = @(queueId, params) this.getQueueClass(params)(queueId, this, params)
  leaveAllQueues = @(successCallback, errorCallback, needShowError = false)
    this.getQueueClass(null).leaveAll(successCallback, errorCallback, needShowError)
  updateInfo = function(_successCallback, _errorCallback, _needAllQueues = false) {}
  isParamsCorresponds = @(_params) true
}

enumsAddTypes(g_queue_type,
  {
    UNKNOWN = {
      checkOrder = qTypeCheckOrder.UNKNOWN
    }

    EVENT = {
      bit = QUEUE_TYPE_BIT.EVENT
      checkOrder = qTypeCheckOrder.ANY_EVENT
      isParamsCorresponds = @(params) !u.isEmpty(getTblValue("mode", params))
    }

    NEWBIE = {
      bit = QUEUE_TYPE_BIT.NEWBIE
      isParamsCorresponds = @(params) ("mode" in params) && isNewbieEventId(params.mode)
    }

    DOMINATION = {
      bit = QUEUE_TYPE_BIT.DOMINATION
      isParamsCorresponds = @(params) ("mode" in params) && events.isEventRandomBattlesById(params.mode)
    }

    WW_BATTLE = {
      bit = QUEUE_TYPE_BIT.WW_BATTLE
      getQueueClass = @(_params) getQueueClass("WwBattle")
      useSlots = false

      isParamsCorresponds = @(params) "battleId" in params
      prepareQueueParams = function(params) {
        let wwBattle = params?.wwBattle
        let side = params?.side ?? SIDE_1
        return {
          clusters    = clustersModule.getCurrentClusters()
          operationId = params.operationId
          battleId    = params.battleId
          country     = wwBattle ? wwBattle.getCountryNameBySide(side)
                          : getTblValue("country", params, "")
          team        = wwBattle ? wwBattle.getTeamNameBySide(side)
                          : getTblValue("team", params, SIDE_1)
          isBattleByUnitsGroup = wwBattle?.isBattleByUnitsGroup() ?? false
        }
      }

      //FIX ME: why it work not by queueStats and queueInfo classes?
      updateInfo = function(successCallback, errorCallback, needAllQueues = false) {
        request_matching(
          "worldwar.get_queue_info",
          function(response) {
            let queuesInfo = {}
            let responseQueues = getTblValue("queues", response, [])
            foreach (battleQueueInfo in responseQueues)
              if (battleQueueInfo?.battleId)
                queuesInfo[battleQueueInfo.battleId] <- battleQueueInfo

            if (successCallback != null)
              successCallback(queuesInfo)
          },
          errorCallback,
          { all_queues = needAllQueues },
          { showError = false }
        )
      }
    }
  },
  null,
  "typeName"
)

g_queue_type.types.sort(@(a, b) a.checkOrder <=> b.checkOrder)

g_queue_type.getQueueTypeByParams <- function getQueueTypeByParams(params) {
  if (!params)
    return this.UNKNOWN
  foreach (qType in this.types)
    if (qType.isParamsCorresponds(params))
      return qType
  return this.UNKNOWN
}

return freeze({g_queue_type})