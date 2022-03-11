local { toggleShortcut, setShortcutOn, setShortcutOff } = require("globalScripts/controls/shortcutActions.nut")

local touchButtonSize        = shHud(10)
local bigTouchButtonSize     = shHud(14)
local touchButtonMargin      = shHud(2)
local menuTouchButtonWidth   = shHud(10)
local menuTouchButtonHeight  = shHud(5.7)

local iconColor         = Color(200, 209, 219, 170)
local iconColorPushed   = Color(239, 231, 164)

local touchButtonsConfigs = {
  ["ID_FLIGHTMENU_SETUP"] = {
    image = ::Picture("!ui/gameuiskin#menu_1")
    size = [menuTouchButtonWidth, menuTouchButtonHeight]
  },
  ["ID_SHOW_VOICE_MESSAGE_LIST"] = {
    image = ::Picture("!ui/gameuiskin#radio_1")
    size = [menuTouchButtonWidth, menuTouchButtonHeight]
  },
  ["ID_MPSTATSCREEN"] = {
    image = ::Picture("!ui/gameuiskin#statistics_1")
    size = [menuTouchButtonWidth, menuTouchButtonHeight]
  },
  ["ID_TACTICAL_MAP"] = {
    image = ::Picture("!ui/gameuiskin#map_1")
    size = [menuTouchButtonWidth, menuTouchButtonHeight]
  },
  ["ID_ZOOM_TOGGLE"] = {
    image = ::Picture("!ui/gameuiskin#sniper_mode")
  },
  ["ID_SHIP_WEAPON_ALL"] = {
    image = ::Picture("!ui/gameuiskin#fire")
    size = [bigTouchButtonSize, bigTouchButtonSize]
  },
  ["ship_steering_rangeMax"] = {
    id = "ship_steering_rangeMax"
    image = ::Picture("!ui/gameuiskin#accelerator_left")
    size = [bigTouchButtonSize, bigTouchButtonSize]
    behavior = Behaviors.TouchScreenButton
    onClick = @() setShortcutOn(id)
    onTouchEnd = @() setShortcutOff(id)
  },
  ["ship_steering_rangeMin"] = {
    id = "ship_steering_rangeMin"
    image = ::Picture("!ui/gameuiskin#accelerator_right")
    size = [bigTouchButtonSize, bigTouchButtonSize]
    behavior = Behaviors.TouchScreenButton
    onClick = @() setShortcutOn(id)
    onTouchEnd = @() setShortcutOff(id)
  },
  ["ship_main_engine_rangeMax"] = {
    id = "ship_main_engine_rangeMax"
    image = ::Picture("!ui/gameuiskin#accelerator_up_v1")
    size = [bigTouchButtonSize, bigTouchButtonSize]
  },
  ["ship_main_engine_rangeMin"] = {
    id = "ship_main_engine_rangeMin"
    image = ::Picture("!ui/gameuiskin#accelerator_down_v1")
    size = [bigTouchButtonSize, bigTouchButtonSize]
  },
}

local function mkTouchButton(id, overrideParams = {}) {
  if (id not in touchButtonsConfigs)
    return null

  local buttonConfig = touchButtonsConfigs[id]
  local stateFlags = Watched(0)
  return @() {
    watch = stateFlags
    behavior = Behaviors.Button
    rendObj = ROBJ_IMAGE
    size = [touchButtonSize, touchButtonSize]
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    color = stateFlags.value & S_ACTIVE ? iconColorPushed : iconColor
    onClick = @() toggleShortcut(id)
    onElemState = @(v) stateFlags(v)
  }.__update(buttonConfig, overrideParams)
}

return {
  mkTouchButton
  touchButtonSize
  bigTouchButtonSize
  touchButtonMargin
}
