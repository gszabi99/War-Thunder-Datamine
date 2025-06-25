from "%scripts/dagui_library.nut" import *
let { get_time_msec } = require("dagor.time")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock = require("DataBlock")
let { setTimeout, clearTimer } = require("dagor.workcycle")
let { charRequestBlk } = require("%scripts/tasker.nut")
let { isDataBlock, convertBlk } = require("%sqstd/datablock.nut")





















enum userInfoEventName {
  UPDATED = "UserInfoManagerDataUpdated"
}

let MIN_TIME_BETWEEN_SAME_REQUESTS_MSEC = 300000
let MAX_REQUESTED_UID_NUM = 100
let usersInfo = {}
let usersForRequest = {}
local haveRequest = false

function isUserNeedUpdateInfo(userInfo, curTime = -1) {
  if (userInfo == null)
    return true
  curTime = curTime == -1 ? get_time_msec() : curTime
  return curTime - userInfo.updatingLastTime > MIN_TIME_BETWEEN_SAME_REQUESTS_MSEC
}

function _splitUsersByCacheStatus(users) {
  let upToDateUsers = {}
  let outdatedUsersIds = []
  let currentTime = get_time_msec()

  foreach (userId in users) {
    let curUserInfo = usersInfo?[userId]
    if (isUserNeedUpdateInfo(curUserInfo, currentTime))
      outdatedUsersIds.append(userId)
    else
      upToDateUsers[userId] <- curUserInfo
  }
  return { upToDateUsers, outdatedUsersIds }
}

function _requestDataCommonSuccessCallback(response) {
  local isUpdated = false
  foreach (uid, newUserInfo in response) {
    local curUserInfo = usersInfo?[uid]
    if (curUserInfo != null) {
      foreach (key, _value in newUserInfo)
        if (newUserInfo[key] != curUserInfo?[key]) {
          curUserInfo[key] <- newUserInfo[key]
          isUpdated = true
        }
    }
    else {
      curUserInfo = {}
      foreach (key, value in newUserInfo)
        curUserInfo[key] <- value
      isUpdated = true
    }

    curUserInfo.updatingLastTime <- get_time_msec()
    usersInfo[uid] <- curUserInfo
  }

  if (isUpdated)
    broadcastEvent(userInfoEventName.UPDATED, { usersInfo = response })
}

function _convertServerResponse(response) {
  let res = {}
  foreach (uid, userInfo in response) {
    if (userInfo?.failed)
      continue
    let convertedData = {
      uid = uid
      name = userInfo?.nick ?? ""
      pilotIcon = userInfo?.pilotIcon ?? ""
      pilotId = userInfo?.pilotId ?? ""
      title = userInfo?.title ?? ""
      clanTag =  userInfo?.clanTag ?? ""
      clanName =  userInfo?.clanName ?? ""
      shcType = userInfo?.shcType ?? ""
      background = userInfo?.background ?? ""
      frame = userInfo?.frame ?? ""
      showcase = isDataBlock(userInfo?.showcase)
        ? convertBlk(userInfo.showcase)
        : {}
    }
    res[uid] <- convertedData
  }

  return res
}

function clearRequestArray(users) {
  foreach (uid, _ in users)
    if (uid in usersForRequest)
      usersForRequest.$rawdelete(uid)
}

function getUserListRequest(users = {}) {
  let reqList = []

  foreach (uid, _ in users) {
    reqList.append(uid)

    if (reqList.len() == MAX_REQUESTED_UID_NUM)
      return reqList
  }
  return reqList
}

function requestUsersInfo(users, successCb = null, errorCb = null) {
  if (haveRequest || users.len() == 0)
    return

  let { upToDateUsers, outdatedUsersIds } = _splitUsersByCacheStatus(users)

  if (outdatedUsersIds.len() == 0)
    return successCb?(upToDateUsers)

  let usersList = ";".join(outdatedUsersIds, true)
  let requestBlk = DataBlock()
  requestBlk.setStr("usersList", usersList)

  function fullSuccessCb(response) {
    let parsedResponse = _convertServerResponse(response)
    _requestDataCommonSuccessCallback(parsedResponse)
    clearRequestArray(parsedResponse)
    if (upToDateUsers.len() > 0)
      parsedResponse.__update(upToDateUsers)

    if (successCb != null)
      successCb(parsedResponse)
    haveRequest = false
  }

  function fullErrorCb(response) {
    errorCb?(response)
    haveRequest = false
  }

  haveRequest = true
  charRequestBlk("cln_get_users_terse_info", requestBlk, { showErrorMessageBox = false }, fullSuccessCb, fullErrorCb)
}

function updateUsersInfo() {
  clearTimer(updateUsersInfo)
  let updateUsersInfo_ = callee()
  function errorCb(_) {
    clearTimer(updateUsersInfo_)
    setTimeout(MIN_TIME_BETWEEN_SAME_REQUESTS_MSEC, updateUsersInfo_)
  }

  let userListForRequestgetUser = getUserListRequest(usersForRequest)

  if (userListForRequestgetUser.len() == 0)
    return

  requestUsersInfo(userListForRequestgetUser, null, errorCb)
}

function requestUserInfoData(userId) {
  clearTimer(updateUsersInfo)

  let cachedInfo = usersInfo?[userId]
  if ((userId not in usersForRequest) && isUserNeedUpdateInfo(cachedInfo))
    usersForRequest[userId] <- true

  if (usersForRequest.len() == 0)
    return

  setTimeout(0.3, updateUsersInfo)
}

function forceRequestUserInfoData(userId) {
  let userInfo = usersInfo?[userId]
  if (userInfo != null)
    userInfo.updatingLastTime -= MIN_TIME_BETWEEN_SAME_REQUESTS_MSEC

  requestUserInfoData(userId)
}

function getUserInfo(uid) {
  let userInfo = usersInfo?[uid]
  if (isUserNeedUpdateInfo(userInfo))
    requestUserInfoData(uid)

  return userInfo
}

function setUserInfoParams(uid, params) {
  let userInfo = usersInfo?[uid]
  if (userInfo == null)
    return

  userInfo.__update(params)
  broadcastEvent(userInfoEventName.UPDATED, { usersInfo = { [uid] = userInfo } })
}

return {
  requestUserInfoData
  forceRequestUserInfoData
  requestUsersInfo
  getUserInfo
  setUserInfoParams
}