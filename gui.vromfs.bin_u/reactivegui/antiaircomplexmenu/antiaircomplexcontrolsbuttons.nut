from "%rGui/radarState.nut" import Irst, Radar2ModeNameId
from "%rGui/hints/shortcuts.nut" import antiAirMenuShortcutHeight, getShortcut
from "%rGui/antiAirComplexMenu/antiAirMenuBaseComps.nut" import mkShortcutButton, mkShortcutButtonContinued, mkShortcutText, mkShortcutHint
from "%rGui/components/gamepadImgByKey.nut" import mkImageCompByDargKey
from "%rGui/ctrlsState.nut" import showConsoleButtons
from "%globalScripts/controls/shortcutActions.nut" import toggleShortcut
from "%rGui/globals/ui_library.nut" import *

let { modeNames } = require("%rGui/radarState.nut")
let JB = require("%rGui/control/gui_buttons.nut")

const radarColor = 0xFF00FF07
const radarColorInactive = 0x66006602

let mkGamepadImageByHotkey = @(hotkey, scale = 1) mkImageCompByDargKey(hotkey,
  0, { height = antiAirMenuShortcutHeight * scale })

function mkBtnHint(shortcut, gamepadHotkey = "", scale = 1) {
  return @() {
    watch = showConsoleButtons
    children = !showConsoleButtons.get() ? mkShortcutHint(shortcut, scale)
      : gamepadHotkey != "" ? mkGamepadImageByHotkey(gamepadHotkey)
      : null
  }
}

let mkMouseBtnHint = @(buttonImage, gamepadHotkey = "") @() {
  watch = showConsoleButtons
  children = !showConsoleButtons.get() ? getShortcut(
        { inputName = "inputImage", buttonImage }, { place = "antiAirMenu" })
    : gamepadHotkey != "" ? mkGamepadImageByHotkey(gamepadHotkey)
    : null
}

let mkZoomMinBtn = @() mkShortcutButtonContinued("gm_zoom_rangeMin",
  [mkMouseBtnHint("ui/gameuiskin#mouse_center_down"), mkShortcutText("-")])
let mkZoomMaxBtn = @() mkShortcutButtonContinued("gm_zoom_rangeMax",
  [mkMouseBtnHint("ui/gameuiskin#mouse_center_up"), mkShortcutText("+")])

let zoomControlByMouseWheel = {
  size = const [sw(100), sh(100)]
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  behavior = Behaviors.TrackMouse
  function onMouseWheel(mouseEvent) {
    if (mouseEvent.button > 0)
      toggleShortcut("gm_zoom_rangeMax")
    else
      toggleShortcut("gm_zoom_rangeMin")
  }
}

let isIrstActive = Computed(@() Irst.get() || (Radar2ModeNameId.get() >= 0 && modeNames[Radar2ModeNameId.get()].contains("IRST")))
let circularRadarModeText = {
  flow = FLOW_HORIZONTAL
  gap = hdpx(2)
  children = [
    @() {
      watch = isIrstActive
      rendObj = ROBJ_TEXT
      color = isIrstActive.get() ? radarColorInactive : radarColor
      font = Fonts.very_tiny_text_hud
      text = loc("hud/radar")
    }
    {
      rendObj = ROBJ_TEXT
      color = radarColorInactive
      font = Fonts.very_tiny_text_hud
      text = "/"
    }
    @() {
      watch = isIrstActive
      rendObj = ROBJ_TEXT
      color = isIrstActive.get() ? radarColor : radarColorInactive
      font = Fonts.very_tiny_text_hud
      text = loc("hud/irst")
    }
  ]
}

let mkSensorTypeSwitchBtn = @() mkShortcutButton("ID_SENSOR_TYPE_SWITCH_TANK",
  [mkBtnHint("ID_SENSOR_TYPE_SWITCH_TANK"), circularRadarModeText])

let mkSensorSwitchBtn = @() mkShortcutButton("ID_SENSOR_SWITCH_TANK", [
  mkBtnHint("ID_SENSOR_SWITCH_TANK", "J:R.Thumb"),
  mkShortcutText(loc("radar_selector/search"))],
  { hotkeys = [["^J:R.Thumb"]] })

let mkSensorScanPatternSwitchBtn = @()
  mkShortcutButton("ID_SENSOR_SCAN_PATTERN_SWITCH_TANK", [
    mkBtnHint("ID_SENSOR_SCAN_PATTERN_SWITCH_TANK", JB.B),
    mkShortcutText(loc("hud/search_mode"))],
    { hotkeys = [[$"^{JB.B}"]] })

let mkSensorRangeSwitchBtn = @() mkShortcutButton("ID_SENSOR_RANGE_SWITCH_TANK", [
  mkBtnHint("ID_SENSOR_RANGE_SWITCH_TANK", "J:Y"),
  mkShortcutText(loc("hud/scope_scale"))],
  { hotkeys = [["^J:Y"]] })

let mkSensorTargetLockBtn = @() mkShortcutButton("ID_SENSOR_TARGET_LOCK_TANK", [
  mkBtnHint("ID_SENSOR_TARGET_LOCK_TANK", "J:LB"),
  mkShortcutText(loc("actionBarItem/weapon_lock"))],
  { hotkeys = [["^J:LB"]] })

let mkFireBtn = @() mkShortcutButtonContinued("ID_FIRE_GM", [
  mkMouseBtnHint("ui/gameuiskin#mouse_right", "J:LT"),
  mkShortcutText(loc("hotkeys/ID_FIRE_GM"))],
  { hotkeys = [["^M:1"], ["^J:LT"]] })

let mkSpecialFireBtn = @() mkShortcutButtonContinued("ID_FIRE_GM_SPECIAL_GUN", [
  mkBtnHint("ID_FIRE_GM_SPECIAL_GUN", "J:RT"),
  mkShortcutText(loc("hotkeys/ID_FIRE_GM_SPECIAL_GUN"))],
  { hotkeys = [["^J:RT"]] })

let mkWeaponLockBtn = @() mkShortcutButton("ID_WEAPON_LOCK_TANK", [
  mkBtnHint("ID_WEAPON_LOCK_TANK", "J:X"), mkShortcutText(loc("hud/guidanceState"))],
  { hotkeys = [["^J:X"]] })

let mkNightVisionBtn = @(contentScaleV) mkShortcutButton("ID_TANK_NIGHT_VISION",
  [
    mkShortcutText(loc("hotkeys/ID_TANK_NIGHT_VISION"), contentScaleV),
    mkBtnHint("ID_TANK_NIGHT_VISION", "", contentScaleV)
  ], { size = [SIZE_TO_CONTENT, antiAirMenuShortcutHeight * contentScaleV],
  scale = contentScaleV, borderColor = 0xFF555555})

return {
  radarColor
  mkZoomMinBtn
  mkZoomMaxBtn
  mkSensorTypeSwitchBtn
  mkSensorSwitchBtn
  mkSensorScanPatternSwitchBtn
  mkSensorRangeSwitchBtn
  mkSensorTargetLockBtn
  mkFireBtn
  mkSpecialFireBtn
  mkWeaponLockBtn
  mkNightVisionBtn
  zoomControlByMouseWheel
}