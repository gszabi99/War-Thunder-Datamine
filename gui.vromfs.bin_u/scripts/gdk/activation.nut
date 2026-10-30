from "%scripts/social/xboxSquadManager/xboxSquadManager.nut" import onSystemInviteAccept
from "%gdkLib/impl/app.nut" import register_activation_callback
from "%scripts/dagui_library.nut" import *

let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_ACTIVATION] ")


function activation_handler(senderXuid, invitedXuid, data, isFromInvitation) {
  logX($"Activated for {invitedXuid}, invited by {senderXuid}. From invitation: {isFromInvitation}. Connection data: {data}")
  onSystemInviteAccept(senderXuid.tostring())
}


register_activation_callback(activation_handler)
