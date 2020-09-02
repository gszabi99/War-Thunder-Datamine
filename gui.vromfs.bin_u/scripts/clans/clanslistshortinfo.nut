const REQUEST_TIME_OUT_MSEC  = 20000    //20sec
const VALID_INFO_TIME_OUT_MSEC = 1800000 //30min

local cachedList = {}

local canRequestByTime = @(clanData) !(clanData?.isInUpdate ?? false)
  && (::dagor.getCurTime() - (clanData?.lastRequestTimeMsec ?? 0)) >= REQUEST_TIME_OUT_MSEC

local hasValidInfo = @(clanData) ("info" in clanData)
  && (::dagor.getCurTime() - clanData.lastUpdateTimeMsec < VALID_INFO_TIME_OUT_MSEC)

local function needRequest(clanId) {
  local clanData = cachedList?[clanId] ?? {}
  return !hasValidInfo(clanData) && canRequestByTime(clanData)
}

local function prepareListToRequest(clanIdsArray) {
  local blk = ::DataBlock()
  blk.addBlock("body")
  foreach (clanId in clanIdsArray) {
    local clanIdStr = clanId.tostring()
    if (clanIdStr == "" || !needRequest(clanIdStr))
      continue

    blk.body.addStr("clanId", clanIdStr)
    cachedList[clanIdStr] <- (cachedList?[clanIdStr] ?? {}).__update({
      isInUpdate = true
      lastRequestTimeMsec = ::dagor.getCurTime()
    })
  }
  return blk
}

local function updateClansInfoList(data) {
  local clansInfoList = {}
  foreach (info in data) {
    local id = info?._id
    if (id == null)
      continue
    cachedList[id] <- {
      info = ::buildTableFromBlk(info)
      lastUpdateTimeMsec = ::dagor.getCurTime()
    }
    clansInfoList[id] <- cachedList[id].info
  }
  return clansInfoList
}

local function requestListCb(data) {
  local clansInfoList = updateClansInfoList(data)
  ::broadcastEvent("UpdateClansInfoList", { clansInfoList = clansInfoList})
}

local function requestError(requestBlk) {
  foreach (id in (requestBlk.body % "clanId"))
    cachedList[id].isInUpdate = false
}

local function requestList(clanIdsArray) {
  local requestBlk = prepareListToRequest(clanIdsArray)
  if (!("clanId" in requestBlk.body))
    return

  local errorCb = @(taskResult) requestError(requestBlk)
  ::g_tasker.charRequestBlk("cln_clans_list_get_short_info", requestBlk, null, requestListCb, errorCb)
  return
}

local function getClansInfoByClanIds(clanIdsArray) {
  requestList(clanIdsArray)
  local res = {}
  foreach (clanId in clanIdsArray) {
    local info = cachedList?[clanId.tostring()].info
    if (info != null)
      res[clanId] <- info
  }
  return res
}

return {
  getClansInfoByClanIds = getClansInfoByClanIds
}
