let input = require("xbox.input")
let { eventbus_subscribe } = require("eventbus")


function register_for_devices_change(callback) {
  eventbus_subscribe(input.device_change_event_name, function(result) {
    callback?(result?.type, result?.count)
  })
}


return {
  DeviceType = input.DeviceType
  register_for_devices_change
}
