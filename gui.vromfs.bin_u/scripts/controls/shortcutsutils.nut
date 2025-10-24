from "%scripts/dagui_library.nut" import *

let { format } = require("string")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { utf8ToLower } = require("%sqstd/string.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { setShortcutsAndSaveControls, joystickGetCurSettings,
  getShortcuts } = require("%scripts/controls/controlsCompatibility.nut")
let { GAMEPAD_AXIS, MOUSE_AXIS, CONTROL_TYPE } = require("%scripts/controls/controlsConsts.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { Button } = require("%scripts/controls/input/button.nut")
let { Combination } = require("%scripts/controls/input/combination.nut")
let { find_in_array } = require("%sqStdLibs/helpers/u.nut")
let { getCurControlsPreset } = require("%scripts/controls/controlsState.nut")
let { getShortcutById, shortcutsList } = require("%scripts/controls/shortcutsList/shortcutsList.nut")
let { create_option_dropright, create_option_list, create_option_slider, create_option_switchbox
} = require("%scripts/options/optionsCtors.nut")
let { get_option } = require("%scripts/options/optionsExt.nut")
let { getCurrentHelpersMode } = require("%scripts/controls/aircraftHelpers.nut")
let { ControlHelpersMode } = require("globalEnv")

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

let mkTextShortcutRow = kwarg(@(scId, id, trAdd, trName, scData = "")
  "\n".concat("tr { {0} ".subst(trAdd),
    "td { width:t='@controlsLeftRow'; overflow:t='hidden'; cellType:t='left'; optiontext{id:t='{0}'; text:t='{1}'; }}"
      .subst($"txt_{id}", trName),
    "td { width:t='pw-1@controlsLeftRow'; cellType:t='right'; padding-left:t='@optPad';",
      "cellSeparator{}",
      "shortcutCell { scId:t='{0}';".subst(scId),
        "on_hover:t='onScHover'; on_unhover:t='onScUnHover'; ",
        "on_click:t='onScClick'; on_dbl_click:t='onScDblClick'; ",
        "tdiv { id:t='{0}'; {1}}".subst($"sc_{id}", scData),
  "} } }\n"))

function buildHotkeyItem(rowIdx, shortcuts, item, params, rowParams = "") {
  let hotkeyData = {
    id = $"table_row_{rowIdx}"
    markup = ""
    text = ""
  }

  if (("condition" in item) && !item.condition())
    return hotkeyData

  let trAdd = format("id:t='%s'; optContainer:t='yes'; %s", hotkeyData.id, rowParams)
  local res = ""
  local elemTxt = ""
  local elemIdTxt =$"controls/{item.id}"

  if (item.type == CONTROL_TYPE.SECTION) {
    let hotkeyId =$"hotkeys/{item.id}"
    res = format(
      "".concat("tr { %s inactive:t='yes'; headerRow:t='yes';",
        "td { width:t='@controlsLeftRow'; overflow:t='visible';",
        "optionBlockHeader { text:t='#%s'; } }\n", "td { width:t='pw-1@controlsLeftRow';}\n",
        "optionHeaderLine {} }\n"),
      trAdd, hotkeyId)

    hotkeyData.text = utf8ToLower(loc(hotkeyId))
    hotkeyData.markup = res
  }
  else if (item.type == CONTROL_TYPE.SHORTCUT || item.type == CONTROL_TYPE.AXIS_SHORTCUT) {
    let trName = "".concat("hotkeys/", ((item.id == "") ? "enable" : item.id))
    res = mkTextShortcutRow({
      scId = rowIdx
      id = item.id
      trAdd = trAdd
      trName = $"#{trName}"
      scData = getShortcutData(shortcuts, item.shortcutId)
    })
    hotkeyData.text = utf8ToLower(loc(trName))
    hotkeyData.markup = res
  }
  else if (item.type == CONTROL_TYPE.AXIS && item.axisIndex >= 0) {
    res = mkTextShortcutRow({
      scId = rowIdx
      id = item.id
      trAdd = trAdd
      trName = $"#controls/{item.id}"
    })
    hotkeyData.text = utf8ToLower(loc($"controls/{item.id}"))
    hotkeyData.markup = res
  }
  else if (item.type == CONTROL_TYPE.SPINNER || item.type == CONTROL_TYPE.DROPRIGHT) {
    local createOptFunc = create_option_list
    if (item.type == CONTROL_TYPE.DROPRIGHT)
      createOptFunc = create_option_dropright

    let callBack = ("onChangeValue" in item) ? item.onChangeValue : null

    if ("optionType" in item) {
      let config = get_option(item.optionType)
      elemIdTxt =$"options/{config.id}"
      elemTxt = createOptFunc(item.id, config.items, config.value, callBack, true)
    }
    else if ("options" in item && (item.options.len() > 0)) {
      let value = ("value" in item) ? item.value(params) : 0
      elemTxt = createOptFunc(item.id, item.options, value, callBack, true)
    }
    else
      log("Error: No optionType nor options field");
  }
  else if (item.type == CONTROL_TYPE.SLIDER) {
    if ("optionType" in item) {
      let config = get_option(item.optionType)
      elemIdTxt =$"options/{config.id}"
      elemTxt = create_option_slider(item.id, config.value, "onSliderChange", true,
        "slider", config.__merge({ needShowValueText = false }))
    }
    else {
      let value = ("value" in item) ? item.value(params) : 50
      elemTxt = create_option_slider(item.id, value.tointeger(), "onSliderChange", true, "slider", item)
    }

    elemTxt = "".concat(
      elemTxt,
      format("activeText{ id:t='%s'; margin-left:t='0.01@sf' } ", $"{item.id}_value"))
  }
  else if (item.type == CONTROL_TYPE.SWITCH_BOX) {
    local config = null
    if ("optionType" in item) {
      config = get_option(item.optionType)
      elemIdTxt =$"options/{config.id}"
      config.id = item.id
    }
    else {
      let value = ("value" in item) ? item.value(params) : false
      config = {
        id = item.id
        value = value
      }
    }
    config.cb <- getTblValue("onChangeValue", item)
    elemTxt = create_option_switchbox(config)
  }
  else if (item.type == CONTROL_TYPE.MOUSE_AXIS && (item.values.len() > 0) && ("axis_num" in item)) {
    let value = params.getMouseAxis(item.axis_num)
    let callBack = ("onChangeValue" in item) ? item.onChangeValue : null
    let options = []
    for (local i = 0; i < item.values.len(); i++)
      options.append($"#controls/{item.values[i]}")
    local sel = find_in_array(item.values, value)
    if (!(sel in item.values))
      sel = 0
    elemTxt = create_option_list(item.id, options, sel, callBack, true)
  }
  else if (item.type == CONTROL_TYPE.BUTTON) {
    elemIdTxt = "";
    elemTxt = handyman.renderCached("%gui/commonParts/button.tpl", {
      id = item.id
      text =$"#controls/{item.id}"
      funcName = "onActionButtonClick"
    })
  }
  else {
    res = "tr { display:t='hide'; td {} td { tdiv{} } }"
    log($"Error: wrong shortcut - {item.id}")
  }

  if (elemTxt != "") {
    let elemCellWidth = item.type == CONTROL_TYPE.SHORTCUT || item.type == CONTROL_TYPE.AXIS_SHORTCUT
      ? "pw-1@controlsLeftRow" : "@optContainerRightCellWidth"
    res = format(
      "".concat(
          "tr { css-hier-invalidate:t='all'; width:t='pw'; %s ",
          "td { width:t='@controlsLeftRow'; cellType:t='left'; overflow:t='hidden'; optiontext { text:t ='%s'; }} ",
          $"td \{ width:t='{elemCellWidth}'; cellType:t='right'; padding-left:t='@optPad'; cellSeparator\{\} %s \} ",
          "}\n"),
      trAdd, elemIdTxt != "" ? $"#{elemIdTxt}" : "", elemTxt)
    hotkeyData.text = utf8ToLower(loc(elemIdTxt))
    hotkeyData.markup = res
  }
  return hotkeyData
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
  isAxisMappedOnMouse
  refillControlsDupes
  buildHotkeyItem
  getMouseAxis
}
