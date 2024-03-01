from "%scripts/dagui_library.nut" import *

let { get_time_msec } = require("dagor.time")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock  = require("DataBlock")
let { convertBlk } = require("%sqstd/datablock.nut")
let { charRequestBlk } = require("%scripts/tasker.nut")

const REQUEST_TIME_OUT_MSEC  = 20000    //20sec
const VALID_INFO_TIME_OUT_MSEC = 1800000 //30min

let cachedList = {}

let canRequestByTime = @(clanData) !(clanData?.isInUpdate ?? false)
  && (get_time_msec() - (clanData?.lastRequestTimeMsec ?? 0)) >= REQUEST_TIME_OUT_MSEC

let hasValidInfo = @(clanData) ("info" in clanData)
  && (get_time_msec() - clanData.lastUpdateTimeMsec < VALID_INFO_TIME_OUT_MSEC)

function needRequest(clanId) {
  let clanData = cachedList?[clanId] ?? {}
  return !hasValidInfo(clanData) && canRequestByTime(clanData)
}

function prepareListToRequest(clanIdsArray) {
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

function updateClansInfoList(data) {
  let clansInfoList = {}
  foreach (info in data) {
    let id = info?._id
    if (id == null)
      continue
    cachedList[id] <- {
      info = convertBlk(info)
      lastUpdateTimeMsec = get_time_msec()
    }
    clansInfoList[id] <- cachedList[id].info
  }
  return clansInfoList
}

function requestListCb(data) {
  let clansInfoList = updateClansInfoList(data)
  broadcastEvent("UpdateClansInfoList", { clansInfoList = clansInfoList })
}

function requestError(requestBlk) {
  foreach (id in (requestBlk.body % "clanId"))
    cachedList[id].isInUpdate = false
}

function requestList(clanIdsArray) {
  let requestBlk = prepareListToRequest(clanIdsArray)
  if (!("clanId" in requestBlk.body))
    return

  let errorCb = @(_taskResult) requestError(requestBlk)
  charRequestBlk("cln_clans_list_get_short_info", requestBlk, null, requestListCb, errorCb)
  return
}

function getClansInfoByClanIds(clanIdsArray) {
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
