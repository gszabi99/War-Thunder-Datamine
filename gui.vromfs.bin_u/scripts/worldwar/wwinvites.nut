from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { notifyMailRead } =  require("%scripts/matching/serviceNotifications/postbox.nut")
let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { actionWithGlobalStatusRequest } = require("%scripts/worldWar/operations/model/wwGlobalStatus.nut")

let function addInviteToOperation(p) {
  if (::g_invites.findInviteByUid(::g_invites_classes.Operation.getUidByParams(p)) && p?.mail_id)
    notifyMailRead(p.mail_id)

  if (p.operationId > -1 && p.operationId != ::ww_get_operation_id()){
    let requestBlk = ::DataBlock()
    requestBlk.operationId = p.operationId
    actionWithGlobalStatusRequest("cln_ww_global_status_short", requestBlk, null, function() {
      let operation = getOperationById(p.operationId)
      if (operation && operation.isAvailableToJoin())
        ::g_invites.addInvite(::g_invites_classes.Operation, p)
    })
  }
}

let function removeInviteToOperation(operationId) {
  let uid = ::g_invites_classes.Operation.getUidByParams({mail = {operationId = operationId}})
  let invite = ::g_invites.findInviteByUid(uid)
  if (invite)
    ::g_invites.remove(invite)
}

let addInviteFromUserlog = function(blk, idx) {
  if (blk?.disabled)
    return false

  addInviteToOperation({
    operationId = blk.body?.operationId ?? -1
    clanTag = blk.body?.name ?? ""
    isStarted = blk.type == EULT_WW_START_OPERATION
  })

  ::disable_user_log_entry(idx)
  return true
}

::g_invites.registerInviteUserlogHandler(EULT_WW_CREATE_OPERATION, addInviteFromUserlog)
::g_invites.registerInviteUserlogHandler(EULT_WW_START_OPERATION, addInviteFromUserlog)

addListenersWithoutEnv({
  PostboxNewMsg = @(p) addInviteToOperation({
    mail_id = p?.mail_id
    senderId = p?.mail.sender_id.tostring()
    country = p?.mail.country ?? ""
    operationId = p?.mail.operationId
  })
})

return {
  removeInviteToOperation
}