from "app" import isAppActive
from "steam" import steam_is_overlay_active
from "controls" import isXInputDevice, setBindMode, ActivationCondition
from "eventbus" import eventbus_subscribe
from "%globalScripts/inputDeviceConsts.nut" import *
from "%scripts/dagui_natives.nut" import joystick_get_default
from "%scripts/controls/controlsVisual.nut" import getLocalizedControlName, hackTextAssignmentForR2buttonOnPS4,
  getLocalizedShortcutName
from "%scripts/controls/controlsState.nut" import getCurControlsPreset
from "%scripts/controls/input/button.nut" import Button
from "%scripts/controls/input/combination.nut" import Combination
from "%scripts/controls/shortcutViewConfig.nut" import getShortcutConfig
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "%appGlobals/controls/assignShortcutState.nut" import assignShortcut
from "%scripts/dagui_library.nut" import *




let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

const MAX_INPUTS = 4
const KEY_ESCAPE = 1
const XINPUT_START = 4

let DEV_BY_DEVICE_NAME = freeze({
  keyboard = STD_KEYBOARD_DEVICE_ID
  mouse = STD_MOUSE_DEVICE_ID
  joystick = JOYSTICK_DEVICE_0_ID
})

let activationTypeChooseConfig = [
  {
    activationType = ActivationCondition.DEFAULT
    locId = "controls/activationType/onPressed"
  }
  {
    activationType = ActivationCondition.LONG_PRESS
    locId = "controls/activationType/onLongPress"
  }
  {
    activationType = ActivationCondition.TAPPED_TWICE
    locId = "controls/activationType/onDoubleTap"
  }
]

local cur = null

function getInputText() {
  if (cur.dev.len() == 0)
    return ""
  let preset = getCurControlsPreset()
  let text = " + ".join(cur.dev.map(@(dev, idx) getLocalizedControlName(preset, dev, cur.btn[idx])))
  return hackTextAssignmentForR2buttonOnPS4(cur.dev.len() < 3 ? $"{text} + ?" : text)
}

function getCombination() {
  let inputs = cur.dev.map(@(dev, idx) Button(dev, cur.btn[idx], cur.activationType))
  return getShortcutConfig(inputs.len() == 1 ? inputs[0] : Combination(inputs))
}

function updateView() {
  if (cur == null) {
    assignShortcut.set(null)
    return
  }
  let { step, shortcutName, activationType } = cur
  assignShortcut.set({
    step
    shortcutName
    inputText = getInputText()
    combination = step == "activation" ? getCombination() : null
    activationTypes = activationTypeChooseConfig.map(@(c) loc(c.locId))
    activationIdx = activationTypeChooseConfig.findindex(@(c) c.activationType == activationType) ?? 0
  })
}

function setListening(isListening) {
  get_cur_gui_scene().sleepKeyRepeat(isListening)
  setBindMode(isListening)
  
  if (handlersManager.isHandlerValid(cur.owner))
    showObjById("gamercard_bottom", !isListening, cur.owner.scene)
}

function showInputStep() {
  cur.dev.clear()
  cur.btn.clear()
  cur.step = "input"
  setListening(true)
  updateView()
}

function showActivationStep() {
  setListening(false)
  cur.step = "activation"
  updateView()
}

function closeAssignShortcut() {
  if (cur == null)
    return
  setListening(false)
  cur = null
  updateView()
}

function openAssignShortcut(owner, onDone, shortcutId) {
  closeAssignShortcut()
  cur = {
    owner
    onDone
    shortcutName = shortcutId == "" ? "" : getLocalizedShortcutName(shortcutId)
    dev = []
    btn = []
    activationType = ActivationCondition.DEFAULT
    step = "input"
  }
  showInputStep()
}

function applyAssignShortcut() {
  let { owner, onDone, dev, btn, activationType } = cur
  closeAssignShortcut()
  if (dev.len() > 0 && dev.len() == btn.len() && handlersManager.isHandlerValid(owner))
    onDone.call(owner, dev, btn, activationType)
}

function isPovHat(btn) {
  let joy = joystick_get_default()
  return joy != null && "getButtonCount" in joy && btn >= joy.getButtonCount()
}

function onInput(dev, btn, isDown) {
  if (cur?.step != "input")
    return
  if (!isAppActive() || steam_is_overlay_active()) {
    if (cur.dev.len() > 0)
      showInputStep()
    return
  }
  let isCancel = (dev == STD_KEYBOARD_DEVICE_ID && btn == KEY_ESCAPE)
    || (dev == JOYSTICK_DEVICE_0_ID && btn == XINPUT_START && isXInputDevice())
  if (isCancel) {
    if (!isDown)
      closeAssignShortcut()
    return
  }
  if (!isDown) {
    if (cur.dev.len() > 0)
      showActivationStep()
    return
  }
  
  if (cur.dev.len() >= MAX_INPUTS || (dev == JOYSTICK_DEVICE_0_ID && isPovHat(btn))
      || (dev == STD_KEYBOARD_DEVICE_ID && btn == 0)
      || cur.dev.findindex(@(d, idx) d == dev && cur.btn[idx] == btn) != null)
    return
  cur.dev.append(dev)
  cur.btn.append(btn)
  updateView()
}

function onAction(p) {
  if (cur == null)
    return
  if (!handlersManager.isHandlerValid(cur.owner))
    return closeAssignShortcut()
  let { action } = p
  if (action == "input")
    onInput(DEV_BY_DEVICE_NAME[p.device], p.btn, p.isDown)
  else if (action == "cancel")
    closeAssignShortcut()
  else if (action == "back")
    showInputStep()
  else if (action == "apply")
    applyAssignShortcut()
  else if (action == "activationType") {
    cur.activationType = activationTypeChooseConfig?[p.idx].activationType ?? ActivationCondition.DEFAULT
    updateView()
  }
}

assignShortcut.set(null)
eventbus_subscribe("assignShortcut.action", onAction)
eventbus_subscribe("controls.bindGesture", @(p) onInput(STD_GESTURE_DEVICE_ID, p.gesture, p.isDown))
addListenersWithoutEnv({
  AfterJoinEventRoom = @(_) closeAssignShortcut()
  SwitchedBaseHandler = @(_) closeAssignShortcut()
})

return freeze({
  openAssignShortcut
})
