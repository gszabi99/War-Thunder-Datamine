let guiBehaviourConsts = require_optional("guiBehaviourConsts")
let consttable = getconsttable()

let fields = [
  "EV_MOUSE_L_BTN",
  "EV_MOUSE_EXT_BTN",
  "EV_MOUSE_MOVE",
  "EV_MOUSE_WHEEL",
  "EV_MOUSE_OVER",
  "EV_MOUSE_OUTSIDE",
  "EV_MOUSE_HOVER_CHANGE",
  "EV_MOUSE_DBL_CLICK",
  "EV_JOYSTICK",
  "EV_KBD_UP",
  "EV_KBD_DOWN",
  "EV_ACCESSKEY",
  "EV_TIMER",
  "EV_AFTER_RECALC",
  "EV_AFTER_RECALC_FLOW_POS",
  "EV_PROCESS_ACCESSKEYS",
  "EV_PROCESS_SHORTCUTS",
  "EV_OVR_CHILD_VIS",
  "EV_ON_INSERT_REMOVE",
  "EV_ON_CMD",
  "EV_RENDER",
  "EV_BEFORE_CHILD_RECALC",
  "EV_CHILD_ENABLE",
  "EV_ON_FOCUS_LOST",
  "EV_ON_FOCUS_SET",
  "EV_MOUSE_NOT_ON_OBJ",
  "EV_AFTER_APPLY_CSS",
  "EV_GESTURE",
  "EV_GESTURE_START",
  "EV_GESTURE_END",
  "RETCODE_NOTHING",
  "RETCODE_PROCESSED",
  "RETCODE_OBJ_CHANGED",
  "RETCODE_HALT",
  "RETCODE_SEND_TO_USER",
  "RETCODE_FAILED",
  "RETCODE_ERROR",
  "RETCODE_ERASE_ALL_BHV",
  "RETCODE_HALT_SHORTCUT",
  "BITS_MOUSE_BTN_FIRST",
  "BITS_MOUSE_BTN_L",
  "BITS_MOUSE_BTN_R",
  "BITS_MOUSE_BTN_M",
  "BITS_MOUSE_BUTTONS",
  "BITS_MOUSE_TAP",
  "BITS_MOUSE_OVER",
  "BITS_MOUSE_OUTSIDE",
  "BITS_MOUSE_NOT_ON_OBJ",
  "BITS_MOUSE_DBL_CLICK",
]

let export = {}
local c = 0
foreach (k in fields) {
  local cc = guiBehaviourConsts?[k] ?? consttable?[k]
  c = cc == null ? (c+1): cc
  export[k] <- c
}

return freeze(export)
