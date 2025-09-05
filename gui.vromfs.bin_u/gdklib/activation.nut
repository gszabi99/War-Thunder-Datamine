from "eventbus" import eventbus_subscribe, eventbus_send
from "%sqstd/globalState.nut" import hardPersistWatched
import "%gdkLib/impl/app.nut" as app

let logX = require("%sqstd/log.nut")().with_prefix("[ACTIVATION] ")


let ACTIVATION_EVENT_NAME = "xbox_sq_activation_event"
let activationData = hardPersistWatched("activationData", null)


function activation_handler(senderXuid, invitedXuid, data, isFromInvitation) {
  logX($"Activated for {invitedXuid}, invited by {senderXuid}. Connection data: {data}. Is from invitation: {isFromInvitation}")
  activationData.set({ senderXuid, invitedXuid, data, isFromInvitation })
  eventbus_send(ACTIVATION_EVENT_NAME, null)
}


function register_activation_callback(callback) {
  eventbus_subscribe(ACTIVATION_EVENT_NAME, function(_) {
    callback?()
  })
}


app.register_activation_callback(activation_handler)


return freeze({
  get_sender_xuid = @() activationData.get()?.senderXuid ?? 0
  get_invited_xuid = @() activationData.get()?.invitedXuid ?? 0
  get_activation_data = @() activationData.get()?.data
  hasActivationData = @() activationData.get() != null
  resetActivationData = @() activationData.set(null)
  get_is_from_invitation = @() activationData.get().isFromInvitation
  register_activation_callback
})
