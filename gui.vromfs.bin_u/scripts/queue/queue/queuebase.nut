from "%scripts/dagui_library.nut" import *
from "%scripts/teamsConsts.nut" import Team
from "%scripts/queue/queueConsts.nut" import queueStates
from "%scripts/queue/queueType.nut" import g_queue_type

let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let time = require("%scripts/time.nut")
let { get_time_msec } = require("dagor.time")
let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let { isQueueActive } = require("%scripts/queue/queueState.nut")

let BaseQueue = class {
  id = 0
  name = ""
  typeBit = QUEUE_TYPE_BIT.UNKNOWN 
  queueType = g_queue_type.UNKNOWN
  state = queueStates.NOT_IN_QUEUE

  params = null 
                
  activateTime = -1
  queueUidsList = null 
  queueStats = null 
  selfActivated = false

  constructor(queueId, v_queueType, v_params) {
    this.id = queueId
    this.queueType = v_queueType
    this.params = v_params ?? {}

    this.typeBit = this.queueType.bit
    this.queueUidsList = {}
    this.selfActivated = getTblValue("queueSelfActivated", this.params, false)

    this.init()
    this.addQueueByParams(this.params)
  }

  function init() {}

  function addQueueByParams(_qParams) {}

  
  function removeQueueByParams(_leaveData) {
    return false
  }

  function addQueueByUid(queueUid, queueParms) {
    if (queueUid != null)
      this.queueUidsList[queueUid] <- queueParms
  }

  function removeQueueByUid(queueUid) {
    this.queueUidsList.$rawdelete(queueUid)
  }

  function clearAllQueues() {
    this.queueUidsList.clear()
  }

  function isActive() {
    return this.queueUidsList.len() > 0
  }

  function getQueueData(_qParams) {
    return {}
  }

  function getTeamCode() {
    return getTblValue("team", this.params, Team.Any)
  }

  function getBattleName() {
    return ""
  }

  getDescription = @() "".concat(colorize("activeTextColor", this.getBattleName()), "\n",
    loc("options/country"), loc("ui/colon"), loc(this.params?.country ?? ""))

  function getActiveTime() {
    if (this.activateTime >= 0)
      return time.millisecondsToSeconds(get_time_msec() - this.activateTime)

    return 0
  }

  function join(_successCallback, _errorCallback) {}
  function leave(_successCallback, _errorCallback, _needShowError = false) {}
  static function leaveAll(_successCallback, _errorCallback, _needShowError = false) {}

  function hasCustomMode() { return false }
  
  
  function isCustomModeQUeued() { return false }
  
  function isCustomModeSwitchedOn() { return false }
  function switchCustomMode(_shouldQueue) {}
  static function isAllowedToSwitchCustomMode() { return !g_squad_manager.isInSquad() || g_squad_manager.isSquadLeader() }
  hasActualQueueData = @() true
  actualizeData = @() null

  function setState(newState) {
    this.state = newState
    this.activateTime = isQueueActive(this) ? get_time_msec() : -1
  }
}

return BaseQueue
