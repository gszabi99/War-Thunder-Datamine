let crossnet = require("%xboxLib/impl/crossnetwork.nut")
let eventbus = require("eventbus")

let USER_VOICE_STATE_CHANGE_EVENT = "xbox_user_voice_state_change_event"


let function set_user_voice_state(xuid, muted) {
  eventbus.send(USER_VOICE_STATE_CHANGE_EVENT, { xuid, muted })
}


let function subscribe_to_user_voice_state_change(callback) {
  eventbus.subscribe(USER_VOICE_STATE_CHANGE_EVENT, function(res) {
    let xuid = res?.xuid
    let muted = res?.muted
    callback?(xuid, muted)
  })
}


let function process_updated_permissions(permissions) {
  foreach(permission in permissions) {
    let muted = (permission.voice != crossnet.CommunicationState.Allowed)
    let xuid = permission.xuid
    set_user_voice_state(xuid, muted)
  }
}


crossnet.register_chat_state_change_callback(process_updated_permissions)


return  {
  subscribe_to_user_voice_state_change
  track_user_permissions = @(xuid) crossnet.track_user_chat_permissions(xuid)
  stop_tracking_user_permissions = @(xuid) crossnet.stop_tracking_user_chat_permissions(xuid)
}