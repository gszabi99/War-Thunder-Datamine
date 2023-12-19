let app = require("%xboxLib/impl/app.nut")
let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_ACTIVATION] ")
let {onSystemInviteAccept} = require("%scripts/social/xboxSquadManager/xboxSquadManager.nut")


let function activation_handler(senderXuid, invitedXuid, data) {
  logX($"Activated for {invitedXuid}, invited by {senderXuid}. Connection data: {data}")
  onSystemInviteAccept(senderXuid.tostring())
}


app.register_activation_callback(activation_handler)
