let perm = require("xbox.permissions")
let {eventbus_subscribe_onehit} = require("eventbus")


function check_for_user(permission, xuid, callback) {
  let eventName = "xbox_permissions_check_for_user"
  eventbus_subscribe_onehit(eventName, function(result) {
    let success = result?.success
    let res_xuid = result?.xuid
    let reasons = result?.xuid
    let allowed = result?.allowed
    callback?(success, res_xuid, allowed, reasons)
  })
  perm.check_for_user(permission, xuid, eventName)
}


function check_for_users(permission, xuids, callback) {
  let eventName = "xbox_permissions_check_for_users"
  eventbus_subscribe_onehit(eventName, function(result) {
    let success = result?.success
    let results = result?.results
    callback?(success, results)
  })
  perm.check_for_users(permission, xuids, eventName)
}


function check_anonymous(permission, anon_user_type, callback) {
  let eventName = "xbox_permissions_check_anonymous"
  eventbus_subscribe_onehit(eventName, function(result) {
    let success = result?.success
    let allowed = result?.allowed
    let reasons = result?.reasons
    callback?(success, allowed, reasons)
  })
  perm.check_anonymous(permission, anon_user_type, eventName)
}


return {
  Permission = perm.Permission
  AnonUserType = perm.AnonUserType
  DenyReason = perm.DenyReason

  check_deny_reason = perm.check_deny_reason

  check_for_user
  check_for_users
  check_anonymous
}
