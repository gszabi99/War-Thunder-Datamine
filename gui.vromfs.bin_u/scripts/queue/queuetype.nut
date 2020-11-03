local clustersModule = require("scripts/clusterSelect.nut")
local QUEUE_TYPE_BIT = require("scripts/queue/queueTypeBit.nut")

local enums = require("sqStdlibs/helpers/enums.nut")
enum qTypeCheckOrder {
  COMMON
  ANY_EVENT
  UNKNOWN
}

::g_queue_type <- {
  types = []
}

::g_queue_type.template <- {
  typeName = "" //filled automatically by typeName
  bit = QUEUE_TYPE_BIT.UNKNOWN
  checkOrder = qTypeCheckOrder.COMMON
  getQueueClass = @(params) ::queue_classes.Event
  useSlots = true

  prepareQueueParams = function(params)
  {
    if (useSlots)
      if(!("slots" in params))
        params.slots <- ::getSelSlotsTable()

    if(!("clusters" in params))
      params.clusters <- clustersModule.getCurrentClusters()

    return params
  }

  createQueue = @(queueId, params) getQueueClass(params)(queueId, this, params)
  leaveAllQueues = @(successCallback, errorCallback, needShowError = false)
    getQueueClass(null).leaveAll(successCallback, errorCallback, needShowError)
  updateInfo = function(successCallback, errorCallback, needAllQueues = false) {}
  isParamsCorresponds = @(params) true
}

enums.addTypesByGlobalName("g_queue_type",
  {
    UNKNOWN = {
      checkOrder = qTypeCheckOrder.UNKNOWN
    }

    EVENT = {
      bit = QUEUE_TYPE_BIT.EVENT
      checkOrder = qTypeCheckOrder.ANY_EVENT
      isParamsCorresponds = @(params) !::u.isEmpty(::getTblValue("mode", params))
    }

    NEWBIE = {
      bit = QUEUE_TYPE_BIT.NEWBIE
      isParamsCorresponds = @(params) ("mode" in params) && ::my_stats.isNewbieEventId(params.mode)
    }

    DOMINATION = {
      bit = QUEUE_TYPE_BIT.DOMINATION
      isParamsCorresponds = @(params) ("mode" in params) && ::events.isEventRandomBattlesById(params.mode)
    }

    WW_BATTLE = {
      bit = QUEUE_TYPE_BIT.WW_BATTLE
      getQueueClass = @(params) ::queue_classes.WwBattle
      useSlots = false

      isParamsCorresponds = @(params) "battleId" in params
      prepareQueueParams = function(params)
      {
        local wwBattle = params?.wwBattle
        local side = params?.side ?? ::SIDE_1
        return {
          clusters    = clustersModule.getCurrentClusters()
          operationId = params.operationId
          battleId    = params.battleId
          country     = wwBattle ? wwBattle.getCountryNameBySide(side)
                          : ::getTblValue("country", params, "")
          team        = wwBattle ? wwBattle.getTeamNameBySide(side)
                          : ::getTblValue("team", params, ::SIDE_1)
          isBattleByUnitsGroup = wwBattle?.isBattleByUnitsGroup() ?? false
        }
      }

      //FIX ME: why it work not by queueStats and queueInfo classes?
      updateInfo = function(successCallback, errorCallback, needAllQueues = false) {
        ::request_matching(
          "worldwar.get_queue_info",
          function(response) {
            local queuesInfo = {}
            local responseQueues = ::getTblValue("queues", response, [])
            foreach(battleQueueInfo in responseQueues)
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

::g_queue_type.types.sort(@(a, b) a.checkOrder <=> b.checkOrder)

g_queue_type.getQueueTypeByParams <- function getQueueTypeByParams(params)
{
  if (!params)
    return UNKNOWN
  foreach(qType in types)
    if (qType.isParamsCorresponds(params))
      return qType
  return UNKNOWN
}
