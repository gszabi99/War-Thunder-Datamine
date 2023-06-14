//checked for plus_string
from "%scripts/dagui_library.nut" import *


let DataBlock  = require("DataBlock")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { notifyMailRead } =  require("%scripts/matching/serviceNotifications/postbox.nut")
let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { actionWithGlobalStatusRequest } = require("%scripts/worldWar/operations/model/wwGlobalStatus.nut")

let function checkOperationParams(params) {
  if (params.operationId < 0)
    return false

  let operation = getOperationById(params.operationId)
  if (operation && operation.isAvailableToJoin())
    return true

  return false
}

let function addWWInvite(p) {
  let inviteClass = ::g_invites_classes?[p.inviteClassName]
  let params = p?.params
  if (!inviteClass || !params)
    return

  if (::g_invites.findInviteByUid(inviteClass.getUidByParams(params)) && p?.mail_id)
    notifyMailRead(p.mail_id)

  if (checkOperationParams(params))
    return ::g_invites.addInvite(inviteClass, params)

  let requestBlk = DataBlock()
  requestBlk.operationId = params.operationId
  actionWithGlobalStatusRequest("cln_ww_global_status_short", requestBlk, null, function() {
    if (checkOperationParams(params))
      ::g_invites.addInvite(inviteClass, params)
  })
}

let addInviteFromUserlog = function(blk, idx) {
  if (blk?.disabled)
    return false

  addWWInvite({
    inviteClassName = "Operation"
    params = {
      operationId = blk.body?.operationId ?? -1
      clanTag = blk.body?.name ?? ""
      isStarted = blk.type == EULT_WW_START_OPERATION
    }
  })

  ::disable_user_log_entry(idx)
  // To update queue status immediately as operation created instead of refresh by timer.
  // It effects on buttons state in main WW screen.
  if (blk.type == EULT_WW_START_OPERATION)
    actionWithGlobalStatusRequest("cln_ww_queue_status")
  return true
}

::g_invites.registerInviteUserlogHandler(EULT_WW_START_OPERATION, addInviteFromUserlog)

addListenersWithoutEnv({
  PostboxNewMsg = @(p) p?.mail.inviteClassName ? addWWInvite({
    mail_id = p?.mail_id
    senderId = p?.mail.sender_id.tostring()
    inviteClassName = p?.mail.inviteClassName
    params = p?.mail.params
  }) : null
})
