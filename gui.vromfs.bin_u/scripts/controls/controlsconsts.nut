//checked for plus_string
from "%scripts/dagui_library.nut" import *

const MAX_DEADZONE = 0.5
const MAX_NONLINEARITY = 4
const MAX_CAMERA_SMOOTH = 0.9

const MIN_CAMERA_SPEED = 0.5
const MAX_CAMERA_SPEED = 8

const MAX_SHORTCUTS = 3

global enum CONTROL_TYPE {
  HEADER
  SECTION
  SHORTCUT
  AXIS_SHORTCUT
  AXIS
  SPINNER
  DROPRIGHT
  SLIDER
  SWITCH_BOX
  MOUSE_AXIS
  //for controls wizard
  MSG_BOX
  SHORTCUT_GROUP
  LISTBOX
  BUTTON
}

global enum AXIS_DEVICES {
  STICK,
  THROTTLE,
  GAMEPAD,
  MOUSE,
  UNKNOWN
}

global enum AXIS_MODIFIERS {
  NONE = 0x0,
  MIN = 0x8000,
  MAX = 0x4000,
}

//gamepad axes bitmask
global enum GAMEPAD_AXIS {
  NOT_AXIS = 0

  LEFT_STICK_HORIZONTAL = 0x1
  LEFT_STICK_VERTICAL = 0x2
  RIGHT_STICK_HORIZONTAL = 0x4
  RIGHT_STICK_VERTICAL = 0x8

  LEFT_TRIGGER = 0x10
  RIGHT_TRIGGER = 0x20
  BOTH_TRIGGER_XBOX = 0x40 // axisId=6 (R+L.Trigger) on XBOX
  BOTH_TRIGGER_PS4 = 0x200 // axisId=9 (R+L.Trigger) on PS4

  LEFT_STICK = 0x3
  RIGHT_STICK = 0xC
}

//mouse axes bitmask
global enum MOUSE_AXIS {
  NOT_AXIS = 0x0

  HORIZONTAL_AXIS = 0x1
  VERTICAL_AXIS = 0x2
  WHEEL_AXIS = 0x4

  MOUSE_MOVE = 0x3

  TOTAL = 3
}

global enum CONTROL_HELP_PATTERN {
  NONE,
  SPECIAL_EVENT,
  MISSION,
  IMAGE,
  GAMEPAD,
  KEYBOARD_MOUSE,
  HOTAS4,
  RADAR,
}

global enum AxisDirection {
  X,
  Y
}

global enum ConflictGroups {
  PLANE_FIRE,
  HELICOPTER_FIRE,
  TANK_FIRE
}

return {
  MAX_DEADZONE
  MAX_NONLINEARITY
  MAX_CAMERA_SMOOTH

  MIN_CAMERA_SPEED
  MAX_CAMERA_SPEED

  MAX_SHORTCUTS
}