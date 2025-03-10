from "%scripts/dagui_library.nut" import *

let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { AXIS_MODIFIERS, GAMEPAD_AXIS, MOUSE_AXIS } = require("%scripts/controls/controlsConsts.nut")

let ICO_PRESET_DEFAULT = "#ui/gameuiskin#xone_"
let ICO_PRESET_PS4 = "#ui/gameuiskin#ps_"
let SVG_EXT = ".svg"

let controlsList = { 
  button_a = true
  button_a_pressed = true
  button_b = true
  button_b_pressed = true
  button_x = true
  button_x_pressed = true
  button_y = true
  button_y_pressed = true

  button_back = true
  button_back_pressed = true
  button_share = true
  button_share_pressed = true
  button_start = true
  button_start_pressed = true

  l_trigger = true
  l_trigger_pressed = true
  r_trigger = true
  r_trigger_pressed = true
  l_shoulder = true
  l_shoulder_pressed = true
  r_shoulder = true
  r_shoulder_pressed = true

  dirpad = true
  dirpad_down = true
  dirpad_left = true
  dirpad_right = true
  dirpad_up = true

  l_stick = true
  l_stick_4 = true
  l_stick_down = true
  l_stick_left = true
  l_stick_pressed = true
  l_stick_right = true
  l_stick_to_left_n_right = true
  l_stick_to_up_n_down = true
  l_stick_up = true

  r_stick = true
  r_stick_4 = true
  r_stick_down = true
  r_stick_left = true
  r_stick_pressed = true
  r_stick_right = true
  r_stick_to_left_n_right = true
  r_stick_to_up_n_down = true
  r_stick_up = true

  table_plays_icon = true
  team_dirpad = true
  touchpad = true
  touchpad_pressed = true
}

let btnNameByIndex = [
  "dirpad_up"     
  "dirpad_down"   
  "dirpad_left"   
  "dirpad_right"  
  "button_start"  
  "button_back"   
  "l_stick_pressed" 
  "r_stick_pressed" 
  "l_shoulder"    
  "r_shoulder"    
  "table_plays_icon" 
  "table_plays_icon" 
  "button_a"      
  "button_b"      
  "button_x"      
  "button_y"      
  "l_trigger"     
  "r_trigger"     
  "l_stick_right" 
  "l_stick_left"  
  "l_stick_up"    
  "l_stick_down"  
  "r_stick_right" 
  "r_stick_left"  
  "r_stick_up"    
  "r_stick_down"  
]

let mouseButtonTextures = [
  "mouse_left"
  "mouse_right"
  "mouse_center"
]

let ps4TouchpadImagesByMouseIdx = [
  "touchpad"
  "touchpad_pressed"
]

let gamepadAxesImages = {
  [GAMEPAD_AXIS.NOT_AXIS] = "",
  [GAMEPAD_AXIS.LEFT_STICK_HORIZONTAL] = "l_stick_to_left_n_right",
  [GAMEPAD_AXIS.LEFT_STICK_VERTICAL] = "l_stick_to_up_n_down",
  [GAMEPAD_AXIS.LEFT_STICK] = "l_stick_4",
  [GAMEPAD_AXIS.RIGHT_STICK_HORIZONTAL] = "r_stick_to_left_n_right",
  [GAMEPAD_AXIS.RIGHT_STICK_VERTICAL] = "r_stick_to_up_n_down",
  [GAMEPAD_AXIS.RIGHT_STICK] = "r_stick_4",
  [GAMEPAD_AXIS.LEFT_TRIGGER] = "l_trigger",
  [GAMEPAD_AXIS.RIGHT_TRIGGER] = "r_trigger",

  [GAMEPAD_AXIS.LEFT_STICK_VERTICAL | AXIS_MODIFIERS.MIN] = "l_stick_down",
  [GAMEPAD_AXIS.LEFT_STICK_VERTICAL | AXIS_MODIFIERS.MAX] = "l_stick_up",
  [GAMEPAD_AXIS.LEFT_STICK_HORIZONTAL | AXIS_MODIFIERS.MIN] = "l_stick_left",
  [GAMEPAD_AXIS.LEFT_STICK_HORIZONTAL | AXIS_MODIFIERS.MAX] = "l_stick_right",
  [GAMEPAD_AXIS.RIGHT_STICK_VERTICAL | AXIS_MODIFIERS.MIN] = "r_stick_down",
  [GAMEPAD_AXIS.RIGHT_STICK_VERTICAL | AXIS_MODIFIERS.MAX] = "r_stick_up",
  [GAMEPAD_AXIS.RIGHT_STICK_HORIZONTAL | AXIS_MODIFIERS.MIN] = "r_stick_left",
  [GAMEPAD_AXIS.RIGHT_STICK_HORIZONTAL | AXIS_MODIFIERS.MAX] = "r_stick_right",
  [GAMEPAD_AXIS.BOTH_TRIGGER_XBOX | AXIS_MODIFIERS.MIN] = "l_trigger",
  [GAMEPAD_AXIS.BOTH_TRIGGER_XBOX | AXIS_MODIFIERS.MAX] = "r_trigger",
  [GAMEPAD_AXIS.BOTH_TRIGGER_PS4 | AXIS_MODIFIERS.MIN] = "l_trigger",
  [GAMEPAD_AXIS.BOTH_TRIGGER_PS4 | AXIS_MODIFIERS.MAX] = "r_trigger",
}

let mouseAxesImages = {
  [MOUSE_AXIS.NOT_AXIS] = "",
  [MOUSE_AXIS.HORIZONTAL_AXIS] = "mouse_move_l_r",
  [MOUSE_AXIS.VERTICAL_AXIS] = "mouse_move_up_down",
  [MOUSE_AXIS.MOUSE_MOVE] = "mouse_move_4_sides",
  [MOUSE_AXIS.WHEEL_AXIS] = "mouse_center_up_down",

  [MOUSE_AXIS.WHEEL_AXIS | AXIS_MODIFIERS.MIN] = "mouse_center_down",
  [MOUSE_AXIS.WHEEL_AXIS | AXIS_MODIFIERS.MAX] = "mouse_center_up",
  [MOUSE_AXIS.HORIZONTAL_AXIS | AXIS_MODIFIERS.MIN] = "mouse_move_l",
  [MOUSE_AXIS.HORIZONTAL_AXIS | AXIS_MODIFIERS.MAX] = "mouse_move_r",
  [MOUSE_AXIS.VERTICAL_AXIS | AXIS_MODIFIERS.MIN] = "mouse_move_down",
  [MOUSE_AXIS.VERTICAL_AXIS | AXIS_MODIFIERS.MAX] = "mouse_move_up",
}

let curPreset = isPlatformSony ? ICO_PRESET_PS4 : ICO_PRESET_DEFAULT

let getTexture = @(id, preset = curPreset) (id in controlsList) ? "".concat(preset, id, SVG_EXT) : ""
let getTextureByButtonIdx = @(idx) getTexture(btnNameByIndex?[idx])

local cssString = null
let getCssString = function() {
  if (cssString)
    return cssString

  cssString = ""
  foreach (name, _value in controlsList)
    cssString = "".concat(cssString, "@const control_", name, ":", getTexture(name), ";")
  return cssString
}

let getGamepadAxisTexture = @(axisVal, _preset = curPreset) getTexture(gamepadAxesImages?[axisVal])

let getMouseTexture = function(idx, preset = curPreset) {
  if (preset == ICO_PRESET_PS4 && idx in ps4TouchpadImagesByMouseIdx)
    return "".concat(preset, ps4TouchpadImagesByMouseIdx[idx], SVG_EXT)

  if (idx in mouseButtonTextures)
    return $"#ui/gameuiskin#{mouseButtonTextures[idx]}"

  return getTextureByButtonIdx(idx)
}

let getMouseAxisTexture = @(axisVal)
  axisVal in mouseAxesImages ? $"#ui/gameuiskin#{mouseAxesImages[axisVal]}" : ""

return {
  TOTAL_BUTTON_INDEXES = btnNameByIndex.len()
  ICO_PRESET_DEFAULT       = ICO_PRESET_DEFAULT
  ICO_PRESET_PS4           = ICO_PRESET_PS4

  fullIconsList = controlsList

  getTexture = getTexture
  getTextureByButtonIdx = getTextureByButtonIdx
  getGamepadAxisTexture = getGamepadAxisTexture
  getMouseTexture = getMouseTexture
  getMouseAxisTexture = getMouseAxisTexture
  hasMouseTexture = @(idx) mouseButtonTextures?[idx] != null
  hasTextureByButtonIdx = @(idx) btnNameByIndex?[idx] != null
  getButtonNameByIdx = @(idx) btnNameByIndex?[idx] ?? ""
  getCssString = getCssString
}
