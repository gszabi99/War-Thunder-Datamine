let app = require("%xboxLib/impl/app.nut")
let {eventbus_subscribe, eventbus_send} = require("eventbus")
let logX = require("%sqstd/log.nut")().with_prefix("[ACTIVATION] ")

let ACTIVATION_EVENT_NAME = "xbox_sq_activation_event"
let activationData = persist("activationData", @() { senderXuid = 0, invitedXuid = 0, data = null })


function activation_handler(senderXuid, invitedXuid, data) {
  logX($"Activated for {invitedXuid}, invited by {senderXuid}. Connection data: {data}")
  activationData.senderXuid = senderXuid
  activationData.invitedXuid = invitedXuid
  activationData.data = data
  eventbus_send(ACTIVATION_EVENT_NAME, null)
}


function register_activation_callback(callback) {
  eventbus_subscribe(ACTIVATION_EVENT_NAME, function(_) {
    callback?()
  })
}


app.register_activation_callback(activation_handler)


return {
  get_sender_xuid = @() activationData.senderXuid
  get_invited_xuid = @() activationData.invitedXuid
  get_activation_data = @() activationData.data
  register_activation_callback
}