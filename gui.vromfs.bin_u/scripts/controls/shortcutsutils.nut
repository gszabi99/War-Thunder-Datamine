from "%scripts/controls/controlsCompatibility.nut" import setShortcutsAndSaveControls, joystickGetCurSettings, getShortcuts
from "%scripts/controls/controlsConsts.nut" import GAMEPAD_AXIS, MOUSE_AXIS, CONTROL_TYPE
from "%scripts/controls/input/button.nut" import Button
from "%scripts/controls/input/combination.nut" import Combination
from "%scripts/controls/shortcutViewConfig.nut" import getShortcutConfig
from "%scripts/controls/controlsState.nut" import getCurControlsPreset
from "%scripts/controls/shortcutsList/shortcutsList.nut" import getShortcutById
from "%scripts/options/optionsExt.nut" import get_option
from "%scripts/controls/aircraftHelpers.nut" import getCurrentHelpersMode
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%sqStdLibs/helpers/u.nut" import find_in_array
from "%sqstd/string.nut" import utf8ToLower
from "globalEnv" import ControlHelpersMode
from "%globalScripts/inputDeviceConsts.nut" import *
from "%scripts/dagui_library.nut" import *

let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { shortcutsList } = require("%scripts/controls/shortcutsList/shortcutsList.nut")

let axisMappedOnMouse = {
  elevator               = @(isMouseAimMode) isMouseAimMode ? MOUSE_AXIS.VERTICAL_AXIS : MOUSE_AXIS.NOT_AXIS
  ailerons               = @(isMouseAimMode) isMouseAimMode ? MOUSE_AXIS.HORIZONTAL_AXIS : MOUSE_AXIS.NOT_AXIS
  mouse_aim_x            = @(isMouseAimMode) isMouseAimMode ? MOUSE_AXIS.HORIZONTAL_AXIS : MOUSE_AXIS.NOT_AXIS
  mouse_aim_y            = @(isMouseAimMode) isMouseAimMode ? MOUSE_AXIS.VERTICAL_AXIS : MOUSE_AXIS.NOT_AXIS
  gm_mouse_aim_x         = @(_isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  gm_mouse_aim_y         = @(_isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  ship_mouse_aim_x       = @(_isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  ship_mouse_aim_y       = @(_isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  helicopter_mouse_aim_x = @(_isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  helicopter_mouse_aim_y = @(_isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  submarine_mouse_aim_x  = @(_isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  submarine_mouse_aim_y  = @(_isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  human_mouse_aim_x      = @(_isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  human_mouse_aim_y      = @(_isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  




  camx                   = @(_isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  camy                   = @(_isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  gm_camx                = @(_isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  gm_camy                = @(_isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  ship_camx              = @(_isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  ship_camy              = @(_isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  helicopter_camx        = @(_isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  helicopter_camy        = @(_isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  submarine_camx         = @(_isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  submarine_camy         = @(_isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  human_camx             = @(_isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  human_camy             = @(_isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  



}

function getMouseAxis(shortcutId, helpersMode = null, joyParams = null) {
  let axis = axisMappedOnMouse?[shortcutId]
  if (axis)
    return axis((helpersMode ?? getCurrentHelpersMode()) == ControlHelpersMode.EM_MOUSE_AIM)

  if (!joyParams)
    joyParams = joystickGetCurSettings()
  for (local i = 0; i < MouseAxis.NUM_MOUSE_AXIS_TOTAL; ++i) {
    if (shortcutId == joyParams.getMouseAxis(i))
      return 1 << min(i, MOUSE_AXIS.TOTAL - 1)
  }

  return MOUSE_AXIS.NOT_AXIS
}

function isAxisMappedOnMouse(shortcutId, helpersMode = null, joyParams = null) {
  return getMouseAxis(shortcutId, helpersMode, joyParams) != MOUSE_AXIS.NOT_AXIS
}

function isAxisBoundToMouse(shortcutId) {
  return isAxisMappedOnMouse(shortcutId)
}

function getBitArrayAxisIdByShortcutId(joyParams, shortcutId) {
  let shortcutData = getShortcutById(shortcutId)
  let axis = joyParams.getAxis(shortcutData?.axisIndex ?? -1)
  if (axis.axisId < 0)
    if (isAxisBoundToMouse(shortcutId))
      return getMouseAxis(shortcutId, null, joyParams)
    else
      return GAMEPAD_AXIS.NOT_AXIS

  return 1 << axis.axisId
}

function getComplexAxesId(shortcutComponents) {
  let joyParams = joystickGetCurSettings()
  local axesId = 0
  foreach (shortcutId in shortcutComponents)
    axesId = axesId | getBitArrayAxisIdByShortcutId(joyParams, shortcutId)

  return axesId
}






let isComponentsAssignedToSingleInputItem = @(axesId)
  axesId == GAMEPAD_AXIS.RIGHT_STICK
  || axesId == GAMEPAD_AXIS.LEFT_STICK
  || axesId == MOUSE_AXIS.MOUSE_MOVE

function getInputsParts(inputs) {
  let res = []
  foreach (input in inputs) {
    if (res.len() > 0)
      res.append({ text = loc("ui/comma") })
    res.append({ input = getShortcutConfig(input) })
  }
  return res
}

function getShortcutParts(shortcuts, shortcutId, cantBeEmpty = true, preset = null) {
  if (shortcuts?[shortcutId] == null)
    return cantBeEmpty ? [{ text = loc("ui/not_applicable") }] : []

  preset = preset ?? getCurControlsPreset()
  let inputs = []
  for (local i = 0; i < shortcuts[shortcutId].len(); i++) {
    let buttons = []
    let sc = shortcuts[shortcutId][i]

    for (local j = 0; j < sc.dev.len(); j++)
      buttons.append(Button(sc.dev[j], sc.btn[j], sc.activationType, preset))

    if (buttons.len() > 1)
      inputs.append(Combination(buttons))
    else
      inputs.extend(buttons)
  }

  let parts = getInputsParts(inputs)
  return cantBeEmpty && parts.len() == 0 ? [{ text = loc("ui/not_applicable") }] : parts
}

function isBindInShortcut(bind, shortcut) {
  foreach (sc in shortcut)
    if (sc.btn.len() == bind.btn.len()) {
      local same = true
      foreach (ib, btn in bind.btn) {
        let i = find_in_array(sc.btn, btn)
        if (i < 0 || sc.dev[i] != bind.dev[ib]) {
          same = false
          break
        }
      }
      if (same)
        return true
    }
  return false
}

function isShortcutEqual(sc1, sc2) {
  if (sc1.len() != sc2.len())
    return false

  foreach (_i, sb in sc2)
    if (!isBindInShortcut(sb, sc1))
      return false
  return true
}

function isShortcutDisplayEqual(sc1, sc2) {
  foreach (_i, sb in sc1)
    if (isBindInShortcut(sb, sc2))
      return true
  return false
}

function isShortcutMapped(shortcut) {
  foreach (button in shortcut)
    if (button && button.dev.len() >= 0)
      foreach (d in button.dev)
        if (d > 0 && d <= STD_GESTURE_DEVICE_ID)
            return true
  return false
}

function restoreShortcuts(scList, scNames) {
  let changeList = []
  let changeNames = []
  let curScList = getShortcuts(scNames)
  foreach (idx, sc in curScList) {
    let prevSc = scList[idx]
    if (!isShortcutMapped(prevSc))
      continue

    if (isShortcutEqual(sc, prevSc))
      continue

    changeList.append(prevSc)
    changeNames.append(scNames[idx])
  }
  if (!changeList.len())
    return

  setShortcutsAndSaveControls(changeList, changeNames)
  broadcastEvent("ControlsPresetChanged")
}

function hasMappedSecondaryWeaponSelector(unitType) {
  local shortcuts = []

  if (unitType == unitTypes.AIRCRAFT)
    shortcuts = getShortcuts([ "ID_FIRE_SECONDARY", "ID_SWITCH_SHOOTING_CYCLE_SECONDARY" ])
  else if (unitType == unitTypes.HELICOPTER)
    shortcuts = getShortcuts([ "ID_FIRE_SECONDARY_HELICOPTER", "ID_SWITCH_SHOOTING_CYCLE_SECONDARY_HELICOPTER" ])

  return (shortcuts.len() > 0)
    ? (isShortcutMapped(shortcuts[0]) && isShortcutMapped(shortcuts[1]))
    : false
}

function refillControlsDupes() {
  let arr = []
  for (local i = 0; i < shortcutsList.len(); i++) {
    let item = shortcutsList[i]
    if ((item.type == CONTROL_TYPE.SHORTCUT)
        && (item.isHidden || (("dontCheckDupes" in item) && item.dontCheckDupes)))
      arr.append(item.id)
  }
  return arr
}


function buildHotkeyItem(rowIdx, shortcuts, item, params) {
  let hotkeyData = {
    id = $"table_row_{rowIdx}"
    rowIdx
    itemId = item.id
    text = ""
    label = null
    control = null
  }

  if (("condition" in item) && !item.condition())
    return hotkeyData

  if (item.type == CONTROL_TYPE.SECTION) {
    let hotkeyId = $"hotkeys/{item.id}"
    return hotkeyData.__update({ text = utf8ToLower(loc(hotkeyId)), label = $"#{hotkeyId}" })
  }
  if (item.type == CONTROL_TYPE.SHORTCUT || item.type == CONTROL_TYPE.AXIS_SHORTCUT) {
    let trName = "".concat("hotkeys/", ((item.id == "") ? "enable" : item.id))
    return hotkeyData.__update({ text = utf8ToLower(loc(trName)), label = $"#{trName}",
      control = { kind = "shortcut", parts = getShortcutParts(shortcuts, item.shortcutId) } })
  }
  if (item.type == CONTROL_TYPE.AXIS && item.axisIndex >= 0) {
    let axisLocId = $"controls/{item.id}"
    return hotkeyData.__update({ text = utf8ToLower(loc(axisLocId)), label = $"#{axisLocId}",
      control = { kind = "shortcut", parts = [] } })
  }

  local labelLocId = $"controls/{item.id}"
  local control = null
  if (item.type == CONTROL_TYPE.SPINNER || item.type == CONTROL_TYPE.DROPRIGHT) {
    let kind = item.type == CONTROL_TYPE.DROPRIGHT ? "dropright" : "combobox"

    if ("optionType" in item) {
      let config = get_option(item.optionType)
      labelLocId = $"options/{config.id}"
      control = { kind, items = config.items, value = config.value }
    }
    else if ("options" in item && (item.options.len() > 0)) {
      let value = ("value" in item) ? item.value(params) : 0
      control = { kind, items = item.options, value }
    }
    else
      log("Error: No optionType nor options field");
  }
  else if (item.type == CONTROL_TYPE.SLIDER) {
    if ("optionType" in item) {
      let config = get_option(item.optionType)
      labelLocId = $"options/{config.id}"
      control = { kind = "slider", value = config.value, params = config }
    }
    else {
      let value = ("value" in item) ? item.value(params).tointeger() : 50
      control = { kind = "slider", value, params = item }
    }
  }
  else if (item.type == CONTROL_TYPE.SWITCH_BOX) {
    local config = null
    if ("optionType" in item) {
      config = get_option(item.optionType)
      labelLocId = $"options/{config.id}"
    }
    else
      config = { value = ("value" in item) ? item.value(params) : false }
    control = { kind = "switchbox", config }
  }
  else if (item.type == CONTROL_TYPE.MOUSE_AXIS && (item.values.len() > 0) && ("axis_num" in item)) {
    let value = params.getMouseAxis(item.axis_num)
    let options = []
    for (local i = 0; i < item.values.len(); i++)
      options.append($"#controls/{item.values[i]}")
    local sel = find_in_array(item.values, value)
    if (!(sel in item.values))
      sel = 0
    control = { kind = "combobox", items = options, value = sel }
  }
  else if (item.type == CONTROL_TYPE.BUTTON) {
    labelLocId = ""
    control = { kind = "button", text = $"#controls/{item.id}" }
  }
  else
    log($"Error: wrong shortcut - {item.id}")

  if (control == null)
    return hotkeyData
  return hotkeyData.__update({ text = utf8ToLower(loc(labelLocId)),
    label = labelLocId != "" ? $"#{labelLocId}" : "", control })
}

let getSliderValueText = @(item, value) "showValueMul" in item ? (item.showValueMul * value).tostring()
  : "".concat(value * (item?.showValuePercMul ?? 1), "%")

return freeze({
  getInputsParts
  getSliderValueText
  isAxisBoundToMouse
  getComplexAxesId
  isComponentsAssignedToSingleInputItem
  getShortcutParts
  isShortcutMapped
  restoreShortcuts
  hasMappedSecondaryWeaponSelector
  isBindInShortcut
  isShortcutDisplayEqual
  isAxisMappedOnMouse
  refillControlsDupes
  buildHotkeyItem
  getMouseAxis
})
