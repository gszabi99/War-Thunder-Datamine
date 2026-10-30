import "%sqStdLibs/helpers/u.nut" as u
from "%scripts/controls/controlsConsts.nut" import MAX_DEADZONE, MAX_SHORTCUTS, CONTROL_TYPE
from "%scripts/controls/shortcutsUtils.nut" import getShortcutParts, refillControlsDupes, buildHotkeyItem, getSliderValueText
from "%scripts/controls/controlRowsView.nut" import mkViewRows
from "%scripts/controls/controlsVisual.nut" import remapAxisName
from "%scripts/controls/controlsState.nut" import getCurControlsPreset
from "%scripts/controls/controlsManager.nut" import commitControls
from "%scripts/controls/controlsCompatibility.nut" import joystickSetCurSettings
from "%scripts/controls/assignShortcut.nut" import openAssignShortcut
from "%appGlobals/controls/assignShortcutState.nut" import assignShortcut as assignShortcutState
from "%scripts/options/consoleMode.nut" import showConsoleButtons
from "%scripts/dargScreenBridge.nut" import mkComboItems
from "%appGlobals/controls/axisSetupState.nut" import axisSetup, axisSetupItems, setAxisSetupField, setAxisSetupItem,
  resetAxisSetup, axisPoints
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent, addListenersWithoutEnv
from "%sqStdLibs/helpers/daguiString.nut" import stripTags
from "dagor.workcycle" import setInterval, clearTimer
from "dagor.time" import get_time_msec
from "eventbus" import eventbus_subscribe
from "string" import format
from "math" import abs, fabs, pow
from "%scripts/dagui_natives.nut" import joystick_get_default, is_axis_digital
from "%scripts/dagui_library.nut" import *




let shortcutsAxisListModule = require("%scripts/controls/shortcutsList/shortcutsAxis.nut")
let { shortcutsList } = require("%scripts/controls/shortcutsList/shortcutsList.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

const INPUT_TIMER_SEC = 0.03
const AUTODETECT_DEVIATION = 12000

const REST_CAPTURE_TIME = 0.5
const RELATIVE_ONLY = ["kRelSpd", "kRelStep"]

let axisItems = shortcutsAxisListModule.types
local cur = null
local timerMsec = 0

let getItemValue = @(id) axisSetupItems.get()?[id]?.value
let getRowItem = @(rowIdx) axisItems?[(rowIdx ?? -1).tointeger()]
let getAxis = @() cur.curJoyParams.getAxis(cur.axisItem.axisIndex)
let isOwnerValid = @() handlersManager.isHandlerValid(cur?.owner)

function showRows() {
  let axis = getAxis()
  let hidden = cur.axisItem?.hideAxisOptions ?? []
  let isRelative = getItemValue("relativeAxis") ?? axis.relative
  let rows = axisItems.map(@(item, idx) hidden.contains(item.id) ? { label = null }
    : buildHotkeyItem(idx, cur.shortcuts, item, axis))
  let { viewRows, items, kinds } = mkViewRows(rows)
  let prev = axisSetupItems.get()
  foreach (id, kind in kinds) {
    if (kind == "shortcut")
      continue
    let value = prev?[id]?.value ?? items[id].value
    items[id].value = value
    if (kind == "slider")
      items[id].valueText <- getSliderValueText(shortcutsAxisListModule[id], value)
    if (RELATIVE_ONLY.contains(id))
      items[id].enabled <- isRelative
  }
  foreach (row in viewRows)
    if (row.itemId == "rangeMax" || row.itemId == "rangeMin")
      row.label = loc(isRelative ? (row.itemId == "rangeMax" ? "hotkeys/rangeInc" : "hotkeys/rangeDec")
        : $"hotkeys/{row.itemId}")
  
  axisSetupItems.mutate(@(v) v.__update(items))
  setAxisSetupField("rows", viewRows)
}

function updateButtons() {
  let isShortcut = cur.curShortcut != null
  setAxisSetupItem("btn_reset_shortcut", "shown", isShortcut)
  setAxisSetupItem("btn_assign", "shown", isShortcut)
}

function selectRow(rowIdx) {
  let item = getRowItem(rowIdx)
  if (item == null)
    return
  cur.curShortcut = item == cur.curShortcut ? null : item
  setAxisSetupField("selectedRowId", cur.curShortcut == null ? null : $"table_row_{rowIdx}")
  updateButtons()
}

function updateAxisIdx() {
  if (cur.bindAxisNum <= cur.numAxisInList && axisSetup.get().axisIdx != cur.bindAxisNum + 1)
    setAxisSetupField("axisIdx", cur.bindAxisNum + 1)
}

function fillAxisList() {
  let curDevice = joystick_get_default()
  let curPreset = getCurControlsPreset()
  cur.numAxisInList = curDevice ? curPreset.getNumAxes() : 0
  let names = ["#joystick/axis_not_assigned"]
  for (local i = 0; i < cur.numAxisInList; i++)
    names.append(stripTags(remapAxisName(curPreset, i)))
  setAxisSetupField("axisOptions", mkComboItems(names))
  setAxisSetupField("axisIdx", curDevice ? (cur.bindAxisNum + 1) : 0)
}

function reinit() {
  cur.bindAxisNum = getAxis().axisId
  if ("modifiersId" in cur.axisItem)
    foreach (name, shortcutId in cur.axisItem.modifiersId)
      shortcutsAxisListModule[name].shortcutId = shortcutId
  axisSetupItems.set({})
  fillAxisList()
  showRows()
  axisPoints.set([0.0, 0.0])
  updateButtons()
}

function getAxisRawValues(idx, rawPos) {
  let { axisRawValues } = cur
  if (axisRawValues.len() <= idx)
    axisRawValues.resize(idx + 1, null)
  if (axisRawValues[idx] == null)
    axisRawValues[idx] = { def = rawPos, last = rawPos, stuckTime = 0.0, inited = is_axis_digital(idx) || rawPos != 0 }
  return axisRawValues[idx]
}


function detectMovedAxis(device, dt) {
  cur.autodetectTime += dt
  for (local i = 0; i < device.getNumAxes(); i++) {
    let rawPos = device.getAxisPosRaw(i)
    let rawValues = getAxisRawValues(i, rawPos)
    if (!rawValues.inited && (rawPos != 0 || cur.autodetectTime > REST_CAPTURE_TIME)) {
      
      if (cur.autodetectTime <= REST_CAPTURE_TIME)
        rawValues.def = rawPos
      rawValues.inited = true
    }
    if (abs(rawPos - rawValues.def) <= AUTODETECT_DEVIATION)
      continue
    if (abs(rawPos - rawValues.last) < 1000) {
      rawValues.stuckTime += dt
      if (rawValues.stuckTime > 3.0)
        rawValues.def = rawPos
    }
    else {
      rawValues.last = rawPos
      rawValues.stuckTime = 0.0
    }
    
    cur.bindAxisNum = i
    return
  }
}

function onInputTimer() {
  let now = get_time_msec()
  let dt = (now - timerMsec) * 0.001
  timerMsec = now
  if (cur == null || !isOwnerValid() || cur.owner.scene.getModalCounter() > 0 || assignShortcutState.get() != null)
    return
  let curDevice = joystick_get_default()
  if (!curDevice)
    return

  if (axisSetup.get().autodetect)
    detectMovedAxis(curDevice, dt)
  updateAxisIdx()
  if (cur.bindAxisNum < 0)
    return

  let devVal = curDevice.getAxisPosRaw(cur.bindAxisNum) / 32000.0
  let deadzone = MAX_DEADZONE * getItemValue("deadzone") / shortcutsAxisListModule.deadzone.max.tofloat()
  let nonlin = getItemValue("nonlinearity").tofloat() / 10 - 1
  local val = (getItemValue("invertAxis") ? -devVal : devVal) * getItemValue("kMul").tofloat() / 100.0
    + getItemValue("kAdd").tofloat() / 50.0
  let valSign = val < 0 ? -1 : 1
  val = max(-1.0, min(1.0, val))
  val = fabs(val) < deadzone ? 0 : valSign * ((fabs(val) - deadzone) / (1.0 - deadzone))
  axisPoints.set([valSign * pow(fabs(val), 1 + nonlin), devVal])
}

function closeAxisSetup() {
  if (cur == null)
    return
  clearTimer(onInputTimer)
  let { changedShortcuts, changedAxes, shortcuts } = cur
  cur = null
  resetAxisSetup()
  broadcastEvent("ControlsChangedShortcuts", { changedShortcuts, updShortcuts = shortcuts })
  broadcastEvent("ControlsChangedAxes", { changedAxes, updShortcuts = shortcuts })
}

function applyAxisValues() {
  let axis = getAxis()
  foreach (item in axisItems) {
    if ((("condition" in item) && !item.condition()) || "setValue" not in item)
      continue
    let value = getItemValue(item.id)
    if (value != null)
      item.setValue(axis, value)
  }
  joystickSetCurSettings(cur.curJoyParams)
}

function doBindAxis() {
  cur.curJoyParams.bindAxis(cur.axisItem.axisIndex, cur.bindAxisNum)
  applyAxisValues()
  commitControls()
  closeAxisSetup()
}

function findBindedAxes() {
  let { bindAxisNum, axisItem, curJoyParams } = cur
  if (bindAxisNum < 0 || !axisItem.checkAssign)
    return []
  return shortcutsList.filter(@(item) item.type == CONTROL_TYPE.AXIS && item != axisItem
    && (axisItem.checkGroup & item.checkGroup) != 0 && curJoyParams.getAxis(item.axisIndex).axisId == bindAxisNum)
}

function doAxisApply() {
  let alreadyBindedAxes = findBindedAxes()
  if (alreadyBindedAxes.len() == 0)
    return doBindAxis()

  let msg = loc("hotkeys/msg/unbind_axis_question", {
    action = ", ".join(alreadyBindedAxes.map(@(item) loc($"controls/{item.id}")))
  })
  scene_msg_box("controls_axis_bind_existing_axis", null, msg, [
    ["add", doBindAxis],
    ["replace", function() {
      foreach (item in alreadyBindedAxes) {
        cur.curJoyParams.bindAxis(item.axisIndex, -1)
        cur.changedAxes.append(item)
      }
      doBindAxis()
    }],
    ["cancel", @() null],
  ], "add")
}


function checkZoomOnMWheel() {
  if (cur.bindAxisNum < 0 || cur.axisItem.id != "zoom")
    return false
  let wheelItem = shortcutsList.findvalue(@(item) item.id == "mouse_z")
  let value = cur.owner.getControlValue("mouse_z")
  if (value == null || wheelItem?.values[value] != "zoom")
    return false
  scene_msg_box("zoom_axis_assigned", null, format(loc("msg/zoomAssignmentsConflict"), loc("controls/mouse_z")), [
    ["replace", function() {
      cur.owner.setControlValue("mouse_z", 0)
      doAxisApply()
    }],
    ["cancel", function() {
      cur.bindAxisNum = -1
      doAxisApply()
    }]
  ], "replace")
  return true
}

function onShortcutChange(shortcutId) {
  u.appendOnce(shortcutId, cur.changedShortcuts)
  let name = cur.axisItem?.modifiersId?.findindex(@(id) id == shortcutId)
  if (name != null)
    setAxisSetupItem(name, "cell", getShortcutParts(cur.shortcuts, shortcutId))
}

function findButtons(devs, btns, activationType) {
  let res = []
  foreach (idx, event in cur.shortcuts)
    if (cur.axisItem.checkGroup & cur.shortcutItems[idx].checkGroup)
      foreach (buttonIdx, button in event) {
        if (!button || button.dev.len() != devs.len() || button.activationType != activationType)
          continue
        local numEqual = 0
        foreach (i, dev in button.dev)
          foreach (j, d in devs)
            if (dev == d && button.btn[i] == btns[j])
              numEqual++
        if (numEqual == btns.len() && !cur.dontCheckControlsDupes.contains(cur.shortcutItems[idx].id))
          res.append([idx, buttonIdx])
      }
  return res
}

function getShortcutLocId(shortcutId) {
  let reqItem = cur.shortcutItems?[shortcutId]
  if (reqItem == null)
    return ""
  let name = reqItem?.modifiersId?.findindex(@(id) id == shortcutId)
  return name == null || name == "" ? reqItem.id : $"{reqItem.id}_{name}"
}

function doBind(devs, btns, activationType, item) {
  let event = cur.shortcuts[item.shortcutId]
  event.append({ dev = devs, btn = btns, activationType })
  if (event.len() > MAX_SHORTCUTS)
    event.remove(0)
  onShortcutChange(item.shortcutId)
}

function bindShortcut(devs, btns, activationType) {
  let item = cur?.curShortcut
  if (item == null || devs.len() == 0 || devs.len() != btns.len() || item.shortcutId not in cur.shortcuts)
    return
  let curBinding = findButtons(devs, btns, activationType)
  if (curBinding.len() == 0)
    return doBind(devs, btns, activationType, item)
  if (curBinding.findvalue(@(b) b[0] == item.shortcutId) != null)
    return

  let action = ", ".join(curBinding.map(@(b) loc($"hotkeys/{getShortcutLocId(b[0])}")))
  scene_msg_box("controls_axis_bind_existing_shortcut", null, loc("hotkeys/msg/unbind_question", { action }), [
    ["add", @() doBind(devs, btns, activationType, item)],
    ["replace", function() {
      foreach (binding in curBinding) {
        let [shortcutId, btnIdx] = binding
        if (cur.shortcuts?[shortcutId][btnIdx] != null)
          cur.shortcuts[shortcutId].remove(btnIdx)
        onShortcutChange(shortcutId)
      }
      doBind(devs, btns, activationType, item)
    }],
    ["cancel", @() null],
  ], "cancel")
}

function clearShortcut(item) {
  cur.shortcuts[item.shortcutId].clear()
  onShortcutChange(item.shortcutId)
}

function resetAxis() {
  cur.bindAxisNum = -1
  cur.curJoyParams.resetAxis(cur.axisItem.axisIndex)
  let axis = getAxis()
  foreach (item in axisItems) {
    if (item.type == CONTROL_TYPE.SLIDER)
      setAxisSetupItem(item.id, "value", item.value(axis).tointeger())
    else if (item.type == CONTROL_TYPE.SWITCH_BOX)
      setAxisSetupItem(item.id, "value", item.value(axis))
    else if (item.type == CONTROL_TYPE.AXIS_SHORTCUT)
      clearShortcut(item)
  }
  showRows()
}

function assignShortcut() {
  if (cur.curShortcut != null)
    openAssignShortcut(cur.owner, @(devs, btns, activationType) bindShortcut(devs, btns, activationType),
      cur.curShortcut.id)
}

function applyAxisSetup() {
  if (!checkZoomOnMWheel())
    doAxisApply()
}

let BUTTON_ACTIONS = {
  btn_axis_restore = function() {
    cur.bindAxisNum = getAxis().axisId
    updateAxisIdx()
  }
  btn_axis_reset = resetAxis
  btn_reset_shortcut = @() cur.curShortcut == null ? null : clearShortcut(cur.curShortcut)
  btn_assign = assignShortcut
  btn_apply = applyAxisSetup
}

function setValue(id, value) {
  setAxisSetupItem(id, "value", value)
  let item = shortcutsAxisListModule?[id]
  if (item?.type == CONTROL_TYPE.SLIDER)
    setAxisSetupItem(id, "valueText", getSliderValueText(item, value))
  if (id == "relativeAxis")
    showRows()
}

function selectAndAssign(rowIdx) {
  if (getRowItem(rowIdx) != cur.curShortcut)
    selectRow(rowIdx)
  assignShortcut()
}

let ACTIONS = {
  button = @(p) BUTTON_ACTIONS?[p.id]()
  value = @(p) setValue(p.id, p.value)
  axis = function(p) {
    cur.bindAxisNum = p.idx - 1
    updateAxisIdx()
    u.appendOnce(cur.axisItem.modifiersId[""], cur.changedShortcuts)
  }
  function autodetect(p) {
    setAxisSetupField("autodetect", p.value)
    if (!p.value)
      return
    
    cur.axisRawValues = []
    cur.autodetectTime = 0.0
  }
  
  shortcutClick = @(p) showConsoleButtons.get() && p.byGamepad ? selectAndAssign(p.rowIdx) : selectRow(p.rowIdx)
  shortcutDblClick = @(p) selectAndAssign(p.rowIdx)
}

function openAxisSetup(owner, axisItem) {
  closeAxisSetup()
  cur = {
    owner
    axisItem
    curJoyParams = owner.curJoyParams
    shortcuts = owner.shortcuts
    shortcutItems = owner.shortcutItems
    bindAxisNum = -1
    axisRawValues = []
    autodetectTime = 0.0
    numAxisInList = 0
    curShortcut = null
    changedShortcuts = []
    changedAxes = []
    dontCheckControlsDupes = refillControlsDupes()
  }
  resetAxisSetup()
  setAxisSetupField("title", loc($"controls/{axisItem.id}"))
  reinit()
  setAxisSetupField("isOpen", true)
  timerMsec = get_time_msec()
  setInterval(INPUT_TIMER_SEC, onInputTimer)
}


function updateAxisSetupParams(owner) {
  if (cur == null)
    return
  cur.curJoyParams = owner.curJoyParams
  cur.shortcuts = owner.shortcuts
  cur.shortcutItems = owner.shortcutItems
  let axisId = cur.axisItem.id
  cur.axisItem = shortcutsList.findvalue(@(s) s.id == axisId) ?? cur.axisItem
  reinit()
}

eventbus_subscribe("axisSetup.action", function(p) {
  if (cur == null)
    return
  if (!isOwnerValid())
    return closeAxisSetup()
  if (p.action == "close")
    return applyAxisSetup()
  ACTIONS?[p.action](p)
})
addListenersWithoutEnv({ AfterJoinEventRoom = @(_) closeAxisSetup() })
resetAxisSetup()

return freeze({
  openAxisSetup
  updateAxisSetupParams
  closeAxisSetup
})
