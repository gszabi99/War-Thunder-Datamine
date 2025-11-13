from "%scripts/dagui_library.nut" import *
from "%scripts/queue/queueConsts.nut" import queueStates

let u = require("%sqStdLibs/helpers/u.nut")
let mapPreferencesParams = require("%scripts/missions/mapPreferencesParams.nut")
let { needActualizeQueueData, queueProfileJwt, actualizeQueueData } = require("%scripts/queue/queueBattleData.nut")
let { enqueueInSession } = require("%scripts/matching/serviceNotifications/match.nut")
let { checkMatchingError } = require("%scripts/matching/api.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_QUEUE_EVENT_CUSTOM_MODE, USEROPT_QUEUE_JIP, USEROPT_DISPLAY_MY_REAL_NICK,
  USEROPT_AUTO_SQUAD, USEROPT_CAN_QUEUE_TO_NIGHT_BATLLES, USEROPT_CAN_QUEUE_TO_SMALL_TEAMS_BATTLES,
  USEROPT_DISPLAY_MY_REAL_CLAN
} = require("%scripts/options/optionsExtNames.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { hasNightGameModes, hasSmallTeamsGameModes, getEventEconomicName } = require("%scripts/events/eventInfo.nut")
let { getGameModeIdsByEconomicName, getGameModeIdsByEconomicNameWithoutTags,
  NIGHT_GAME_MODE_TAG_PREFIX, SMALL_TEAMS_GAME_MODE_TAG_PREFIX
} = require("%scripts/matching/matchingGameModes.nut")
let { markToShowMultiplayerLimitByAasMsg } = require("%scripts/user/antiAddictSystem.nut")
let { EASTE_ERROR_DENIED_DUE_TO_AAS_LIMITS } = require("chardConst")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let events = getGlobalModule("events")
let { getRecentSquadMrank } = require("%scripts/battleRating.nut")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { get_gui_option_in_mode } = require("%scripts/options/options.nut")
let BaseQueue = require("%scripts/queue/queue/queueBase.nut")
let { registerQueueClass, getQueueClass } = require("%scripts/queue/queue/queueClasses.nut")
let { get_option_in_mode } = require("%scripts/options/optionsExt.nut")
let { getShouldEventQueueCustomMode, setShouldEventQueueCustomMode, requestLeaveQueue, findQueueByName
} = require("%scripts/queue/queueState.nut")
let { getQueueCountry, getQueueSlots } = require("%scripts/queue/queueInfo.nut")
let { leaveAllQueuesSilent, joinQueueImpl } = require("%scripts/queue/queueManager.nut")
let crossplayModule = require("%scripts/social/crossplay.nut")

function getCustomMgm(eventName) {
  return events.getCustomGameMode(events.getEvent(eventName))
}

function hasCustomModeByEventName(eventName) {
  return hasFeature("QueueCustomEventRoom") && !!getCustomMgm(eventName)
}

function hasOptions(eventName) {
  return hasCustomModeByEventName(eventName)
    && getQueueClass("Event").isAllowedToSwitchCustomMode()
    && !findQueueByName(eventName, true)
}

function getOptions(eventName) {
  if (!hasOptions(eventName))
    return null
  return {
    options = [[USEROPT_QUEUE_EVENT_CUSTOM_MODE]]
    context = { eventName = eventName }
  }
}

let Event = class (BaseQueue) {
  shouldQueueCustomMode = false

  isQueueLeaved = false
  isCustomModeInTransition = false
  leaveQueueData = null

  function init() {
    this.name = getTblValue("mode", this.params, "")
    this.shouldQueueCustomMode = getShouldEventQueueCustomMode(this.name)

    this.params.clusters <- clone (this.params?.clusters ?? [])
  }

  function addQueueByParams(qParams) {
    if ("mrank" in qParams)
      this.params.mrank <- qParams.mrank

    let cluster = qParams?.cluster
    if (cluster != null && !isInArray(cluster, this.params.clusters))
      this.params.clusters.append(cluster)

    this.addQueueByUid(qParams?.queueId, this.getQueueData(qParams))
  }

  function removeQueueByParams(leaveData) {
    let queueUid = getTblValue("queueId", leaveData)
    if (queueUid == null || (queueUid in this.queueUidsList && this.queueUidsList.len() == 1)) { 
      this.clearAllQueues()
      return true
    }

    if (!(queueUid in this.queueUidsList))
      return false

    this.removeQueueByUid(queueUid)
    return true
  }

  function clearAllQueues() {
    this.params.clusters.clear()
    base.clearAllQueues()
  }

  static function getCustomMgm(eventName) {
    return getCustomMgm(eventName)
  }

  static function hasOptions(eventName) {
    return hasOptions(eventName)
  }

  static function getOptions(eventName) {
    return getOptions(eventName)
  }

  function join(successCallback, errorCallback) {
    log("enqueue into event session")
    debugTableData(this.params)
    this._joinQueueImpl(this.getQueryParams(true), successCallback, errorCallback)
  }

  function _joinQueueImpl(queryParams, successCallback, errorCallback, needShowError = true) {
    enqueueInSession(
      queryParams,
      function(response) {
        if (checkMatchingError(response, needShowError)) {
          if (this && this.shouldQueueCustomMode)
            this.switchCustomMode(this.shouldQueueCustomMode, true)
          successCallback(response)
        }
        else
          errorCallback(response)
      }.bindenv(this)
    )
  }

  function leave(successCallback, errorCallback, needShowError = false) {
    if (this.isCustomModeInTransition) {
      this.leaveQueueData = {
        successCallback = successCallback
        errorCallback = errorCallback
        needShowError = needShowError
      }
      return
    }
    requestLeaveQueue(this.getQueryParams(false), successCallback, errorCallback, needShowError)
  }

  static function leaveAll(successCallback, errorCallback, needShowError = false) {
    requestLeaveQueue({}, successCallback, errorCallback, needShowError)
  }

  getCurRank = @(event) g_squad_manager.isInSquad()
    ? getRecentSquadMrank()
    : getPlayerCurUnit().getEconomicRank(events.getEDiffByEvent(event))

  getExcludedGmsTags = @(event) {
    [NIGHT_GAME_MODE_TAG_PREFIX] = hasNightGameModes(event)
      && !get_gui_option_in_mode(USEROPT_CAN_QUEUE_TO_NIGHT_BATLLES, OPTIONS_MODE_GAMEPLAY, false),

    [SMALL_TEAMS_GAME_MODE_TAG_PREFIX] = hasSmallTeamsGameModes(event)
      && (!get_gui_option_in_mode(USEROPT_CAN_QUEUE_TO_SMALL_TEAMS_BATTLES, OPTIONS_MODE_GAMEPLAY, false)
      || this.getCurRank(event) < event.minMRankForSmallTeamsBattles)
  }.filter(@(v) v)
   .keys()

  function getQueryParams(isForJoining, customMgm = null) {
    let qp = {}
    let event = events.getEvent(this.name)
    let eventName = getEventEconomicName(event)
    let excludedTags = this.getExcludedGmsTags(event)
    let gameModesList = (event?.forceBatchRequest ?? false) ? getGameModeIdsByEconomicName(eventName)
      : excludedTags.len() > 0 ? getGameModeIdsByEconomicNameWithoutTags(eventName, excludedTags)
      : []

    if (!crossplayModule.isCrossPlayEnabled()) {
      qp.mode <- this.name
    }
    else {
      if (gameModesList.len() > 0)
        qp.game_modes_list <- gameModesList
      else if (customMgm)
        qp.game_mode_id <- customMgm.gameModeId
      else
        qp.mode <- this.name
    }

    if (!isForJoining)
      return qp

    qp.team <- this.getTeamCode()

    qp.clusters <- this.params.clusters

    let prefParams =  mapPreferencesParams.getParams(event)
    let members = this.params?.members
    let needAddJwtProfile = queueProfileJwt.get() != null
      && (members == null || members.findvalue(@(m) (m?.queueProfileJwt ?? "") == "") == null)
    qp.players <- {
      [userIdStr.get()] = {
        country = getQueueCountry(this)
        slots = getQueueSlots(this)
        dislikedMissions = prefParams.dislikedMissions
        bannedMissions = prefParams.bannedMissions
        fakeName = !get_option_in_mode(USEROPT_DISPLAY_MY_REAL_NICK, OPTIONS_MODE_GAMEPLAY).value
        hideClan = !get_option_in_mode(USEROPT_DISPLAY_MY_REAL_CLAN, OPTIONS_MODE_GAMEPLAY).value
      }
    }
    if (needAddJwtProfile)
      qp.players[userIdStr.get()].profileJwt <- queueProfileJwt.get()

    if (members)
      foreach (uid, m in members) {
        qp.players[uid] <- {
          country = ("country" in m) ? m.country : getQueueCountry(this)
          dislikedMissions = m?.dislikedMissions ?? []
          bannedMissions = m?.bannedMissions ?? []
          fakeName = m?.fakeName ?? false
          hideClan = m?.hideClan ?? false
        }
        if ("slots" in m)
          qp.players[uid].slots <- m.slots
        if (needAddJwtProfile)
          qp.players[uid].profileJwt <- m.queueProfileJwt
      }
    qp.jip <- get_option_in_mode(USEROPT_QUEUE_JIP, OPTIONS_MODE_GAMEPLAY).value
    qp.auto_squad <- get_option_in_mode(USEROPT_AUTO_SQUAD, OPTIONS_MODE_GAMEPLAY).value

    if (this.params)
      foreach (key in ["team", "roomId", "gameQueueId"])
        if (key in this.params)
          qp[key] <- this.params[key]

    return qp
  }

  function getQueueData(qParams) {
    return {
      gameModeId = getTblValue("gameModeId", qParams, -1)
    }
  }

  function getBattleName() {
    let event = events.getEvent(this.name)
    if (!event)
      return ""

    return events.getEventNameText(event)
  }

  function hasCustomMode() {
    return hasCustomModeByEventName(this.name)
  }

  function isCustomModeQUeued() {
    let customMgm = getCustomMgm(this.name)
    if (!customMgm)
      return false
    return !!u.search(this.queueUidsList, @(q) q.gameModeId == customMgm.gameModeId)
  }

  function isCustomModeSwitchedOn() {
    return this.shouldQueueCustomMode
  }

  function switchCustomMode(shouldQueue, needForceRequest = false) {
    if (!this.isAllowedToSwitchCustomMode()
      || (!needForceRequest && shouldQueue == this.shouldQueueCustomMode))
      return

    this.shouldQueueCustomMode = shouldQueue
    setShouldEventQueueCustomMode(this.name, this.shouldQueueCustomMode)

    if (this.isCustomModeInTransition)
      return

    let queue = this
    let cb = function(_res) {
      queue.isCustomModeInTransition = false
      queue.afterCustomModeQueueChanged(shouldQueue)
    }
    this.isCustomModeInTransition = true
    if (this.shouldQueueCustomMode)
      this._joinQueueImpl(this.getQueryParams(true, getCustomMgm(this.name)), cb, cb, false)
    else
      requestLeaveQueue(this.getQueryParams(false, getCustomMgm(this.name)), cb, cb, false)
  }

  function afterCustomModeQueueChanged(wasShouldQueue) {
    if (this.leaveQueueData) {
      this.leave(this.leaveQueueData.successCallback, this.leaveQueueData.errorCallback, this.leaveQueueData.needShowError)
      return
    }

    if (wasShouldQueue != this.shouldQueueCustomMode)
      this.switchCustomMode(this.shouldQueueCustomMode, true)
  }

  hasActualQueueData = @() !needActualizeQueueData.get()
  function actualizeData() {
    let queue = this
    actualizeQueueData(function(res) {
      if (queue.state != queueStates.ACTUALIZE)
        return
      if (res == EASTE_ERROR_DENIED_DUE_TO_AAS_LIMITS) {
        leaveAllQueuesSilent()
        markToShowMultiplayerLimitByAasMsg()
        return
      }
      joinQueueImpl(queue)
    })
  }
}

registerQueueClass("Event", Event)
