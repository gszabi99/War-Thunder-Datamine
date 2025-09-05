import "gdk.stats" as stats
from "eventbus" import eventbus_subscribe_onehit

function write_number(id, value, callback) {
  let eventName = "xbox_stats_write_number"
  eventbus_subscribe_onehit(eventName, function(result) {
    let success = result?.success
    callback?(success)
  })
  stats.write_number(id, value, eventName)
}


function write_string(id, value, callback) {
  let eventName = "xbox_stats_write_string"
  eventbus_subscribe_onehit(eventName, function(result) {
    let success = result?.success
    callback?(success)
  })
  stats.write_string(id, value, eventName)
}


return freeze({
  write_number
  write_string
})