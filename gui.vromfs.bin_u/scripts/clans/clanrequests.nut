from "%scripts/dagui_natives.nut" import char_send_clan_oneway_blk, clan_get_my_clan_id, clan_get_admin_editor_mode, clan_request_log, clan_get_clan_log, clan_request_membership_request, clan_get_my_clan_name
from "%scripts/dagui_library.nut" import *

let DataBlock  = require("DataBlock")
let { addTask } = require("%scripts/tasker.nut")
let { convertBlk } = require("%sqstd/datablock.nut")
let { g_clan_log_type } = require("%scripts/clans/clanLogType.nut")
let time = require("%scripts/time.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { addPopup } = require("%scripts/popups/popups.nut")
let { getContact } = require("%scripts/contacts/contacts.nut")

function prepareCreateRequest(clanType, name, tag, slogan, description, announcement, region) {
  let requestData = DataBlock()
  requestData["name"] = name
  requestData["tag"] = tag
  requestData["slogan"] = slogan
  requestData["region"] = region
  requestData["type"] = clanType.getTypeName()

  if (clanType.isDescriptionChangeAllowed())
    requestData["desc"] = description

  if (clanType.isAnnouncementAllowed())
    requestData["announcement"] = announcement

  return requestData
}

function prepareEditRequest(clanType, name, tag, slogan, description, announcement, region) {
  let requestData = DataBlock()

  requestData["version"] = 2

  if (name != null)
    requestData["name"] = name
  if (tag != null)
    requestData["tag"] = tag
  if (clanType.isDescriptionChangeAllowed() && description != null)
    requestData["desc"] = description
  if (slogan != null)
    requestData["slogan"] = slogan
  if (clanType.isAnnouncementAllowed() && announcement != null)
    requestData["announcement"] = announcement
  if (region != null)
    requestData["region"] = region

  return requestData
}

function prepareUpgradeRequest(clanType, tag, description, announcement) {
  let requestData = DataBlock()
  requestData["type"] = clanType.getTypeName()
  requestData["tag"] = tag
  requestData["desc"] = clanType.isDescriptionChangeAllowed() ? description : ""
  requestData["announcement"] = clanType.isAnnouncementAllowed() ? announcement : ""
  return requestData
}

function clan_request_set_membership_requirements(clanIdStr, requirements, autoAccept) {
  let blk = DataBlock()
  blk["membership_req"] <- requirements
  blk["_id"] = clanIdStr
  if (autoAccept)
    blk["autoaccept"] = true
  return char_send_clan_oneway_blk("cln_clan_set_membership_requirements", blk)
}

function requestClanLog(clanId, rowsCount, requestMarker, callbackFnSuccess, callbackFnError, handler) {
  let params = DataBlock()
  params._id = clanId.tointeger()
  params.count = rowsCount

  
  if ((clan_get_my_clan_id() != clanId) && !clan_get_admin_editor_mode())
    params.events = "create;info"

  if (requestMarker != null)
    params.last = requestMarker
  let taskId = clan_request_log(clanId, params)
  let successCb = Callback(callbackFnSuccess, handler)
  let errorCb = Callback(callbackFnError, handler)

  addTask(
    taskId,
    null,
    function () {
      let logData = {}
      let logDataBlk = clan_get_clan_log()

      logData.requestMarker <- logDataBlk?.lastMark
      logData.logEntries <- []
      foreach (logEntry in logDataBlk % "log") {
        if (logEntry?.uid != null && logEntry?.nick != null)
          getContact(logEntry.uid, logEntry.nick)

        if (logEntry?.uId != null && logEntry?.uN != null)
          getContact(logEntry.uId, logEntry.uN)

        let logEntryTable = convertBlk(logEntry)
        let logType = g_clan_log_type.getTypeByName(logEntryTable.ev)

        if ("time" in logEntryTable)
          logEntryTable.time = time.buildDateTimeStr(logEntryTable.time)

        logEntryTable.header <- logType.getLogHeader(logEntryTable)
        if (logType.needDetails(logEntryTable)) {
          let commonFields = logType.getLogDetailsCommonFields()
          let shortCommonDetails = logEntryTable.filter(@(_v, k) commonFields.indexof(k) != null)
          let individualFields = logType.getLogDetailsIndividualFields()
          let shortIndividualDetails = logEntryTable.filter(@(_v, k) individualFields.indexof(k) != null)

          let fullDetails = shortCommonDetails
          foreach (key, value in shortIndividualDetails) {
            let fullKey = $"{logEntryTable.ev}_{key}"
            fullDetails[fullKey] <- value
          }

          logEntryTable.details <- fullDetails
          logEntryTable.details.signText <- logType.getSignText(logEntryTable)
        }

        logData.logEntries.append(logEntryTable)
      }

      successCb(logData)
    },
    errorCb
  )
}

function membershipRequestSend(clanId) {
  let taskId = clan_request_membership_request(clanId, "", "", "")
  let onSuccess = function() {
    if (clanId == "") { 
      broadcastEvent("ClanMembershipCanceled")
      return
    }

    addPopup("", loc("clan/requestSent"))
    broadcastEvent("ClanMembershipRequested")
  }
  addTask(taskId, { showProgressBox = true }, onSuccess)
}

function requestMembership(clanId) {
  if (::clan_get_requested_clan_id() == "-1" || clan_get_my_clan_name() == "") {
    membershipRequestSend(clanId)
    return
  }

  scene_msg_box(
    "new_request_cancels_old",
    null,
    loc("msg/clan/clan_request_cancel_previous",
      { prevClanName = colorize("hotkeyColor", clan_get_my_clan_name()) }
    ),
    [
      ["ok", @() membershipRequestSend(clanId) ],
      ["cancel", @() null ]
    ],
    "ok", { cancel_fn = @() null }
  )
}

function cancelMembership() {
  membershipRequestSend("")
}

return {
  prepareCreateRequest
  prepareEditRequest
  prepareUpgradeRequest
  clan_request_set_membership_requirements
  requestClanLog
  membershipRequestSend
  requestMembership
  cancelMembership
}