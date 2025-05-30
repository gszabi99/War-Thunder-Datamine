let app = require("gdk.app")
let {eventbus_subscribe} = require("eventbus")


function register_activation_callback(callback) {
  app.install_activation_handler()
  eventbus_subscribe(app.activation_event_name, function(result) {
    let senderXuid = result?.sender_xuid
    let invitedXuid = result?.invited_xuid
    let invitationData = result?.data
    let isFromInvitation = result?.is_from_invitation
    callback?(senderXuid, invitedXuid, invitationData, isFromInvitation)
  })
}


function register_constrain_callback(callback) {
  eventbus_subscribe(app.constrain_event_name, function(result) {
    callback?(result?.active)
  })
}


function register_important_live_error_callback(callback) {
  app.install_important_live_error_handler()
  eventbus_subscribe(app.important_live_error_event_name, function(err) {
    callback?(err)
  })
}


return {
  launch_browser = app.launch_browser
  get_title_id = app.get_title_id
  get_region = app.get_region

  register_activation_callback
  register_constrain_callback
  register_important_live_error_callback
}