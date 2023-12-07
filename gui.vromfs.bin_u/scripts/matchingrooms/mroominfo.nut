from "%scripts/dagui_library.nut" import *
let { get_time_msec } = require("dagor.time")
let { SERVER_ERROR_ROOM_NOT_FOUND } = require("matching.errors")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { matchingApiFunc } = require("%scripts/matching/api.nut")

const MROOM_INFO_UPDATE_DELAY    = 5000
const MROOM_INFO_REQUEST_TIMEOUT = 15000
const MROOM_INFO_OUTDATE_TIME    = 600000

let class MRoomInfo {
  roomId = -1
  lastUpdateTime = -MROOM_INFO_OUTDATE_TIME
  lastRequestTime = -MROOM_INFO_OUTDATE_TIME
  lastAnswerTime = -MROOM_INFO_OUTDATE_TIME

  roomData = null
  isRoomDestroyed = false

  constructor(v_roomId) {
    this.roomId = v_roomId
  }

  function isValid() {
    return this.lastRequestTime < 0 || this.isRequestInProgress() || !this.isOutdated()
  }

  function isOutdated() {
    return this.lastUpdateTime + MROOM_INFO_OUTDATE_TIME < get_time_msec()
  }

  function isRequestInProgress() {
    return this.lastAnswerTime < this.lastRequestTime
        && this.lastRequestTime + MROOM_INFO_REQUEST_TIMEOUT > get_time_msec()
  }

  function canRequest() {
    return !this.isRoomDestroyed && !this.isRequestInProgress()
        && this.lastAnswerTime + MROOM_INFO_UPDATE_DELAY < get_time_msec()
  }

  function checkRefresh() {
    if (!this.canRequest())
      return

    this.lastRequestTime = get_time_msec()
    let cb = Callback(this.onRefreshCb, this)
    matchingApiFunc("mrooms.get_room",
      function(p) { cb(p) },
      { roomId = this.roomId }
    )
  }

  function onRefreshCb(params) {
    this.lastAnswerTime = get_time_msec()

    if (params.error == SERVER_ERROR_ROOM_NOT_FOUND) {
      this.lastUpdateTime = this.lastAnswerTime
      this.isRoomDestroyed = true
      this.roomData = null
      broadcastEvent("MRoomInfoUpdated", { roomId = this.roomId })
      return
    }

    if (!::checkMatchingError(params, false))
      return

    this.lastUpdateTime = this.lastAnswerTime
    this.roomData = params
    this.roomData.roomId <- this.roomId
    broadcastEvent("MRoomInfoUpdated", { roomId = this.roomId })
  }

  function getFullRoomData() {
    this.checkRefresh()
    if (this.isOutdated())
      this.roomData = null
    return this.roomData
  }
}

return MRoomInfo
