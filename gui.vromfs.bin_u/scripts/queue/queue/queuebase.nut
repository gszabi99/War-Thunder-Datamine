//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let time = require("%scripts/time.nut")
let { get_time_msec } = require("dagor.time")
let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")


::queue_classes.Base <- class {
  id = 0
  name = ""
  typeBit = QUEUE_TYPE_BIT.UNKNOWN //FIX ME: should to rename this also
  queueType = ::g_queue_type.UNKNOWN
  state = queueStates.NOT_IN_QUEUE

  params = null //params = { clusters = array of strings, mode = string, country = string, team = int}
                //params.members = { [uid] = { country, slots } }
  activateTime = -1
  queueUidsList = null // { <queueUid> = <getQueueData> }
  queueStats = null //created on first stats income. We dont know stats version before
  selfActivated = false

  constructor(queueId, v_queueType, v_params) {
    this.id = queueId
    this.queueType = v_queueType
    this.params = v_params || {}

    this.typeBit = this.queueType.bit
    this.queueUidsList = {}
    this.selfActivated = getTblValue("queueSelfActivated", this.params, false)

    this.init()
    this.addQueueByParams(this.params)
  }

  function init() {}

  // return <is somethind in queue parameters changed>
  function addQueueByParams(_qParams) {
    return false
  }

  //return true if queue changed
  function removeQueueByParams(_leaveData) {
    return false
  }

  function addQueueByUid(queueUid, queueParms) {
    if (queueUid != null)
      this.queueUidsList[queueUid] <- queueParms
  }

  function removeQueueByUid(queueUid) {
    delete this.queueUidsList[queueUid]
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
  //is already exist queue with custom mode.
  //custom mode can be switched off, but squad leader can set to queue with custom mode.
  function isCustomModeQUeued() { return false }
  //when custom mode switched on, it will be queued automatically
  function isCustomModeSwitchedOn() { return false }
  function switchCustomMode(_shouldQueue) {}
  static function isAllowedToSwitchCustomMode() { return !::g_squad_manager.isInSquad() || ::g_squad_manager.isSquadLeader() }
  hasActualQueueData = @() true
  actualizeData = @() null
}