let avatars = require("scripts/user/avatars.nut")

/**
  client api:
      requestInfo(users, successCb = null, errorCb = null)
                  - users - array of userId's string

  server api:
      "cln_get_users_terse_info" - char action returns DataBlock: {
                                                                      uid = {
                                                                        nick="string",
                                                                        pilotId="integer"
                                                                      }
                                                                      uid {...}
                                                                    }
**/

enum userInfoEventName
{
  UPDATED = "UserInfoManagerDataUpdated"
}

::g_users_info_manager <- {
  MIN_TIME_BETWEEN_SAME_REQUESTS_MSEC = 600000
  MAX_REQUESTED_UID_NUM = 4

  usersInfo = {}
}

g_users_info_manager.requestInfo <- function requestInfo(users, successCb = null, errorCb = null)
{
  if (users.len() > MAX_REQUESTED_UID_NUM)
    return

  let fastResponse = _getResponseWidthoutRequest(users)
  if (fastResponse != null && successCb != null)
    return successCb(fastResponse)

  let usersList = ::g_string.implode(users, ";")

  let requestBlk = DataBlock()
  requestBlk.setStr("usersList", usersList)

  let fullSuccessCb = (@(users, successCb) function(response) {
    let parsedResponse = ::g_users_info_manager._convertServerResponse(response)
    ::g_users_info_manager._requestDataCommonSuccessCallback(parsedResponse)
    if (successCb != null)
      successCb(parsedResponse)
  })(users, successCb)

  ::g_tasker.charRequestBlk("cln_get_users_terse_info", requestBlk, { showErrorMessageBox = false }, fullSuccessCb, errorCb)
}

g_users_info_manager._getResponseWidthoutRequest <- function _getResponseWidthoutRequest(users)
{
  local fastResponse = {}
  let currentTime = ::dagor.getCurTime()
  foreach (uid, userId in users)
  {
    let curUserInfo = ::getTblValue(userId, usersInfo, null)
    if (curUserInfo == null ||
        currentTime - curUserInfo.updatingLastTime > MIN_TIME_BETWEEN_SAME_REQUESTS_MSEC)
    {
      fastResponse = null
      break
    }
    fastResponse[uid] <- curUserInfo
  }

  return fastResponse
}

g_users_info_manager._requestDataCommonSuccessCallback <- function _requestDataCommonSuccessCallback(response)
{
  local isUpdated = false
  foreach(uid, newUserInfo in response)
  {
    local curUserInfo = ::getTblValue(uid, usersInfo, null)
    if (curUserInfo != null)
    {
      foreach(key, value in newUserInfo)
        if (newUserInfo[key] != ::getTblValue(key, curUserInfo, null))
        {
          curUserInfo[key] <- newUserInfo[key]
          isUpdated = true
        }
    }
    else
    {
      curUserInfo = {}
      foreach(key, value in newUserInfo)
        curUserInfo[key] <- value
      isUpdated = true
    }

    curUserInfo.updatingLastTime <- ::dagor.getCurTime()
    usersInfo[uid] <- curUserInfo
  }

  if (isUpdated)
    ::broadcastEvent(userInfoEventName.UPDATED, { usersInfo = response })
}

g_users_info_manager._convertServerResponse <- function _convertServerResponse(response)
{
  let res = {}
  foreach(uid, userInfo in response)
  {
    let pilotId = ::getTblValue("pilotId", userInfo, "")
    let convertedData = {
      uid = uid
      name = ::getTblValue("nick", userInfo, "")
      pilotIcon = avatars.getIconById(pilotId)
    }

    res[uid] <- convertedData
  }

  return res
}
