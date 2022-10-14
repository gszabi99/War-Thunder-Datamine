from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

const MROOM_INFO_UPDATE_DELAY    = 5000
const MROOM_INFO_REQUEST_TIMEOUT = 15000
const MROOM_INFO_OUTDATE_TIME    = 600000

::MRoomInfo <- class
{
  roomId = -1
  lastUpdateTime = -MROOM_INFO_OUTDATE_TIME
  lastRequestTime = -MROOM_INFO_OUTDATE_TIME
  lastAnswerTime = -MROOM_INFO_OUTDATE_TIME

  roomData = null
  isRoomDestroyed = false

  constructor(v_roomId)
  {
    roomId = v_roomId
  }

  function isValid()
  {
    return lastRequestTime < 0 || isRequestInProgress() || !isOutdated()
  }

  function isOutdated()
  {
    return lastUpdateTime + MROOM_INFO_OUTDATE_TIME < ::dagor.getCurTime()
  }

  function isRequestInProgress()
  {
    return lastAnswerTime < lastRequestTime
        && lastRequestTime + MROOM_INFO_REQUEST_TIMEOUT > ::dagor.getCurTime()
  }

  function canRequest()
  {
    return !isRoomDestroyed && !isRequestInProgress()
        && lastAnswerTime + MROOM_INFO_UPDATE_DELAY < ::dagor.getCurTime()
  }

  function checkRefresh()
  {
    if (!canRequest())
      return

    lastRequestTime = ::dagor.getCurTime()
    let cb = Callback(onRefreshCb, this)
    ::matching_api_func("mrooms.get_room",
      function(p) { cb(p) },
      { roomId = roomId }
    )
  }

  function onRefreshCb(params)
  {
    lastAnswerTime = ::dagor.getCurTime()

    if (params.error == SERVER_ERROR_ROOM_NOT_FOUND)
    {
      lastUpdateTime = lastAnswerTime
      isRoomDestroyed = true
      roomData = null
      ::broadcastEvent("MRoomInfoUpdated", { roomId = roomId })
      return
    }

    if (!::checkMatchingError(params, false))
      return

    lastUpdateTime = lastAnswerTime
    roomData = params
    roomData.roomId <- roomId
    ::broadcastEvent("MRoomInfoUpdated", { roomId = roomId })
  }

  function getFullRoomData()
  {
    checkRefresh()
    if (isOutdated())
      roomData = null
    return roomData
  }
}
