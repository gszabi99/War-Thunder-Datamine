from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { notifyMailRead } =  require("%scripts/matching/serviceNotifications/postbox.nut")

let function addInviteToOperation(p) {
  if (::g_invites.findInviteByUid(::g_invites_classes.Operation.getUidByParams(p)))
    return notifyMailRead(p?.mail_id)

  ::g_invites.addInvite(::g_invites_classes.Operation, p)
}

let function removeInviteToOperation(operationId) {
  let uid = ::g_invites_classes.Operation.getUidByParams({mail = {operationId = operationId}})
  let invite = ::g_invites.findInviteByUid(uid)
  if (invite)
    ::g_invites.remove(invite)
}

let addWwInvite = function(blk, idx) {
  if (blk?.disabled)
    return false

  ::g_world_war.addOperationInvite(
    blk.body?.operationId ?? -1,
    blk.body?.clanId ?? -1,
    blk.type == EULT_WW_START_OPERATION,
    blk?.timeStamp ?? 0)

  ::disable_user_log_entry(idx)
  return true
}

::g_invites.registerInviteUserlogHandler(EULT_WW_CREATE_OPERATION, addWwInvite)
::g_invites.registerInviteUserlogHandler(EULT_WW_START_OPERATION, addWwInvite)

addListenersWithoutEnv({
  PostboxNewMsg = @(p) addInviteToOperation(p)
})

return {
  removeInviteToOperation
}