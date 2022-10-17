global const max_deadzone = 0.5
global const max_nonlinearity = 4
global const max_camera_smooth = 0.9

global const min_camera_speed = 0.5
global const max_camera_speed = 8

global const max_shortcuts = 3

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

enum AXIS_DEVICES {
  STICK,
  THROTTLE,
  GAMEPAD,
  MOUSE,
  UNKNOWN
}
global enum ctrlGroups {
  //base bit groups
  DEFAULT       = 0x0001 //== AIR
  AIR           = 0x0001
  TANK          = 0x0002
  SHIP          = 0x0004
  HELICOPTER    = 0x0008
  SUBMARINE     = 0x0010
  //


  ONLY_COMMON   = 0x0080

  VOICE         = 0x0100
  REPLAY        = 0x0200
  ARTILLERY     = 0x0400

  HANGAR        = 0x0800

  //complex groups mask
  NO_GROUP      = 0x0000
  COMMON        = 0x00FF
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