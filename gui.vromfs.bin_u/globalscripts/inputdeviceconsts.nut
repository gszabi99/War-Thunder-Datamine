let inputDeviceConsts = require_optional("inputDeviceConsts")
let consttable = getconsttable()

let fields = [
  "NULL_INPUT_DEVICE_ID",
  "STD_MOUSE_DEVICE_ID",
  "STD_KEYBOARD_DEVICE_ID",
  "JOYSTICK_DEVICE_0_ID",
  "JOYSTICK_DEVICE_LAST_ID",
  "STD_GESTURE_DEVICE_ID",
  "TOTAL_DEVICES",
  "DKEY_LCONTROL",
  "DKEY_RCONTROL",
  "DKEY_LALT",
  "DKEY_RALT",
  "DKEY_LSHIFT",
  "DKEY_RSHIFT",
]

let export = {}
foreach (k in fields)
  export[k] <- inputDeviceConsts?[k] ?? consttable[k]

return freeze(export)
