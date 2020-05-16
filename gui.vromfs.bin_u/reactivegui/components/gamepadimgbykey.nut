local { cutPrefix } = require("std/string.nut")

local dargJKeysToImage = {
  "J:D.Up"          : "dpad_up",
  "J:D.Down"        : "dpad_down",
  "J:D.Left"        : "dpad_left",
  "J:D.Right"       : "dpad_right",
  "J:A"             : "button_a",
  "J:B"             : "button_b",
  "J:CROSS"         : "button_a",
  "J:CIRCLE"        : "button_b",

  "J:Start"         : "button_start",
  "J:Menu"          : "button_start",
  "J:Back"          : "button_back",
  "J:Select"        : "button_back",
  "J:View"          : "button_back",

  "J:L.Thumb"       : "l_stick",
  "J:LS"            : "l_stick",
  "J:L3"            : "l_stick",
  "J:L3.Centered"   : "l_stick",
  "J:LS.Centered"   : "l_stick",
  "J:R.Thumb"       : "r_stick",
  "J:RS"            : "r_stick",
  "J:R3"            : "r_stick",
  "J:R3.Centered"   : "r_stick",
  "J:RS.Centered"   : "r_stick",

  "J:L.Shoulder"    : "l_shoulder",
  "J:LB"            : "l_shoulder",
  "J:L1"            : "l_shoulder",
  "J:R.Shoulder"    : "r_shoulder",
  "J:RB"            : "r_shoulder",
  "J:R1"            : "r_shoulder",

  "J:X"             : "button_x",
  "J:Y"             : "button_y",
  "J:SQUARE"        : "button_x",
  "J:TRIANGLE"      : "button_y",

  "J:L.Trigger"     : "l_trigger",
  "J:LT"            : "l_trigger",
  "J:L2"            : "l_trigger",
  "J:R.Trigger"     : "r_trigger",
  "J:RT"            : "r_trigger",
  "J:R2"            : "r_trigger",

  "J:L.Thumb.Right" : "l_stick_right",
  "J:LS.Right"      : "l_stick_right",
  "J:L.Thumb.Left"  : "l_stick_left",
  "J:LS.Left"       : "l_stick_left",
  "J:L.Thumb.Up"    : "l_stick_up",
  "J:LS.Up"         : "l_stick_up",
  "J:L.Thumb.Down"  : "l_stick_down",
  "J:LS.Down"       : "l_stick_down",

  "J:R.Thumb.Right" : "r_stick_right",
  "J:RS.Right"      : "r_stick_right",
  "J:R.Thumb.Left"  : "r_stick_left",
  "J:RS.Left"       : "r_stick_left",
  "J:R.Thumb.Up"    : "r_stick_up",
  "J:RS.Up"         : "r_stick_up",
  "J:R.Thumb.Down"  : "r_stick_down",
  "J:RS.Down"       : "r_stick_down",

  "J:L.Thumb.h"     : "l_stick_to_left_n_right",
  "J:L.Thumb.v"     : "l_stick_to_up_n_down",
  "J:R.Thumb.h"     : "r_stick_to_left_n_right",
  "J:R.Thumb.v"     : "r_stick_to_up_n_down",

  "J:R.Thumb.hv"     : "r_stick_4",
  "J:L.Thumb.hv"     : "l_stick_4",
}

const PRESSED_POSTFIX = "_pressed"

local defHeight = ::dp(2) + ::fpx(36)

local function mkImageComp(text, params = {}) {
  if (text==null || text=="")
    return null
  local height = (params?.height ?? defHeight).tointeger()
  return {
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    rendObj = ROBJ_IMAGE
    image = ::Picture($"!{text}:{height}:{height}:K")
    keepAspect = true
    size = [height, height]
  }.__merge(params)
}

local getTexture = @(textureId) cutPrefix(::cross_call.getTextureName(textureId), "#")

local function mkImageCompByDargKey(key, sf = null, params={}) {
  local textureId = dargJKeysToImage?[key]
  if (textureId == null)
    return null

  local isPressed = sf != null && (sf & S_ACTIVE) != 0
  local textureName = isPressed ? getTexture($"{textureId}{PRESSED_POSTFIX}") : ""
  if (textureName == "")
    textureName = getTexture(textureId)

  return mkImageComp(textureName, params)
}

return {
  mkImageCompByDargKey = mkImageCompByDargKey
}
