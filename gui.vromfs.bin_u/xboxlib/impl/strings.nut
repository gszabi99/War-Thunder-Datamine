let strings = require("xbox.strings")
let {subscribe_onehit} = require("eventbus")


let function verify(string_to_check, callback) {
  let eventName = "xbox_strings_verify"
  subscribe_onehit(eventName, function(result) {
    let success = result?.success
    callback?(success)
  })
  strings.verify(string_to_check, eventName)
}


let function verify_multi(strings_to_check, callback) {
  let eventName = "xbox_strings_verify_multi"
  subscribe_onehit(eventName, function(result) {
    let success = result?.success
    callback?(success)
  })
  strings.verify_multi(strings_to_check, eventName)
}


return {
  verify
  verify_multi
}