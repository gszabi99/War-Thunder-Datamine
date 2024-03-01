let strings = require("xbox.strings")
let {eventbus_subscribe_onehit} = require("eventbus")


function verify(string_to_check, callback) {
  let eventName = "xbox_strings_verify"
  eventbus_subscribe_onehit(eventName, function(result) {
    let success = result?.success
    callback?(success)
  })
  strings.verify(string_to_check, eventName)
}


function verify_multi(strings_to_check, callback) {
  let eventName = "xbox_strings_verify_multi"
  eventbus_subscribe_onehit(eventName, function(result) {
    let success = result?.success
    callback?(success)
  })
  strings.verify_multi(strings_to_check, eventName)
}


return {
  verify
  verify_multi
}