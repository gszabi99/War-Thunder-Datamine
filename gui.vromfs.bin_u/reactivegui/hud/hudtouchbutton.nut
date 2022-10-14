from "%rGui/globals/ui_library.nut" import *

let { toggleShortcut, setShortcutOn, setShortcutOff } = require("%globalScripts/controls/shortcutActions.nut")

let touchButtonSize        = shHud(10)
let bigTouchButtonSize     = shHud(14)
let touchButtonMargin      = shHud(2)
let menuTouchButtonWidth   = shHud(10)
let menuTouchButtonHeight  = shHud(5.7)

let iconColor         = Color(200, 209, 219, 170)
let iconColorPushed   = Color(239, 231, 164)

const ship_steering_rangeMax = "ship_steering_rangeMax"
const ship_steering_rangeMin = "ship_steering_rangeMin"

let touchButtonsConfigs = {
  ["ID_FLIGHTMENU_SETUP"] = {
    image = Picture("!ui/gameuiskin#menu_1.png")
    size = [menuTouchButtonWidth, menuTouchButtonHeight]
  },
  ["ID_SHOW_VOICE_MESSAGE_LIST"] = {
    image = Picture("!ui/gameuiskin#radio_1.png")
    size = [menuTouchButtonWidth, menuTouchButtonHeight]
  },
  ["ID_MPSTATSCREEN"] = {
    image = Picture("!ui/gameuiskin#statistics_1.png")
    size = [menuTouchButtonWidth, menuTouchButtonHeight]
  },
  ["ID_TACTICAL_MAP"] = {
    image = Picture("!ui/gameuiskin#map_1.png")
    size = [menuTouchButtonWidth, menuTouchButtonHeight]
  },
  ["ID_ZOOM_TOGGLE"] = {
    image = Picture("!ui/gameuiskin#sniper_mode.png")
  },
  ["ID_SHIP_WEAPON_ALL"] = {
    image = Picture("!ui/gameuiskin#fire.png")
    size = [bigTouchButtonSize, bigTouchButtonSize]
  },
  ["ship_steering_rangeMax"] = {
    id = ship_steering_rangeMax
    image = Picture("!ui/gameuiskin#accelerator_left.png")
    size = [bigTouchButtonSize, bigTouchButtonSize]
    behavior = Behaviors.TouchScreenButton
    onTouchBegin = @() setShortcutOn(ship_steering_rangeMax)
    onTouchEnd = @() setShortcutOff(ship_steering_rangeMax)
  },
  ["ship_steering_rangeMin"] = {
    id = ship_steering_rangeMin
    image = Picture("!ui/gameuiskin#accelerator_right.png")
    size = [bigTouchButtonSize, bigTouchButtonSize]
    behavior = Behaviors.TouchScreenButton
    onTouchBegin = @() setShortcutOn(ship_steering_rangeMin)
    onTouchEnd = @() setShortcutOff(ship_steering_rangeMin)
  },
  ["ship_main_engine_rangeMax"] = {
    id = "ship_main_engine_rangeMax"
    image = Picture("!ui/gameuiskin#accelerator_up_v1.png")
    size = [bigTouchButtonSize, bigTouchButtonSize]
  },
  ["ship_main_engine_rangeMin"] = {
    id = "ship_main_engine_rangeMin"
    image = Picture("!ui/gameuiskin#accelerator_down_v1.png")
    size = [bigTouchButtonSize, bigTouchButtonSize]
  },
}

let function mkTouchButton(id, overrideParams = {}) {
  if (id not in touchButtonsConfigs)
    return null

  let buttonConfig = touchButtonsConfigs[id]
  let stateFlags = Watched(0)
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
