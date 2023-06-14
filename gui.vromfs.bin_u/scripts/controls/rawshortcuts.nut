//checked for plus_string
from "%scripts/dagui_library.nut" import *

::SHORTCUT <- {
  MOUSE_LEFT_BUTTON   = { dev = [STD_MOUSE_DEVICE_ID], btn = [0] }
  MOUSE_RIGHT_BUTTON  = { dev = [STD_MOUSE_DEVICE_ID], btn = [1] }
  MOUSE_MIDDLE_BUTTON = { dev = [STD_MOUSE_DEVICE_ID], btn = [2] }
  MOUSE_BUTTON_4      = { dev = [STD_MOUSE_DEVICE_ID], btn = [3] }
  MOUSE_BUTTON_5      = { dev = [STD_MOUSE_DEVICE_ID], btn = [4] }

  KEY_ESC       = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [1] }

  KEY_1         = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [2] }
  KEY_2         = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [3] }
  KEY_3         = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [4] }
  KEY_4         = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [5] }
  KEY_5         = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [6] }
  KEY_6         = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [7] }
  KEY_7         = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [8] }
  KEY_8         = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [9] }
  KEY_9         = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [10] }
  KEY_0         = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [11] }
  KEY_Q         = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [16] }
  KEY_W         = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [17] }
  KEY_E         = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [18] }
  KEY_R         = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [19] }
  KEY_A         = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [30] }
  KEY_S         = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [31] }
  KEY_D         = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [32] }
  KEY_F         = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [33] }
  KEY_G         = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [34] }
  KEY_H         = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [35] }
  KEY_J         = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [37] }
  KEY_V         = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [47] }
  KEY_B         = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [48] }
  KEY_N         = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [49] }
  KEY_M         = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [50] }
  KEY_COMMA     = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [51] }

  KEY_ENTER     = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [28] }
  KEY_LCTRL     = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [29] }
  KEY_LSHIFT    = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [42] }
  KEY_LALT      = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [56] }
  KEY_SPACE     = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [57] }

  KEY_PRNT_SCRN = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [183] }

  KEY_UP        = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [200] }
  KEY_LEFT      = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [203] }
  KEY_DOWN      = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [208] }
  KEY_RIGHT     = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [205] }
  KEY_PAGE_UP   = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [201] }
  KEY_PAGE_DOWN = { dev = [STD_KEYBOARD_DEVICE_ID], btn = [209] }

  GAMEPAD_UP             = { dev = [JOYSTICK_DEVICE_0_ID], btn = [0], accessKey = "J:Dpad.Up" }
  GAMEPAD_DOWN           = { dev = [JOYSTICK_DEVICE_0_ID], btn = [1], accessKey = "J:Dpad.Down" }
  GAMEPAD_LEFT           = { dev = [JOYSTICK_DEVICE_0_ID], btn = [2], accessKey = "J:Dpad.Left" }
  GAMEPAD_RIGHT          = { dev = [JOYSTICK_DEVICE_0_ID], btn = [3], accessKey = "J:Dpad.Right" }
  GAMEPAD_START          = { dev = [JOYSTICK_DEVICE_0_ID], btn = [4], accessKey = "J:Start" } //PS4 Options
  GAMEPAD_BACK           = { dev = [JOYSTICK_DEVICE_0_ID], btn = [5], accessKey = "J:Back" } // PS4 Touchscreen Press
  GAMEPAD_LSTICK_PRESS   = { dev = [JOYSTICK_DEVICE_0_ID], btn = [6], accessKey = "J:L.Thumb" }
  GAMEPAD_RSTICK_PRESS   = { dev = [JOYSTICK_DEVICE_0_ID], btn = [7], accessKey = "J:R.Thumb" }
  GAMEPAD_L1             = { dev = [JOYSTICK_DEVICE_0_ID], btn = [8], accessKey = "J:LB" } //PS4 L1
  GAMEPAD_R1             = { dev = [JOYSTICK_DEVICE_0_ID], btn = [9], accessKey = "J:RB" } //PS4 R1
  GAMEPAD_A              = { dev = [JOYSTICK_DEVICE_0_ID], btn = [12], accessKey = "J:A" } //PS4 Cross
  GAMEPAD_B              = { dev = [JOYSTICK_DEVICE_0_ID], btn = [13], accessKey = "J:B" } //PS4 Round
  GAMEPAD_X              = { dev = [JOYSTICK_DEVICE_0_ID], btn = [14], accessKey = "J:X" } //PS4 Squar
  GAMEPAD_Y              = { dev = [JOYSTICK_DEVICE_0_ID], btn = [15], accessKey = "J:Y" } //PS4 Triangle
  GAMEPAD_L2             = { dev = [JOYSTICK_DEVICE_0_ID], btn = [16], accessKey = "J:LT" } //PS4 L2
  GAMEPAD_R2             = { dev = [JOYSTICK_DEVICE_0_ID], btn = [17], accessKey = "J:RT" } //PS4 R2
  GAMEPAD_LSTICK_RIGHT   = { dev = [JOYSTICK_DEVICE_0_ID], btn = [18], accessKey = "J:L.Thumb.Right" }
  GAMEPAD_LSTICK_LEFT    = { dev = [JOYSTICK_DEVICE_0_ID], btn = [19], accessKey = "J:L.Thumb.Left" }
  GAMEPAD_LSTICK_UP      = { dev = [JOYSTICK_DEVICE_0_ID], btn = [20], accessKey = "J:L.Thumb.Up" }
  GAMEPAD_LSTICK_DOWN    = { dev = [JOYSTICK_DEVICE_0_ID], btn = [21], accessKey = "J:L.Thumb.Down" }
  GAMEPAD_RSTICK_RIGHT   = { dev = [JOYSTICK_DEVICE_0_ID], btn = [22], accessKey = "J:R.Thumb.Right" }
  GAMEPAD_RSTICK_LEFT    = { dev = [JOYSTICK_DEVICE_0_ID], btn = [23], accessKey = "J:R.Thumb.Left" }
  GAMEPAD_RSTICK_UP      = { dev = [JOYSTICK_DEVICE_0_ID], btn = [24], accessKey = "J:R.Thumb.Up" }
  GAMEPAD_RSTICK_DOWN    = { dev = [JOYSTICK_DEVICE_0_ID], btn = [25], accessKey = "J:R.Thumb.Down" }
  GAMEPAD_LSTICK_PRESS_2 = { dev = [JOYSTICK_DEVICE_0_ID], btn = [26], accessKey = "J:L.Thumb" }
  GAMEPAD_RSTICK_PRESS_2 = { dev = [JOYSTICK_DEVICE_0_ID], btn = [27], accessKey = "J:R.Thumb" }
}

::AXIS <- {
  LEFTSTICK_X   = 0
  LEFTSTICK_Y   = 1
  RIGHTSTICK_X  = 2
  RIGHTSTICK_Y  = 3
  LTRIGGER      = 4
  RTRIGGER      = 5
}

::GAMEPAD_ENTER_SHORTCUT <- ::ps4_is_circle_selected_as_enter_button() ?
                             ::SHORTCUT.GAMEPAD_B :
                             ::SHORTCUT.GAMEPAD_A