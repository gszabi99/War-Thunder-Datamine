import "gdk.input" as input
from "eventbus" import eventbus_subscribe

function register_for_devices_change(callback) {
  eventbus_subscribe(input.device_change_event_name, function(result) {
    callback?(result?.type, result?.count)
  })
}


return freeze({
  DeviceType = input.DeviceType
  register_for_devices_change
})
