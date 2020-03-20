local time = require("scripts/time.nut")
local QUEUE_TYPE_BIT = require("scripts/queue/queueTypeBit.nut")


class ::queue_classes.Base
{
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

  constructor(queueId, _queueType, _params)
  {
    id = queueId
    queueType = _queueType
    params = _params || {}

    typeBit = queueType.bit
    queueUidsList = {}
    selfActivated = ::getTblValue("queueSelfActivated", params, false)

    init()
    addQueueByParams(params)
  }

  function init() {}

  // return <is somethind in queue parameters changed>
  function addQueueByParams(qParams)
  {
    return false
  }

  //return true if queue changed
  function removeQueueByParams(leaveData)
  {
    return false
  }

  function addQueueByUid(queueUid, queueParms)
  {
    if (queueUid)
      queueUidsList[queueUid] <- queueParms
  }

  function removeQueueByUid(queueUid)
  {
    delete queueUidsList[queueUid]
  }

  function clearAllQueues()
  {
    queueUidsList.clear()
  }

  function isActive()
  {
    return queueUidsList.len() > 0
  }

  function getQueueData(qParams)
  {
    return {}
  }

  function getTeamCode()
  {
    return ::getTblValue("team", params, Team.Any)
  }

  function getBattleName()
  {
    return ""
  }

  function getDescription()
  {
    return "<color=@activeTextColor>" + getBattleName() + "</color>\n" +
           ::loc("options/country") + ::loc("ui/colon") + ::loc(params?.country ?? "") + "\n" +
           getQueueActiveTimeText()
  }

  function getQueueActiveTimeText()
  {
    local waitTime = getActiveTime()
    if (waitTime > 0)
    {
      local minutes = time.secondsToMinutes(waitTime).tointeger()
      local seconds = waitTime - time.minutesToSeconds(minutes)
      return ::format(::loc("yn1/wait_time"), minutes, seconds)
    }
    return ""
  }

  function getActiveTime()
  {
    if (activateTime >= 0)
      return time.millisecondsToSeconds(::dagor.getCurTime() - activateTime)

    return 0
  }

  function join(successCallback, errorCallback) {}
  function leave(successCallback, errorCallback, needShowError = false) {}
  static function leaveAll(successCallback, errorCallback, needShowError = false) {}

  function hasCustomMode() { return false }
  //is already exist queue with custom mode.
  //custom mode can be switched off, but squad leader can set to queue with custom mode.
  function isCustomModeQUeued() { return false }
  //when custom mode switched on, it will be queued automatically
  function isCustomModeSwitchedOn() { return false }
  function switchCustomMode(shouldQueue) {}
  static function isAllowedToSwitchCustomMode()
    { return !::g_squad_manager.isInSquad() || ::g_squad_manager.isSquadLeader() }
}