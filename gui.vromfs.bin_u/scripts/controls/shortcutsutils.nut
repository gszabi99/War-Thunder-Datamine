from "%scripts/dagui_library.nut" import *

let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { setShortcutsAndSaveControls, joystickGetCurSettings,
  getShortcuts } = require("%scripts/controls/controlsCompatibility.nut")
let { GAMEPAD_AXIS, MOUSE_AXIS } = require("%scripts/controls/controlsConsts.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { Button } = require("%scripts/controls/input/button.nut")
let { Combination } = require("%scripts/controls/input/combination.nut")
let { find_in_array } = require("%sqStdLibs/helpers/u.nut")
let { getCurControlsPreset } = require("%scripts/controls/controlsState.nut")
let { getShortcutById } = require("%scripts/controls/shortcutsList/shortcutsList.nut")

function isAxisBoundToMouse(shortcutId) {
  return ::is_axis_mapped_on_mouse(shortcutId)
}

function getBitArrayAxisIdByShortcutId(joyParams, shortcutId) {
  let shortcutData = getShortcutById(shortcutId)
  let axis = joyParams.getAxis(shortcutData?.axisIndex ?? -1)
  if (axis.axisId < 0)
    if (isAxisBoundToMouse(shortcutId))
      return ::get_mouse_axis(shortcutId, null, joyParams)
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

let getTextMarkup = @(symbol) symbol == "" ? ""
  : "".concat("textareaNoTab {text:t='<color=@axisSymbolColor>", symbol,
    "</color>'; position:t='relative'; top:t='0.45@kbh-0.5h'}")

function getInputsMarkup(inputs) {
  local res = ""
  foreach (input in inputs) {
    let curMk = input.getMarkup() ?? ""
    if (curMk != "")
      res = $"{res}{res != "" ? getTextMarkup(loc("ui/comma")) : ""}{curMk}"
  }

  return res
}

function getShortcutData(shortcuts, shortcutId, cantBeEmpty = true, preset = null) {
  if (shortcuts?[shortcutId] == null)
    return cantBeEmpty ? getTextMarkup(loc("ui/not_applicable")) : ""

  preset = preset ?? getCurControlsPreset()
  let inputs = []
  for (local i = 0; i < shortcuts[shortcutId].len(); i++) {
    let buttons = []
    let sc = shortcuts[shortcutId][i]

    for (local j = 0; j < sc.dev.len(); j++)
      buttons.append(Button(sc.dev[j], sc.btn[j], preset))

    if (buttons.len() > 1)
      inputs.append(Combination(buttons))
    else
      inputs.extend(buttons)
  }

  let markup = getInputsMarkup(inputs)
  return cantBeEmpty && markup == "" ? getTextMarkup(loc("ui/not_applicable")) : markup
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

return {
  getInputsMarkup
  isAxisBoundToMouse
  getComplexAxesId
  isComponentsAssignedToSingleInputItem
  getTextMarkup
  getShortcutData
  isShortcutMapped
  restoreShortcuts
  hasMappedSecondaryWeaponSelector
  isBindInShortcut
  isShortcutDisplayEqual
}
