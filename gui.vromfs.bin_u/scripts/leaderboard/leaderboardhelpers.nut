from "%scripts/dagui_library.nut" import *
from "%scripts/leaderboard/leaderboardConsts.nut" import LEADERBOARD_VALUE_TOTAL, LEADERBOARD_VALUE_INHISTORY

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { requestLeaderboardData, convertLeaderboardData } = require("%scripts/leaderboard/requestLeaderboardData.nut")
let { userIdInt64 } = require("%scripts/user/profileStates.nut")

local selfRowData       = null
local leaderboardData   = null
local lastRequestData   = null
local lastRequestSRData = null //last self row request
local canRequestLb      = true

let defaultRequest = {
  lbType = ETTI_VALUE_INHISORY
  lbField = "each_player_victories"
  rowsInPage = 1
  pos = 0
  lbMode = ""
  platformFilter = ""
}

function checkLbRowVisibility(row, params = {}) {
  // check ownProfileOnly
  if (getTblValue("ownProfileOnly", row, false) && !getTblValue("isOwnStats", params, false))
    return false

  // check reqFeature
  if (!row.isVisibleByFeature())
    return false

  // check modesMask
  let lbMode = getTblValue("lbMode", params)
  if (!row.isVisibleByLbModeName(lbMode))
    return false

  return true
}

function compareRequests(req1, req2) {
  foreach (name, _field in defaultRequest) {
    if ((name in req1) != (name in req2))
      return false
    if (!(name in req1)) //no name in both req
      continue
    if (req1[name] != req2[name])
      return false
  }
  return true
}

function reset() {
  selfRowData       = null
  leaderboardData   = null
  lastRequestData   = null
  lastRequestSRData = null
  canRequestLb      = true
}

function validateRequestData(requestData) {
  foreach (name, field in defaultRequest)
    if (!(name in requestData))
      requestData[name] <- field
  return requestData
}

function handleLbRequest(requestData, lbData) {
  let { callBack = null, handler = null } = requestData
  if (callBack == null)
    return

  if (handler != null)
    callBack.call(handler, lbData)
  else
    callBack(lbData)
}

function loadLeaderboard(requestData) {
  lastRequestData = requestData
  if (!canRequestLb)
    return

  canRequestLb = false
  let { pos, lbField, lbType, lbMode, platformFilter, rowsInPage } = requestData
  let valueType = lbType == ETTI_VALUE_INHISORY ? LEADERBOARD_VALUE_INHISTORY : LEADERBOARD_VALUE_TOTAL
  let dataParams = {
    gameMode = lbMode
    start    = pos
    count    = rowsInPage
    category = lbField
    platformFilter
    valueType
  }
  let headers = {
    appId = 0 //Leaderboards for War Thunder use appid 0 since char does not fully support appid.
  }

  let self = callee()
  requestLeaderboardData(dataParams, headers, function(response) {
    leaderboardData = convertLeaderboardData(response, false, valueType)
    canRequestLb = true
    if (!compareRequests(lastRequestData, requestData))
      self(lastRequestData)
    else
      handleLbRequest(requestData, leaderboardData)
  })
}

function loadSeflRow(requestData) {
  lastRequestSRData = requestData
  if (!canRequestLb)
    return
  canRequestLb = false
  let { lbField, lbType, lbMode, platformFilter, userId = null } = requestData
  let valueType = lbType == ETTI_VALUE_INHISORY ? LEADERBOARD_VALUE_INHISTORY : LEADERBOARD_VALUE_TOTAL
  let dataParams = {
    gameMode = lbMode
    count    = 0
    category = lbField
    platformFilter
    valueType
  }
  let headers = {
    appId = 0 //Leaderboards for War Thunder use appid 0 since char does not fully support appid.
    userId = userId ?? userIdInt64.get()
  }

  let self = callee()
  requestLeaderboardData(dataParams, headers, function(response) {
    selfRowData = convertLeaderboardData(response, false, valueType).rows
    canRequestLb = true
    if (!compareRequests(lastRequestSRData, requestData))
      self(lastRequestSRData)
    else
      handleLbRequest(requestData, selfRowData)
  })
}

/**
 * Function requests leaderboards asynchronously and puts result
 * as argument to callback function
 */
function requestLeaderboard(requestData, callback, context = null) {
  requestData = validateRequestData(requestData)

  //trigging callback if data is lready here
  if (leaderboardData && compareRequests(lastRequestData, requestData)) {
    if (context)
      callback.call(context, leaderboardData)
    else
      callback(leaderboardData)
    return
  }

  requestData.callBack <- Callback(callback, context)
  loadLeaderboard(requestData)
}

/**
 * Function requests self leaderboard row asynchronously and puts result
 * as argument to callback function
 */
function requestSelfRow(requestData, callback, context = null) {
  requestData = validateRequestData(requestData)
  if (lastRequestSRData)
    lastRequestSRData.pos <- requestData.pos

  //trigging callback if data is lready here
  if (selfRowData && compareRequests(lastRequestSRData, requestData)) {
    if (context)
      callback.call(context, selfRowData)
    else
      callback(selfRowData)
    return
  }

  requestData.callBack <- Callback(callback, context)
  loadSeflRow(requestData)
}

let leaderboardModel = {
  reset
  requestLeaderboard
  requestSelfRow
  checkLbRowVisibility
}


/**
 * Comapares two lb row with the same fields and returns
 * a table of diff for each field.
 * Result table containes only fields with different values
 * The first argument is base of comarsion. In other words a is now and b is
 * was.
 * If a.f1 > b.f1 and a.f1 - b.f1 == 3
 * the result will looks like
 * res.f1 = 3
 * String fields are ignored
 */
function getLbDiff(a, b) {
  let res = {}
  foreach (fieldId, fieldValue in a) {
    if (fieldId == "_id")
      continue
    if (type(fieldValue) == "string")
      continue
    let compareToValue = getTblValue(fieldId, b, 0)
    if (fieldValue != compareToValue)
      res[fieldId] <- fieldValue - compareToValue
  }
  return res
}

/**
 * Generates view for leaderbord item
 *
 * @param field_config  - item of ::leaderboards_list
 *                        or eventsTableConfig
 * @param lb_value      - value of specified field as it comes from char
 * @param lb_value_diff - optional, diff data, generated
 *                        with getLbDiff(...)
 *
 * @return view for getLeaderboardItemWidgets(...)
 */
function getLeaderboardItemView(lbCategory, lb_value, lb_value_diff = null, params = null) {
  let view = lbCategory.getItemCell(lb_value)
  view.name <- lbCategory.headerTooltip
  view.icon <- lbCategory.headerImage

  view.width  <- getTblValue("width",  params)
  view.pos    <- getTblValue("pos",    params)
  view.margin <- getTblValue("margin", params)

  if (lb_value_diff) {
    view.progress <- {
      positive = lb_value_diff > 0
      diff = lbCategory.getItemCell(lb_value_diff, null, true)
    }
  }

  return view
}

/**
 * Generates view for leaderbord items array
 * @param view  - { items = array of getLeaderboardItemView(...) }
 * @return markup ready for insertion into scene
 */
let getLeaderboardItemWidgets = @(view) handyman.renderCached("%gui/leaderboard/leaderboardItemWidget.tpl", view)

function getLbItemCell(id, value, dataType, allowNegative = false) {
  let res = {
    id   = id
    text = dataType.getShortTextByValue(value, allowNegative)
  }

  let tooltipText =  dataType.getPrimaryTooltipText(value, allowNegative)
  if (tooltipText != "")
    res.tooltip <- tooltipText

  return res
}

return {
  leaderboardModel
  checkLbRowVisibility
  getLbDiff
  getLeaderboardItemView
  getLeaderboardItemWidgets
  getLbItemCell
}
