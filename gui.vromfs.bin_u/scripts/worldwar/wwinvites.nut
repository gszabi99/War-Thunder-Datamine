import "DataBlock" as DataBlock
from "%scripts/matching/serviceNotifications/postbox.nut" import notifyMailRead
from "%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut" import getOperationById
from "%scripts/worldWar/operations/model/wwGlobalStatus.nut" import actionWithGlobalStatusRequest
from "%scripts/invites/invitesClasses.nut" import findInviteClass
from "%scripts/invites/invites.nut" import registerInviteUserlogHandler, findInviteByUid, addInvite
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "%globalScripts/unlockConsts.nut" import *
from "%scripts/dagui_natives.nut" import disable_user_log_entry
from "%scripts/dagui_library.nut" import *

function checkOperationParams(params) {
  if (params.operationId < 0)
    return false

  let operation = getOperationById(params.operationId)
  if (operation && operation.isAvailableToJoin())
    return true

  return false
}

function addWWInvite(p) {
  let inviteClass = findInviteClass(p.inviteClassName)
  let params = p?.params
  if (!inviteClass || !params)
    return

  if (findInviteByUid(inviteClass.getUidByParams(params)) && p?.mail_id)
    notifyMailRead(p.mail_id)

  if (checkOperationParams(params))
    return addInvite(inviteClass, params)

  let requestBlk = DataBlock()
  requestBlk.operationId = params.operationId
  actionWithGlobalStatusRequest("cln_ww_global_status_short", requestBlk, null, function() {
    if (checkOperationParams(params))
      addInvite(inviteClass, params)
  })
}

function addInviteFromUserlog(blk, idx) {
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

  disable_user_log_entry(idx)
  
  
  if (blk.type == EULT_WW_START_OPERATION)
    actionWithGlobalStatusRequest("cln_ww_queue_status")
  return true
}

registerInviteUserlogHandler(EULT_WW_START_OPERATION, addInviteFromUserlog)

addListenersWithoutEnv({
  PostboxNewMsg = @(p) p?.mail.inviteClassName ? addWWInvite({
    mail_id = p?.mail_id
    senderId = p?.mail.sender_id.tostring()
    inviteClassName = p?.mail.inviteClassName
    params = p?.mail.params
  }) : null
})
