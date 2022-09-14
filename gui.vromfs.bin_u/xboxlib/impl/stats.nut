let stats = require("xbox.stats")
let {subscribe_onehit} = require("eventbus")


let function write_number(id, value, callback) {
  let eventName = "xbox_stats_write_number"
  subscribe_onehit(eventName, function(result) {
    let success = result?.success
    callback?(success)
  })
  stats.write_number(id, value, eventName)
}


let function write_string(id, value, callback) {
  let eventName = "xbox_stats_write_string"
  subscribe_onehit(eventName, function(result) {
    let success = result?.success
    callback?(success)
  })
  stats.write_string(id, value, eventName)
}


return {
  write_number
  write_string
}