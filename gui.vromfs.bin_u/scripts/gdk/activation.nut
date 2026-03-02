from "%scripts/dagui_library.nut" import *

let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_ACTIVATION] ")
let { register_activation_callback } = require("%gdkLib/impl/app.nut")
let {onSystemInviteAccept} = require("%scripts/social/xboxSquadManager/xboxSquadManager.nut")


function activation_handler(senderXuid, invitedXuid, data, isFromInvitation) {
  logX($"Activated for {invitedXuid}, invited by {senderXuid}. From invitation: {isFromInvitation}. Connection data: {data}")
  onSystemInviteAccept(senderXuid.tostring())
}


register_activation_callback(activation_handler)
