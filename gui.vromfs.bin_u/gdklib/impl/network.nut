import "gdk.network" as net
from "eventbus" import eventbus_subscribe

function subscribe_for_network_state_change(callback) {
  eventbus_subscribe(net.network_state_change_event_name, function(result) {
    callback?(result?.availability)
  })
}


return freeze({
  NetworkAvailability = net.NetworkAvailability
  subscribe_for_network_state_change
})
