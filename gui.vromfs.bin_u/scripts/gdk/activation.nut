from "%scripts/dagui_library.nut" import *

let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_ACTIVATION] ")
let { eventbus_send, eventbus_subscribe_onehit } = require("eventbus")
let { try_switch_user_to, get_xuid } = require("%gdkLib/impl/user.nut")
let { register_activation_callback } = require("%gdkLib/impl/app.nut")
let {onSystemInviteAccept} = require("%scripts/social/xboxSquadManager/xboxSquadManager.nut")


function activation_handler(senderXuid, invitedXuid, data, isFromInvitation) {
  let currentXuid = get_xuid()
  let needRelogin = currentXuid != invitedXuid
  logX($"Activated for {invitedXuid}, invited by {senderXuid}. From invitation: {isFromInvitation}. Connection data: {data}")
  logX($"Current xuid: {currentXuid}, need relogin: {needRelogin}")

  if (needRelogin) {
    eventbus_subscribe_onehit("on_sign_out", function(...) {
      try_switch_user_to(invitedXuid, function(success, xuid) {
        if (!success) {
          logerr($"Failed to switch user to {invitedXuid}. Got {xuid}")
          return
        }
        onSystemInviteAccept(senderXuid.tostring())
      })
    })
    eventbus_send("request_logout", {})
  } else {
    onSystemInviteAccept(senderXuid.tostring())
  }
}


register_activation_callback(activation_handler)
