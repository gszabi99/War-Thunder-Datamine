let input = require("xbox.input")
let { subscribe } = require("eventbus")


let function register_for_devices_change(callback) {
  subscribe(input.device_change_event_name, function(result) {
    callback?(result?.type, result?.count)
  })
}


return {
  DeviceType = input.DeviceType
  register_for_devices_change
}
