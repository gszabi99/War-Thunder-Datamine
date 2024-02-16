from "%scripts/dagui_library.nut" import *
from "%scripts/queue/queueConsts.nut" import queueStates

let u = require("%sqStdLibs/helpers/u.nut")
let mapPreferencesParams = require("%scripts/missions/mapPreferencesParams.nut")
let { needActualizeQueueData, queueProfileJwt, actualizeQueueData } = require("%scripts/queue/queueBattleData.nut")
let { enqueueInSession } = require("%scripts/matching/serviceNotifications/match.nut")
let { matchingApiFunc } = require("%scripts/matching/api.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_QUEUE_EVENT_CUSTOM_MODE, USEROPT_QUEUE_JIP,
  USEROPT_DISPLAY_MY_REAL_NICK, USEROPT_AUTO_SQUAD, USEROPT_CAN_QUEUE_TO_NIGHT_BATLLES
} = require("%scripts/options/optionsExtNames.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { hasNightGameModes, getEventEconomicName } = require("%scripts/events/eventInfo.nut")
let { getGameModeIdsByEconomicNameWithoutNight, getGameModeIdsByEconomicName
} = require("%scripts/matching/matchingGameModes.nut")

::queue_classes.Event <- class (::queue_classes.Base) {
  shouldQueueCustomMode = false

  isQueueLeaved = false
  isCustomModeInTransition = false
  leaveQueueData = null

  function init() {
    this.name = getTblValue("mode", this.params, "")
    this.shouldQueueCustomMode = this.getShouldQueueCustomMode(this.name)

    this.params.clusters <- clone (this.params?.clusters ?? [])
  }

  function addQueueByParams(qParams) {
    if ("mrank" in qParams)
      this.params.mrank <- qParams.mrank

    if (!("cluster" in qParams))
      return false

    let cluster = qParams.cluster
    local isClusterAdded = false
    if (!isInArray(cluster, this.params.clusters)) {
      this.params.clusters.append(cluster)
      isClusterAdded = true
    }

    this.addQueueByUid(qParams?.queueId, this.getQueueData(qParams))
    return isClusterAdded
  }

  function removeQueueByParams(leaveData) {
    let queueUid = getTblValue("queueId", leaveData)
    if (queueUid == null || (queueUid in this.queueUidsList && this.queueUidsList.len() == 1)) { //leave all queues
      this.clearAllQueues()
      return true
    }

    if (!(queueUid in this.queueUidsList))
      return false

    this.removeQueueByUid(queueUid)
    return true
  }

  function removeQueueByUid(queueUid) {
    let cluster = this.queueUidsList[queueUid].cluster
    if (this.queueUidsList.filter(@(q) q.cluster == cluster).len() <= 1) {
      let idx = this.params.clusters.indexof(cluster)
      if (idx != null)
        this.params.clusters.remove(idx)
    }
    base.removeQueueByUid(queueUid)
  }

  function clearAllQueues() {
    this.params.clusters.clear()
    base.clearAllQueues()
  }

  static function getCustomModeSaveId(eventName) { return $"queue/customEvent/{eventName}" }
  static function getShouldQueueCustomMode(eventName) {
    return loadLocalAccountSettings(::queue_classes.Event.getCustomModeSaveId(eventName), false)
  }
  static function setShouldQueueCustomMode(eventName, shouldSave) {
    return saveLocalAccountSettings(::queue_classes.Event.getCustomModeSaveId(eventName), shouldSave)
  }

  static function getCustomMgm(eventName) {
    return ::events.getCustomGameMode(::events.getEvent(eventName))
  }

  static function hasCustomModeByEventName(eventName) {
    return hasFeature("QueueCustomEventRoom") && !!::queue_classes.Event.getCustomMgm(eventName)
  }

  static function hasOptions(eventName) {
    return ::queue_classes.Event.hasCustomModeByEventName(eventName)
      && ::queue_classes.Event.isAllowedToSwitchCustomMode()
      && !::queues.findQueueByName(eventName, true)
  }

  static function getOptions(eventName) {
    if (!::queue_classes.Event.hasOptions(eventName))
      return null
    return {
      options = [[USEROPT_QUEUE_EVENT_CUSTOM_MODE]]
      context = { eventName = eventName }
    }
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
        if (::checkMatchingError(response, needShowError)) {
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
    this._leaveQueueImpl(this.getQueryParams(false), successCallback, errorCallback, needShowError)
  }

  static function leaveAll(successCallback, errorCallback, needShowError = false) {
    ::queue_classes.Event._leaveQueueImpl({}, successCallback, errorCallback, needShowError)
  }

  static function _leaveQueueImpl(queryParams, successCallback, errorCallback, needShowError = false) {
    matchingApiFunc(
      "match.leave_queue"
      function(response) {
        if (::checkMatchingError(response, needShowError))
          successCallback(response)
        else
          errorCallback(response)
      }
      queryParams
    )
  }

  function getQueryParams(isForJoining, customMgm = null) {
    let qp = {}
    let event = ::events.getEvent(this.name)
    let eventName = getEventEconomicName(event)
    let gameModesList = (event?.forceBatchRequest ?? false) ? getGameModeIdsByEconomicName(eventName)
      : hasNightGameModes(event)
          && !::get_gui_option_in_mode(USEROPT_CAN_QUEUE_TO_NIGHT_BATLLES, OPTIONS_MODE_GAMEPLAY, false)
        ? getGameModeIdsByEconomicNameWithoutNight(eventName)
      : []
    if (gameModesList.len() > 0)
      qp.game_modes_list <- gameModesList
    else if (customMgm)
      qp.game_mode_id <- customMgm.gameModeId
    else
      qp.mode <- this.name

    if (!isForJoining)
      return qp

    qp.team <- this.getTeamCode()

    qp.clusters <- this.params.clusters

    let prefParams =  mapPreferencesParams.getParams(event)
    let members = this.params?.members
    let needAddJwtProfile = queueProfileJwt.value != null
      && (members == null || members.findvalue(@(m) (m?.queueProfileJwt ?? "") == "") == null)
    qp.players <- {
      [userIdStr.value] = {
        country = ::queues.getQueueCountry(this)  //FIX ME: move it out of manager
        slots = ::queues.getQueueSlots(this)
        dislikedMissions = prefParams.dislikedMissions
        bannedMissions = prefParams.bannedMissions
        fakeName = !::get_option_in_mode(USEROPT_DISPLAY_MY_REAL_NICK, OPTIONS_MODE_GAMEPLAY).value
      }
    }
    if (needAddJwtProfile)
      qp.players[userIdStr.value].profileJwt <- queueProfileJwt.value

    if (members)
      foreach (uid, m in members) {
        qp.players[uid] <- {
          country = ("country" in m) ? m.country : ::queues.getQueueCountry(this)
          dislikedMissions = m?.dislikedMissions ?? []
          bannedMissions = m?.bannedMissions ?? []
          fakeName = m?.fakeName ?? false
        }
        if ("slots" in m)
          qp.players[uid].slots <- m.slots
        if (needAddJwtProfile)
          qp.players[uid].profileJwt <- m.queueProfileJwt
      }
    qp.jip <- ::get_option_in_mode(USEROPT_QUEUE_JIP, OPTIONS_MODE_GAMEPLAY).value
    qp.auto_squad <- ::get_option_in_mode(USEROPT_AUTO_SQUAD, OPTIONS_MODE_GAMEPLAY).value

    if (this.params)
      foreach (key in ["team", "roomId", "gameQueueId"])
        if (key in this.params)
          qp[key] <- this.params[key]

    return qp
  }

  function getQueueData(qParams) {
    return {
      cluster = qParams.cluster
      gameModeId = getTblValue("gameModeId", qParams, -1)
    }
  }

  function getBattleName() {
    let event = ::events.getEvent(this.name)
    if (!event)
      return ""

    return ::events.getEventNameText(event)
  }

  function hasCustomMode() {
    return this.hasCustomModeByEventName(this.name)
  }

  function isCustomModeQUeued() {
    let customMgm = this.getCustomMgm(this.name)
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
    this.setShouldQueueCustomMode(this.name, this.shouldQueueCustomMode)

    if (this.isCustomModeInTransition)
      return

    let queue = this
    let cb = function(_res) {
      queue.isCustomModeInTransition = false
      queue.afterCustomModeQueueChanged(shouldQueue)
    }
    this.isCustomModeInTransition = true
    if (this.shouldQueueCustomMode)
      this._joinQueueImpl(this.getQueryParams(true, this.getCustomMgm(this.name)), cb, cb, false)
    else
      this._leaveQueueImpl(this.getQueryParams(false, this.getCustomMgm(this.name)), cb, cb, false)
  }

  function afterCustomModeQueueChanged(wasShouldQueue) {
    if (this.leaveQueueData) {
      this.leave(this.leaveQueueData.successCallback, this.leaveQueueData.errorCallback, this.leaveQueueData.needShowError)
      return
    }

    if (wasShouldQueue != this.shouldQueueCustomMode)
      this.switchCustomMode(this.shouldQueueCustomMode, true)
  }

  hasActualQueueData = @() !needActualizeQueueData.value
  function actualizeData() {
    let queue = this
    actualizeQueueData(function(_jwtData) {
      if (queue.state != queueStates.ACTUALIZE)
        return
      ::queues.joinQueueImpl(queue)
    })
  }
}