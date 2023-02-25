//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { get_time_msec } = require("dagor.time")
let DataBlock  = require("DataBlock")

const REQUEST_TIME_OUT_MSEC  = 20000    //20sec
const VALID_INFO_TIME_OUT_MSEC = 1800000 //30min

let cachedList = {}

let canRequestByTime = @(clanData) !(clanData?.isInUpdate ?? false)
  && (get_time_msec() - (clanData?.lastRequestTimeMsec ?? 0)) >= REQUEST_TIME_OUT_MSEC

let hasValidInfo = @(clanData) ("info" in clanData)
  && (get_time_msec() - clanData.lastUpdateTimeMsec < VALID_INFO_TIME_OUT_MSEC)

let function needRequest(clanId) {
  let clanData = cachedList?[clanId] ?? {}
  return !hasValidInfo(clanData) && canRequestByTime(clanData)
}

let function prepareListToRequest(clanIdsArray) {
  let blk = DataBlock()
  blk.addBlock("body")
  foreach (clanId in clanIdsArray) {
    let clanIdStr = clanId.tostring()
    if (clanIdStr == "" || !needRequest(clanIdStr))
      continue

    blk.body.addStr("clanId", clanIdStr)
    cachedList[clanIdStr] <- (cachedList?[clanIdStr] ?? {}).__update({
      isInUpdate = true
      lastRequestTimeMsec = get_time_msec()
    })
  }
  return blk
}

let function updateClansInfoList(data) {
  let clansInfoList = {}
  foreach (info in data) {
    let id = info?._id
    if (id == null)
      continue
    cachedList[id] <- {
      info = ::buildTableFromBlk(info)
      lastUpdateTimeMsec = get_time_msec()
    }
    clansInfoList[id] <- cachedList[id].info
  }
  return clansInfoList
}

let function requestListCb(data) {
  let clansInfoList = updateClansInfoList(data)
  ::broadcastEvent("UpdateClansInfoList", { clansInfoList = clansInfoList })
}

let function requestError(requestBlk) {
  foreach (id in (requestBlk.body % "clanId"))
    cachedList[id].isInUpdate = false
}

let function requestList(clanIdsArray) {
  let requestBlk = prepareListToRequest(clanIdsArray)
  if (!("clanId" in requestBlk.body))
    return

  let errorCb = @(_taskResult) requestError(requestBlk)
  ::g_tasker.charRequestBlk("cln_clans_list_get_short_info", requestBlk, null, requestListCb, errorCb)
  return
}

let function getClansInfoByClanIds(clanIdsArray) {
  requestList(clanIdsArray)
  let res = {}
  foreach (clanId in clanIdsArray) {
    let info = cachedList?[clanId.tostring()].info
    if (info != null)
      res[clanId] <- info
  }
  return res
}

return {
  getClansInfoByClanIds = getClansInfoByClanIds
}
