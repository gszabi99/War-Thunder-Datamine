import "gdk.app" as app
from "eventbus" import eventbus_subscribe

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


function register_unconstrain_callback(callback) {
  eventbus_subscribe(app.unconstrain_event_name, function(_) {
    callback?()
  })
}


function register_resume_callback(callback) {
  eventbus_subscribe(app.resume_event_name, function(_) {
    callback?()
  })
}


function register_important_live_error_callback(callback) {
  app.install_important_live_error_handler()
  eventbus_subscribe(app.important_live_error_event_name, function(err) {
    callback?(err)
  })
}


return freeze({
  launch_browser = app.launch_browser
  get_title_id = app.get_title_id
  get_region = app.get_region

  register_activation_callback
  register_unconstrain_callback
  register_resume_callback
  register_important_live_error_callback
})