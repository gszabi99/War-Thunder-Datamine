import "%sqStdLibs/helpers/u.nut" as u
import "controllerState" as controllerState
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/controls/controlsBackupManager.nut" import ControlsBackupManager
from "%scripts/genericOptions.nut" import GenericOptions
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/baseGuiHandlerManagerWT.nut" import loadHandler, handlersManager
from "%scripts/controls/controlsConsts.nut" import AXIS_MODIFIERS, MAX_SHORTCUTS, CONTROL_TYPE, AIR_MOUSE_USAGE, HELP_CONTENT_SET
from "%scripts/wheelmenu/voiceMessages.nut" import resetFastVoiceMessages
from "%sqstd/platform.nut" import is_windows, isPC, isSony, isXbox
from "%appGlobals/clientState/platform.nut" import isPlatformShieldTv
from "%scripts/breadcrumb.nut" import setBreadcrumbGoBackParams, getBackSceneName
from "%scripts/slotbar/playerCurUnit.nut" import getPlayerCurUnit
from "%scripts/controls/shortcutsUtils.nut" import getShortcutParts, getInputsParts, isShortcutMapped, isAxisMappedOnMouse, refillControlsDupes, buildHotkeyItem, getSliderValueText
from "%scripts/controls/controlsUtils.nut" import getControlsPresetBySelectedType, canChangeHelpersMode, gui_modal_controlsWizard
from "%scripts/controls/controlsCompatibility.nut" import joystickSetCurSettings, setShortcutsAndSaveControls, joystickGetCurSettings, getShortcuts
from "%scripts/onlineShop/url.nut" import openUrl
from "%scripts/options/optionsExt.nut" import set_option, get_option
from "%scripts/options/consoleMode.nut" import showConsoleButtons
from "%scripts/options/optionsExtNames.nut" import OPTIONS_MODE_GAMEPLAY, USEROPT_HELPERS_MODE, USEROPT_CONTROLS_PRESET, USEROPT_MOUSE_USAGE, USEROPT_MOUSE_USAGE_NO_AIM
from "%scripts/controls/controlsVisual.nut" import remapAxisName
from "%scripts/controls/startControls.nut" import switchControlsMode, gui_start_controls_type_choice
from "%scripts/controls/input/button.nut" import Button
from "%scripts/controls/input/combination.nut" import Combination
from "%scripts/controls/input/axis.nut" import Axis
from "%scripts/help/helpWnd.nut" import gui_modal_help
from "%scripts/controls/assignShortcut.nut" import openAssignShortcut
from "%scripts/controls/axisSetup.nut" import openAxisSetup, updateAxisSetupParams, closeAxisSetup
from "%scripts/controls/aircraftHelpers.nut" import getAircraftHelpersOptionValue, setAircraftHelpersOptionValue, getCurrentHelpersMode
from "%scripts/controls/controlsPresets.nut" import parseControlsPresetName, getHighestVersionControlsPreset
from "%scripts/controls/controlsState.nut" import getCurControlsPreset, isPresetChanged, clearControlsPresetGuiOptions
from "%scripts/controls/shortcutsList/shortcutsList.nut" import getShortcutById
from "%scripts/controls/controlsManager.nut" import restoreHardcodedKeys, isLastLoadControlsSucceeded
from "%scripts/controls/controlsTypeUtils.nut" import applyJoyPresetXchange
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%appGlobals/curCircuitOverride.nut" import getCurCircuitOverride
from "%appGlobals/controls/controlsScreenState.nut" import controlsScreen, controlsItems, setControlsScreenField,
  setControlsItem, resetControlsScreen
from "%scripts/dargScreenBridge.nut" import locText, mkControlObj, subscribeScreenActions
from "%scripts/controls/controlRowsView.nut" import mkViewRows
from "string" import format
from "globalEnv" import ControlHelpersMode, setControlHelpersMode
from "guiOptions" import setGuiOptionsMode, getGuiOptionsMode
from "mission" import get_game_mode
from "modules" import on_module_unload
from "%sqstd/string.nut" import utf8ToLower
from "controlsOptions" import set_option_mouse_joystick_square, set_option_mouse_joystick_square_helicopter
from "%scripts/dagui_library.nut" import *
from "%globalScripts/gameModeNativeConsts.nut" import *
from "%scripts/dagui_natives.nut" import set_current_controls, import_current_layout_by_path, import_current_layout, set_option_gain, fetch_devices_inited_once, get_save_load_path, get_axis_index
  , export_current_layout, export_current_layout_by_path
from "gameOptions" import *
from "types" import Function
from "%scripts/controls/activeInputDevice.nut" import locByInputDevice

let { g_shortcut_type } = require("%scripts/controls/shortcutType.nut")
let { FileDialog } = require("%scripts/fileDialog/fileDialog.nut")
let shortcutsAxisListModule = require("%scripts/controls/shortcutsList/shortcutsAxis.nut")
let { unitClassType } = require("%scripts/unit/unitClassType.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { recommendedControlPresets } = require("%scripts/controls/controlsUtils.nut")
let { userOptionNameByIdx } = require("%scripts/options/optionsExtNames.nut")
let { controlHelpersOptions } = require("%scripts/controls/aircraftHelpers.nut")

let { shortcutsList } = require("%scripts/controls/shortcutsList/shortcutsList.nut")

let METHOD_BY_BUTTON = {
  btn_back = "goBack"
  btn_apply = "onApply"
  btn_switchMode = "onSwitchModeButton"
  btn_controlsWizard = "onControlsWizard"
  btn_controlsHelp = "onControlsHelp"
  btn_clearAll = "onClearAll"
  btn_exportToFile = "onExportToFile"
  btn_importFromFile = "onImportFromFile"
  btn_backupManager = "onManageBackup"
  btn_controls_workshop_online = "onControlsWorkshop"
  btn_reset_shortcut = "onButtonReset"
  btn_reset_axis = "onButtonReset"
  btn_assign = "onTblDblClick"
}

function getAxisActivationShortcutParts(shortcuts, item, preset) {
  preset = preset ?? getCurControlsPreset()
  let inputs = []
  let axisDescr = g_shortcut_type._getDeviceAxisDescription(item.id)
  let axisInput = (axisDescr.axisId > -1 || axisDescr.mouseAxis != null)
    ? Axis(axisDescr, AXIS_MODIFIERS.NONE, preset)
    : null
  let buttons = axisInput ? [axisInput] : []
  let scArr = shortcuts[item.modifiersId[""]]
  for (local i = 0; i < scArr.len(); i++) {
    let sc = scArr[i]
    for (local j = 0; j < sc.dev.len(); j++)
      buttons.append(Button(sc.dev[j], sc.btn[j], sc.activationType, preset))

    if (buttons.len() > 1)
      inputs.append(Combination(buttons))
    else
      inputs.extend(buttons)
  }
  
  if (scArr.len() == 0 && axisInput)
    inputs.append(axisInput)

  return getInputsParts(inputs)
}

function resetDefaultControlSettings() {
  set_option_multiplier(OPTION_AILERONS_MULTIPLIER,         0.79); 
  set_option_multiplier(OPTION_ELEVATOR_MULTIPLIER,         0.64); 
  set_option_multiplier(OPTION_RUDDER_MULTIPLIER,           0.43); 
  set_option_multiplier(OPTION_HELICOPTER_CYCLIC_ROLL_MULTIPLIER,   0.79); 
  set_option_multiplier(OPTION_HELICOPTER_CYCLIC_PITCH_MULTIPLIER,  0.64); 
  set_option_multiplier(OPTION_HELICOPTER_PEDALS_MULTIPLIER,        0.43); 
  set_option_multiplier(OPTION_ZOOM_SENSE,                  0); 
  set_option_multiplier(OPTION_MOUSE_SENSE,                 0.5); 
  set_option_multiplier(OPTION_HUMAN_MOUSE_SENSE,           0.5); 
  set_option_multiplier(OPTION_MOUSE_AIM_SENSE,             0.5); 
  set_option_multiplier(OPTION_GUNNER_VIEW_SENSE,           1); 
  set_option_multiplier(OPTION_ATGM_AIM_SENS_HELICOPTER,    1); 
  set_option_multiplier(OPTION_MOUSE_JOYSTICK_DEADZONE,     0.1); 
  set_option_multiplier(OPTION_HELICOPTER_MOUSE_JOYSTICK_DEADZONE,     0.1);
  set_option_multiplier(OPTION_MOUSE_JOYSTICK_SCREENSIZE,   0.6); 
  set_option_multiplier(OPTION_HELICOPTER_MOUSE_JOYSTICK_SCREENSIZE,   0.6);
  set_option_multiplier(OPTION_MOUSE_JOYSTICK_SENSITIVITY,  2); 
  set_option_multiplier(OPTION_HELICOPTER_MOUSE_JOYSTICK_SENSITIVITY,  2);
  set_option_multiplier(OPTION_MOUSE_JOYSTICK_SCREENPLACE,  0); 
  set_option_multiplier(OPTION_HELICOPTER_MOUSE_JOYSTICK_SCREENPLACE,  0);
  set_option_multiplier(OPTION_MOUSE_AILERON_RUDDER_FACTOR, 0.5); 
  set_option_multiplier(OPTION_HELICOPTER_MOUSE_AILERON_RUDDER_FACTOR, 0.5);
  set_option_multiplier(OPTION_CAMERA_SMOOTH,               0); 
  set_option_multiplier(OPTION_CAMERA_SPEED,                1.13); 
  set_option_multiplier(OPTION_CAMERA_MOUSE_SPEED,          4); 
  set_option_multiplier(OPTION_AIM_TIME_NONLINEARITY_AIR,        0.0); 
  set_option_multiplier(OPTION_AIM_TIME_NONLINEARITY_HELICOPTER, 0.0); 
  set_option_multiplier(OPTION_AIM_TIME_NONLINEARITY_TANK,       0.0); 
  set_option_multiplier(OPTION_AIM_TIME_NONLINEARITY_SHIP,       0.0); 
  set_option_multiplier(OPTION_AIM_TIME_NONLINEARITY_SUBMARINE,  0.0); 
  set_option_multiplier(OPTION_AIM_TIME_NONLINEARITY_HUMAN,      0.0); 
  set_option_multiplier(OPTION_AIM_ACCELERATION_DELAY_AIR,        0.5); 
  set_option_multiplier(OPTION_AIM_ACCELERATION_DELAY_HELICOPTER, 0.5); 
  set_option_multiplier(OPTION_AIM_ACCELERATION_DELAY_TANK,       0.5); 
  set_option_multiplier(OPTION_AIM_ACCELERATION_DELAY_SHIP,       0.5); 
  set_option_multiplier(OPTION_AIM_ACCELERATION_DELAY_SUBMARINE,  0.5); 
  set_option_multiplier(OPTION_AIM_ACCELERATION_DELAY_HUMAN,      0.5); 

  set_option_mouse_joystick_square(false); 
  set_option_mouse_joystick_square_helicopter(false);
  set_option_gain(1); 
}


let Hotkeys = class (GenericOptions) {
  wndType = handlerType.BASE
  sceneBlkName = "%gui/controlsDargShell.blk"
  sceneNavBlkName = null

  filterValues = null
  filterObjId = null
  filter = null
  lastFilter = null

  shownControlKinds = null

  shortcuts = null
  shortcutNames = null
  shortcutItems = null
  modifierSymbols = null
  axisScNames = null

  dontCheckControlsDupes = null

  inputBox = null

  curJoyParams = null
  backAfterSave = true

  bindAxisNum = -1
  joysticks = null

  controlsGroupsIdList = []
  curGroupId = ""

  forceLoadWizard = false
  changeControlsMode = false
  applyApproved = false

  isAircraftHelpersChangePerformed = false

  filledControlGroupTab = null

  curShortcut = null

  getWidgetsList = @() [{ widgetId = DargWidgets.SCREEN, screen = "controls" }]

  function initScreen() {
    resetControlsScreen()
    this.shownControlKinds = {}
    setBreadcrumbGoBackParams(this)
    this.mainOptionsMode = getGuiOptionsMode()
    setGuiOptionsMode(OPTIONS_MODE_GAMEPLAY)

    this.scene.findObject("hotkeys_update").setUserData(this)

    this.shortcuts = []
    this.shortcutNames = []
    this.shortcutItems = []
    this.dontCheckControlsDupes = []

    this.initMainParams()

    if (!fetch_devices_inited_once())
      gui_start_controls_type_choice()

    setControlsScreenField("backSceneName", getBackSceneName())
  }

  function onDestroy() {
    closeAxisSetup()
  }

  function onSwitchModeButton() {
    this.changeControlsWindowType(true)
    this.goBack()
  }

  function initMainParams() {
    this.initShortcutsNames()
    this.curJoyParams = joystickGetCurSettings()
    this.updateButtons()

    restoreHardcodedKeys(MAX_SHORTCUTS)
    this.shortcuts = getShortcuts(this.shortcutNames)

    this.fillControlsType()
  }

  function setNavItems(navItems) {
    let items = navItems.map(@(n) { id = n.id, text = locText(n?.text ?? n.id) })
    controlsScreen.mutate(function(s) {
      s.navItems = items
      s.curNavIdx = 0
    })
  }

  getNavItems = @() controlsScreen.get().navItems

  function setCurrentNavItem(navItem) {
    let idx = this.getNavItems().indexof(navItem)
    if (idx != null)
      setControlsScreenField("curNavIdx", idx)
  }

  function fillFilterObj() {
    if (this.filterValues && this.getHelpersFilterItemsCount() == this.filterValues.len() && !isPresetChanged.get())
      return 

    local modsBlock = null
    foreach (block in shortcutsList)
      if ("isFilterObj" in block && block.isFilterObj) {
        modsBlock = block
        break
      }

    if (modsBlock == null)
      return

    let options = get_option(modsBlock.optionType)

    this.filterObjId = modsBlock.id
    this.filterValues = options.values

    let items = []
    foreach (idx, item in options.items)
      items.append({
        id = $"option_{options.values[idx]}"
        text = item.text
        selected = options.value == idx
        tooltip = item.tooltip
      })

    this.showHelpersFilter(items)
    this.onOptionsFilter()
  }

  getHelpersFilterItemsCount = @() controlsScreen.get().helpersFilter.len()
  getHelpersFilterIdx = @() this.filterObjId == null ? null : controlsScreen.get().helpersFilterIdx
  showHelpersFilterBlock = @(isShown) setControlsScreenField("isHelpersFilterShown", isShown)

  function showHelpersFilter(items) {
    let helpersFilter = items.map(@(i) { id = i.id, text = locText(i.text), tooltip = locText(i?.tooltip) })
    let idx = items.findindex(@(i) i.selected) ?? -1
    controlsScreen.mutate(function(s) {
      s.helpersFilter = helpersFilter
      s.helpersFilterIdx = idx
    })
  }

  function setHelpersFilterIdx(idx) {
    if (this.filterObjId == null || idx == controlsScreen.get().helpersFilterIdx)
      return
    setControlsScreenField("helpersFilterIdx", idx)
    this.onOptionsFilter(mkControlObj(this, this.filterObjId))
  }

  function fillControlsType() {
    this.fillFilterObj()
  }

  function applySearchText() {
    if (u.isEmpty(this.filledControlGroupTab))
      return

    let filterText = utf8ToLower(this.getSearchText())

    local parentId = ""
    let isShownByRowId = {}
    foreach (_idx, data in this.filledControlGroupTab) {
      local show = filterText == "" || data.text.indexof(filterText) != null
      if(show && data?.isHeader == true)
        parentId = data.id
      if(parentId != "" && data?.parentId == parentId)
        show = true
      isShownByRowId[data.id] <- show
    }
    
    
    let { rows } = controlsScreen.get()
    controlsItems.mutate(function(items) {
      foreach (row in rows) {
        let shown = !shortcutsList[row.rowIdx].isHidden && (isShownByRowId?[row.id] ?? true)
        if (items?[row.itemId]?.shown != shown)
          items[row.itemId] <- (items?[row.itemId] ?? {}).__merge({ shown })
      }
    })
  }

  getSearchText = @() controlsScreen.get().searchText

  function setSearchText(text) {
    if (text == controlsScreen.get().searchText)
      return
    setControlsScreenField("searchText", text)
    this.applySearchText()
  }

  function onSearchCancel() {
    if (this.getSearchText() != "")
      this.resetSearch()
    else
      this.guiScene.performDelayed(this, function() {
        if (this.isValid())
          this.goBack()
      })
  }

  function resetSearch() {
    this.setSearchText("")
  }

  function isScriptOpenFileDialogAllowed() {
    return hasFeature("ScriptImportExportControls")
  }

  function updateButtons() {
    let isTutorial = get_game_mode() == GM_TRAINING
    let isImportExportAllowed = !isTutorial
      && (this.isScriptOpenFileDialogAllowed() || is_windows)

    this.showSceneItem("btn_exportToFile", isImportExportAllowed)
    this.showSceneItem("btn_importFromFile", isImportExportAllowed)
    this.showSceneItem("btn_switchMode", isSony || isXbox || isPlatformShieldTv())
    this.showSceneItem("btn_backupManager", ControlsBackupManager.isAvailable())
    this.showSceneItem("btn_controlsWizard", hasFeature("ControlsPresets"))
    this.showSceneItem("btn_clearAll", !isTutorial)
    this.showSceneItem("btn_controlsHelp", hasFeature("ControlsHelp"))
    this.showSceneItem("btn_controls_workshop_online", isPC)
  }

  showSceneItem = @(id, isShown) setControlsItem(id, "shown", isShown)
  setNavButtonText = @(id, text) setControlsItem(id, "value", text)

  function fillControlGroupsList() {
    local curValue = 0
    this.controlsGroupsIdList = []
    let currentUnit = getPlayerCurUnit()
    local unitType = unitTypes.INVALID
    local classType = unitClassType.UNKNOWN
    local unitTags = []
    if (this.curGroupId == "" && currentUnit) {
      unitType = currentUnit.unitType
      classType = currentUnit.expClass
      unitTags = (currentUnit?.tags ?? [])
    }

    for (local i = 0; i < shortcutsList.len(); i++)
      if (shortcutsList[i].type == CONTROL_TYPE.HEADER) {
        let header = shortcutsList[i]
        if ("filterShow" in header)
          if (!isInArray(this.filter, header.filterShow))
            continue
        if ("showFunc" in header)
          if (!header.showFunc.bindenv(this)())
            continue

        this.controlsGroupsIdList.append(header.id)
        local isSuitable = unitType != unitTypes.INVALID
          && (header?.unitTypes.contains(unitType) ?? false)
        if (isSuitable && "unitClassTypes" in header)
          isSuitable = isInArray(classType, header.unitClassTypes)
        if (isSuitable && "unitTag" in header)
          isSuitable = isInArray(header.unitTag, unitTags)
        if (isSuitable)
          this.curGroupId = header.id
        if (header.id == this.curGroupId)
          curValue = this.controlsGroupsIdList.len() - 1
      }

    this.showControlGroupTabs(curValue)
  }

  function showControlGroupTabs(curIdx) {
    let groupTabs = this.controlsGroupsIdList.map(@(id) { id, text = loc($"hotkeys/{id}") })
    controlsScreen.mutate(function(s) {
      s.groupTabs = groupTabs
      s.curGroupIdx = curIdx
    })
    this.onControlsGroupChange()
  }

  getControlGroupTabIdx = @() controlsScreen.get().curGroupIdx

  function onControlsGroupChange() {
    this.doControlsGroupChange()
  }

  function doControlsGroupChange(forceUpdate = false) {
    if (!checkObj(this.scene))
      return

    local groupId = this.getControlGroupTabIdx()
    if (groupId < 0)
      groupId = 0

    if (!(groupId in this.controlsGroupsIdList))
      return

    let newGroupId = this.controlsGroupsIdList[groupId]
    let isGroupChanged = this.curGroupId != newGroupId
    if (!isGroupChanged && this.filter == this.lastFilter && !isPresetChanged.get() && !forceUpdate)
      return

    this.lastFilter = this.filter
    if (!isPresetChanged.get())
      this.doApplyJoystick()
    this.curGroupId = newGroupId
    this.fillControlGroupTab(this.curGroupId)
  }

  function getControlGroupTabData(groupId) {
    let joyParams = joystickGetCurSettings();
    local isSectionShowed = true
    local isHelpersVisible = false

    let navigationItems = []
    let rows = []
    local headerId = ""

    for (local n = 0; n < shortcutsList.len(); n++) {
      if (shortcutsList[n].id != groupId)
        continue

      isHelpersVisible = shortcutsList[n]?.isHelpersVisible
      for (local i = n + 1; i < shortcutsList.len(); i++) {
        let entry = shortcutsList[i]
        if (entry.type == CONTROL_TYPE.HEADER)
          break
        if (entry.type == CONTROL_TYPE.SECTION) {
          isSectionShowed =
            (!("filterHide" in entry) || !isInArray(this.filter, entry.filterHide)) &&
            (!("filterShow" in entry) || isInArray(this.filter, entry.filterShow)) &&
            (!("showFunc" in entry) || entry.showFunc.call(this))
          if (isSectionShowed)
            navigationItems.append({
              id = entry.id
              text =$"#hotkeys/{entry.id}"
            })
        }
        if (!isSectionShowed)
          continue

        let hotkeyData = buildHotkeyItem(i, this.shortcuts, entry, joyParams)
        if(entry.type == CONTROL_TYPE.SECTION) {
          headerId = hotkeyData.id
          hotkeyData.isHeader <- true
        }
        else
          hotkeyData.parentId <- headerId
        rows.append(hotkeyData)
      }

      break
    }
    return { rows, navigationItems, isHelpersVisible }
  }

  function fillControlGroupTab(groupId) {
    let { rows, navigationItems, isHelpersVisible } = this.getControlGroupTabData(groupId)
    this.filledControlGroupTab = rows
    this.showControlRows(rows)
    this.showHelpersFilterBlock(isHelpersVisible)
    this.setNavItems(navigationItems)
    this.updateSceneOptions()
    this.updateHidden()
    this.dontCheckControlsDupes = refillControlsDupes()
    this.applySearchText()
  }

  function showControlRows(rows) {
    let { viewRows, items, kinds } = mkViewRows(rows)
    this.shownControlKinds = kinds
    
    controlsItems.mutate(@(v) v.__update(items))
    this.curShortcut = null
    controlsScreen.mutate(function(s) {
      s.rows = viewRows
      s.selectedRowId = null
    })
    this.updateButtonsChangeValue()
  }

  function checkCurrentNavagationSection() {
    let item = this.getCurItem()
    if (!item)
      return

    let navItems = this.getNavItems()
    if (navItems.len() > 1) {
      local navId = null
      for (local i = 0; i < shortcutsList.len(); i++) {
        let entry = shortcutsList[i]
        if (entry.type == CONTROL_TYPE.SECTION)
          navId = entry.id
        if (entry.id != item.id)
          continue

        let curItem = u.search(navItems, @(it) it.id == navId)
        if (curItem != null)
          this.setCurrentNavItem(curItem)

        break
      }
    }
  }

  function onUpdate(_obj, _dt) {
    if (!isPresetChanged.get())
      return

    this.initMainParams()
    updateAxisSetupParams(this)
    isPresetChanged.set(false)
    if (this.forceLoadWizard) {
      this.forceLoadWizard = false
      this.onControlsWizard()
    }
  }

  function initShortcutsNames() {
    let axisScNames = []
    this.modifierSymbols = {}

    foreach (item in shortcutsAxisListModule.types) {
      if (item.type != CONTROL_TYPE.AXIS_SHORTCUT || isInArray(item.id, axisScNames))
        continue

      axisScNames.append(item.id)
      if ("symbol" in item)
        this.modifierSymbols[item.id] <- $"{loc(item.symbol)}{loc("ui/colon")}"
    }
    this.axisScNames = axisScNames

    this.shortcutNames = []
    this.shortcutItems = []

    let addShortcutNames = function(arr) {
      for (local i = 0; i < arr.len(); i++)
        if (arr[i].type == CONTROL_TYPE.SHORTCUT) {
          arr[i].shortcutId = this.shortcutNames.len()
          this.shortcutNames.append(arr[i].id)
          this.shortcutItems.append(arr[i])
        }
    }
    addShortcutNames(shortcutsList)
    addShortcutNames(shortcutsAxisListModule.types)

    for (local i = 0; i < shortcutsList.len(); i++) {
      let item = shortcutsList[i]

      if (item.type != CONTROL_TYPE.AXIS)
        continue

      item.modifiersId = {}
      foreach (name in axisScNames) {
        item.modifiersId[name] <- this.shortcutNames.len()
        this.shortcutNames.append($"{item.axisName}{name == "" ? "" : "_"}{name}")
        this.shortcutItems.append(item)
      }
    }
  }

  function getSymbol(name) {
    if (name in this.modifierSymbols)
      return this.modifierSymbols[name]
    return ""
  }

  function updateAxisShortcuts(item) {
    if (!this.isShortcutCellShown(item.id))
      return

    let parts = []
    let curPreset = getCurControlsPreset()
    if ("modifiersId" in item) {
      if ("" in item.modifiersId && item.modifiersId[""] in this.shortcuts) {
        let activationParts = getAxisActivationShortcutParts(this.shortcuts, item, curPreset)
        if (activationParts.len() > 0)
          parts.append({ text = this.getSymbol("") }).extend(activationParts)
      }
      
      foreach (modifier in this.axisScNames)
        if (modifier != "" && modifier in item.modifiersId) {
          let scParts = getShortcutParts(this.shortcuts, item.modifiersId[modifier], false, curPreset)
          if (scParts.len() == 0)
            continue
          if (parts.len() > 0)
            parts.append({ text = loc("ui/semicolon") })
          parts.append({ text = this.getSymbol(modifier) }).extend(scParts)
        }
    }

    if (parts.len() == 0)
      parts.append({ text = loc("joystick/axis_not_assigned") })

    this.showShortcutCell(item.id, parts)
  }

  isShortcutCellShown = @(id) this.shownControlKinds?[id] == "shortcut"
  showShortcutCell = @(id, parts) setControlsItem(id, "cell", parts)

  function updateSceneOptions() {
    for (local i = 0; i < shortcutsList.len(); i++) {
      if (shortcutsList[i].type == CONTROL_TYPE.AXIS && shortcutsList[i].axisIndex >= 0)
        this.updateAxisShortcuts(shortcutsList[i])
      else if (shortcutsList[i].type == CONTROL_TYPE.SLIDER)
        this.updateSliderValue(shortcutsList[i])
    }
  }

  getCurItem = @() this.curShortcut
  getScById = @(scId) shortcutsList?[(scId ?? "-1").tointeger()]

  function onScHover(obj) {
    if (!showConsoleButtons.get())
      return
    this.curShortcut = this.getScById(obj?.scId)
    this.updateButtonsChangeValue()
  }

  function onScUnHover(obj) {
    if (!showConsoleButtons.get() || this.curShortcut != this.getScById(obj?.scId))
      return
    this.curShortcut = null
    this.updateButtonsChangeValue()
  }

  function onShortcutClick(rowIdx, byGamepad = false) {
    let sc = this.getScById(rowIdx)
    if (sc == null)
      return
    
    let isConsole = showConsoleButtons.get()
    this.curShortcut = sc == this.curShortcut && !isConsole ? null : sc
    setControlsScreenField("selectedRowId", this.curShortcut == null ? null : $"table_row_{rowIdx}")
    this.updateButtonsChangeValue()
    if (isConsole && byGamepad)
      this.onTblDblClick()
  }

  function onShortcutDblClick(rowIdx) {
    let sc = this.getScById(rowIdx)
    if (sc == null)
      return
    if (sc != this.curShortcut)
      this.onShortcutClick(rowIdx)
    this.onTblDblClick()
  }

  function applyAirHelpersChange(obj = null) {
    if (this.isAircraftHelpersChangePerformed)
      return
    this.isAircraftHelpersChangePerformed = true

    if (checkObj(obj)) {
      let valueIdx = obj.getValue()
      local item = null
      for (local i = 0; i < shortcutsList.len(); i++)
        if (obj?.id == shortcutsList[i].id) {
          item = shortcutsList[i]
          break
        }
      if (item != null && "optionType" in item)
        set_option(item.optionType, valueIdx)
    }

    let options = u.values(controlHelpersOptions)
    foreach (optionId in options) {
      if (optionId == USEROPT_HELPERS_MODE)
        continue
      let option = get_option(optionId)
      for (local i = 0; i < shortcutsList.len(); i++)
        if (shortcutsList[i]?.optionType == optionId) {
          let value = this.getControlItemValue(shortcutsList[i])
          if (value != null && value != option.value)
            this.setControlValue(shortcutsList[i].id, option.value)
        }
    }

    this.curJoyParams.mouseJoystick = (getCurControlsPreset().params?.mouseJoystick ?? false)

    this.isAircraftHelpersChangePerformed = false
  }

  function onAircraftHelpersChanged(obj = null) {
    if (this.isAircraftHelpersChangePerformed)
      return

    this.applyAirHelpersChange(obj)
    this.doControlsGroupChangeDelayed(obj)
  }

  function onOptionsFilter(obj = null) {
    this.applyAirHelpersChange(obj)

    let filterId = this.getHelpersFilterIdx()
    if (filterId == null || !(filterId in this.filterValues))
      return

    if (!canChangeHelpersMode() && this.filter != null) {
      foreach (idx, value in this.filterValues)
        if (value == this.filter) {
          if (idx != filterId) {
            let newValue = idx
            this.msgBox("cant_change_controls", loc("msgbox/tutorial_controls_type_locked"),
                   [["ok", @() this.setHelpersFilterIdx(newValue)]], "ok")
          }
          break
        }
      return
    }
    setControlHelpersMode(filterId);
    this.filter = this.filterValues[filterId];
    this.fillControlGroupsList();
    
  }

  delayedControlsGroupStrated = false
  function doControlsGroupChangeDelayed(_obj = null) {
    this.delayedControlsGroupStrated = true
    this.guiScene.performDelayed(this, function() {
      this.delayedControlsGroupStrated = false
      let filterOption = get_option(USEROPT_HELPERS_MODE)
      let filterIdx = this.getHelpersFilterIdx()
      if (filterIdx != null && filterIdx != filterOption.value)
        this.setHelpersFilterIdx(filterOption.value)
      this.doControlsGroupChange(true)
    })
  }

  function updateHidden() {
    for (local i = 0; i < shortcutsList.len(); i++) {
      let item = shortcutsList[i]
      local show = true
      local canBeHidden = true

      if ("filterHide" in item) {
        show = !isInArray(this.filter, item.filterHide)
      }
      else if ("filterShow" in item) {
        show = isInArray(this.filter, item.filterShow)
      }
      else
        canBeHidden = false

      if ("showFunc" in item) {
        show = show && item.showFunc.bindenv(this)()
        canBeHidden = true
      }
      if (!canBeHidden)
        continue

      item.isHidden = !show
    }
  }

  function loadPresetWithMsg(msg, presetSelected, askKeyboardDefault = false) {
    this.msgBox(
      "controls_restore_question", msg,
      [
        ["yes", function() {
          if (askKeyboardDefault) {
            let presets = recommendedControlPresets.map(@(name) [
              name,
              function() {
                this.applySelectedPreset(getControlsPresetBySelectedType(name).fileName)
              }
            ])
            this.msgBox("ask_kbd_type", locByInputDevice("controls/askKeyboardWasdType"), presets, "classic")
            return
          }

          local preset = "empty_ver1"
          let opdata = get_option(USEROPT_CONTROLS_PRESET)
          if (presetSelected in opdata.values)
            preset = opdata.values[presetSelected]
          else
            this.forceLoadWizard = isPC

          preset = parseControlsPresetName(preset)
          preset = getHighestVersionControlsPreset(preset)
          this.applySelectedPreset(preset.fileName)
          resetFastVoiceMessages()
        }],
        ["no", @() null],
      ], "no"
    )
  }

  function applySelectedPreset(preset) {
    resetDefaultControlSettings()
    applyJoyPresetXchange(preset)
    broadcastEvent("ControlsPresetChanged")
  }

  function onClearAll() {
    this.backAfterSave = false
    this.doApply()
    this.loadPresetWithMsg(loc("hotkeys/msg/clearAll"), -1)
  }

  function onDefaultPreset() {
    this.backAfterSave = false
    this.doApply()
    this.loadPresetWithMsg(loc("controls/askRestoreDefaults"), 0, isPC)
  }

  function onButtonReset() {
    let item = this.getCurItem()
    if (!item)
      return
    if (item.type == CONTROL_TYPE.AXIS)
      return this.onAxisReset()
    if (!(item.shortcutId in this.shortcuts))
      return

    this.guiScene.performDelayed(this, function() {
      this.shortcuts[item.shortcutId] = []
      broadcastEvent("ControlsChangedShortcuts", { changedShortcuts = [item.shortcutId] })
    })
  }

  function updateButtonsChangeValue() {
    let item = this.getCurItem()
    let isShortcut = item != null && (item.type == CONTROL_TYPE.SHORTCUT || item.type == CONTROL_TYPE.AXIS_SHORTCUT)
    let isAxis = item != null && item.type == CONTROL_TYPE.AXIS

    this.showSceneItem("btn_reset_shortcut", isShortcut)
    this.showSceneItem("btn_reset_axis", isAxis)
    this.showSceneItem("btn_assign", isShortcut || isAxis)
    this.setNavButtonText("btn_assign", isAxis ? loc("mainmenu/btnEditAxis") : loc("mainmenu/btnAssign"))

    this.checkCurrentNavagationSection()
  }

  function onTblDblClick() {
    let item = this.getCurItem()
    if (!item)
      return

    if (item.type == CONTROL_TYPE.AXIS)
      this.openAxisBox(item)
    else if (item.type == CONTROL_TYPE.SHORTCUT || item.type == CONTROL_TYPE.AXIS_SHORTCUT)
      this.openShortcutInputBox(item)
    else if (item.type == CONTROL_TYPE.BUTTON)
      this.doItemAction(item)
  }

  function openShortcutInputBox(item) {
    openAssignShortcut(this, @(dev, btn, activationType) this.bindShortcut(dev, btn, activationType, item.shortcutId), item.id)
  }

  function doBind(devs, btns, activationType, shortcutId) {
    let event = this.shortcuts[shortcutId]
    event.append({ dev = devs, btn = btns, activationType })
    if (event.len() > MAX_SHORTCUTS)
      event.remove(0)

    broadcastEvent("ControlsChangedShortcuts", { changedShortcuts = [shortcutId] })
  }

  function updateShortcutText(shortcutId) {
    if (!(shortcutId in this.shortcuts))
      return

    let item = this.shortcutItems[shortcutId]
    let cellId = this.shortcutNames[shortcutId]
    if (this.isShortcutCellShown(cellId))
      this.showShortcutCell(cellId, getShortcutParts(this.shortcuts, shortcutId))

    if (item.type == CONTROL_TYPE.AXIS)
      this.updateAxisShortcuts(item)
  }

  function bindShortcut(devs, btns, activationType, shortcutId) {
    if (!(shortcutId in this.shortcuts))
      return false

    let curBinding = this.findButtons(devs, btns, activationType, shortcutId)
    if (!curBinding || curBinding.len() == 0) {
      this.doBind(devs, btns, activationType, shortcutId)
      return false
    }

    for (local i = 0; i < curBinding.len(); i++)
      if (curBinding[i][0] == shortcutId)
        return false

    let msg = loc("hotkeys/msg/unbind_question", {
      action = loc("ui/comma").join(
        curBinding.map((@(b) loc($"hotkeys/{this.shortcutNames[b[0]]}")).bindenv(this)),
        true
      )
    })
    this.msgBox("controls_bind_existing_shortcut", msg, [
      ["add", @() this.doBind(devs, btns, activationType, shortcutId)],
      ["replace", function() {
        for (local i = curBinding.len() - 1; i >= 0; i--) {
          let binding = curBinding[i]
          if (!(binding[1] in this.shortcuts[binding[0]]))
            continue

          this.shortcuts[binding[0]].remove(binding[1])
          this.updateShortcutText(binding[0])
        }
        this.doBind(devs, btns, activationType, shortcutId)
      }],
      ["cancel", function() { }],
    ], "cancel")
    return true
  }

  function findButtons(devs, btns, activationType, shortcutId) {
    let visibilityMap = this.getShortcutsVisibilityMap()

    if (u.find_in_array(this.dontCheckControlsDupes, this.shortcutNames[shortcutId]) >= 0)
      return null

    let res = []

    foreach (index, event in this.shortcuts)
      if ((this.shortcutItems[index].checkGroup & this.shortcutItems[shortcutId].checkGroup) &&
        visibilityMap?[this.shortcutNames[index]] &&
        (this.shortcutItems[index]?.conflictGroup == null ||
          this.shortcutItems[index]?.conflictGroup != this.shortcutItems[shortcutId]?.conflictGroup ||
          index == shortcutId))
        foreach (button_index, button in event) {
          if (!button || button.dev.len() != devs.len())
            continue
          local numEqual = 0
          for (local i = 0; i < button.dev.len(); i++)
            for (local j = 0; j < devs.len(); j++)
              if ((button.dev[i] == devs[j]) && (button.btn[i] == btns[j]) && button.activationType == activationType)
                numEqual++

          if (numEqual == btns.len() && u.find_in_array(this.dontCheckControlsDupes, this.shortcutNames[index]) < 0)
            res.append([index, button_index])
        }
    return res
  }

  function openAxisBox(axisItem) {
    if (this.curJoyParams && axisItem && axisItem.axisIndex >= 0)
      openAxisSetup(this, axisItem)
  }

  function onAxisReset() {
    local axisMode = -1
    let item = this.getCurItem()
    if (item && item.type == CONTROL_TYPE.AXIS)
      axisMode = item.axisIndex

    if (axisMode < 0)
      return

    this.curJoyParams.resetAxis(axisMode)

    if (item)
      foreach (_name, idx in item.modifiersId)
        this.shortcuts[idx] = []

    this.curJoyParams.bindAxis(axisMode, -1)
    this.updateSceneOptions()

    broadcastEvent("ControlsChangedAxes", { changedAxes = [item] })
  }

  function setAxisBind(axisIdx, axisNum, axisName) {
    this.curJoyParams.bindAxis(axisIdx, axisNum)
    this.updateSceneOptions()

    let axisItem = getShortcutById(axisName)
    broadcastEvent("ControlsChangedAxes", { changedAxes = [axisItem] })
  }

  function getUnmappedByGroups() {
    local currentHeader = null
    let unmapped = []
    let mapped = {}

    foreach (item in shortcutsList) {
      if (item.type == CONTROL_TYPE.HEADER) {
        let isHeaderVisible = !("showFunc" in item) || item.showFunc.call(this)
        if (isHeaderVisible)
          currentHeader =$"hotkeys/{item.id}"
        else
          currentHeader = null
      }
      let isRequired = item.checkAssign instanceof Function ? item.checkAssign() : item.checkAssign
      if (!currentHeader || item.isHidden || !isRequired)
        continue
      if (this.filter == ControlHelpersMode.EM_MOUSE_AIM && !item.reqInMouseAim)
        continue

      if (item.type == CONTROL_TYPE.SHORTCUT) {
        if ((item.shortcutId in this.shortcuts)
            && !isShortcutMapped(this.shortcuts[item.shortcutId]))
          unmapped.append({ item = item, header = currentHeader })
        else if ("alternativeIds" in item) {
          mapped[item.id] <- true
          foreach (alternativeId in item.alternativeIds)
            mapped[alternativeId] <- true
        }
      }
      else if (item.type == CONTROL_TYPE.AXIS) {
        local isMapped = false
        if (isAxisMappedOnMouse(item.id, this.filter, this.curJoyParams))
          isMapped = true

        if (!isMapped) {
          let axisId = item.axisIndex >= 0
            ? this.curJoyParams.getAxis(item.axisIndex).axisId : -1
          if (axisId >= 0 || !("modifiersId" in item))
            isMapped = true
        }

        if (!isMapped)
          foreach (name in ["rangeMin", "rangeMax"])
            if (name in item.modifiersId) {
              let id = item.modifiersId[name]
              if (!(id in this.shortcuts) || isShortcutMapped(this.shortcuts[id])) {
                isMapped = true
                break
              }
            }

        if (!isMapped)
          unmapped.append({ item = item, header = currentHeader })
        else if ("alternativeIds" in item) {
          mapped[item.id] <- true
          foreach (alternativeId in item.alternativeIds)
            mapped[alternativeId] <- true
        }
      }
    }

    let unmappedByGroups = {}
    let unmappedList = []
    foreach (unmappedItem in unmapped) {
      let item = unmappedItem.item
      if ("alternativeIds" in item || mapped?[item.id])
        continue

      let header = unmappedItem.header
      local unmappedGroup = unmappedByGroups?[header]
      if (!unmappedGroup) {
        unmappedGroup = { id = header, list = [] }
        unmappedByGroups[header] <- unmappedGroup
        unmappedList.append(unmappedGroup)
      }

      if (item.type == CONTROL_TYPE.SHORTCUT)
        unmappedGroup.list.append($"hotkeys/{this.shortcutNames[item.shortcutId]}")
      else if (item.type == CONTROL_TYPE.AXIS)
        unmappedGroup.list.append($"controls/{item.axisName}")
    }
    return unmappedList
  }

  function updateSliderValue(item) {
    let value = this.getControlItemValue(item)
    if (value == null)
      return

    setControlsItem(item.id, "valueText", getSliderValueText(item, value))
  }

  function onActionButtonClick(obj) {
    if (!obj?.id)
      return

    let item = getShortcutById(obj.id)
    this.doItemAction(item)
  }

  function doItemAction(item) {
    this.saveShortcutsAndAxes()
    if (item.onClick())
      this.doControlsGroupChangeDelayed()
  }

  function doApplyJoystick() {
    if (this.curJoyParams != null)
      this.doApplyJoystickImpl(shortcutsList, this.curJoyParams)
  }

  getControlItemValue = @(item) this.getControlValue(item.id)

  
  function getControlValue(id) {
    if (id == this.filterObjId)
      return this.getHelpersFilterIdx()
    return this.shownControlKinds?[id] == null ? null : controlsItems.get()?[id]?.value
  }

  
  function setControlValue(id, value) {
    if (id == this.filterObjId)
      return this.setHelpersFilterIdx(value)
    let kind = this.shownControlKinds?[id]
    if (kind == null || kind == "shortcut" || controlsItems.get()?[id]?.value == value)
      return
    setControlsItem(id, "value", value)
    let item = getShortcutById(id)
    if (item?.type == CONTROL_TYPE.SLIDER)
      setControlsItem(id, "valueText", getSliderValueText(item, value))
    else if (item?.onChangeValue != null)
      this[item.onChangeValue](mkControlObj(this, id))
  }

  function doApplyJoystickImpl(itemsList, setValueContext) {
    if (!this.isValid())
      return
    foreach (item in itemsList) {
      if ((("condition" in item) && !item.condition())
          || item.type == CONTROL_TYPE.SHORTCUT)
        continue

      let value = this.getControlItemValue(item)
      if (value == null)
        continue

      if ("optionType" in item) {
        set_option(item.optionType, value)
        continue
      }

      if (item.type == CONTROL_TYPE.MOUSE_AXIS && ("axis_num" in item)) {
        if (value in item.values)
          if (item.values[value] == "none")
            this.curJoyParams.setMouseAxis(item.axis_num, "")
          else
            this.curJoyParams.setMouseAxis(item.axis_num, item.values[value])
      }

      if (!("setValue" in item))
        continue

      if ((item.type == CONTROL_TYPE.SPINNER || item.type == CONTROL_TYPE.DROPRIGHT || item.type == CONTROL_TYPE.LISTBOX)
          && (item.options.len() > 0))
        if (value in item.options)
          item.setValue(setValueContext, value)

      if (item.type == CONTROL_TYPE.SLIDER)
        item.setValue(setValueContext, value)
      else if (item.type == CONTROL_TYPE.SWITCH_BOX)
        item.setValue(setValueContext, value)
    }

    joystickSetCurSettings(this.curJoyParams)
  }

  function onEventControlsPresetChanged(_p) {
    isPresetChanged.set(true)
  }

  function onEventControlsChangedShortcuts(p) {
    this.shortcuts = p?.updShortcuts ?? this.shortcuts
    foreach (sc in (p?.changedShortcuts ?? []))
      this.updateShortcutText(sc)
  }

  function onEventControlsChangedAxes(p) {
    this.shortcuts = p?.updShortcuts ?? this.shortcuts
    foreach (axis in p.changedAxes)
      this.updateAxisShortcuts(axis)
  }

  function doApply() {
    if (!checkObj(this.scene))
      return

    this.applyApproved = true
    this.saveShortcutsAndAxes()
    this.save(false)
    this.backAfterSave = true
  }

  function buildMsgFromGroupsList(list) {
    local text = ""
    let colonLocalized = loc("ui/colon")
    foreach (groupIdx, group in list) {
      if (groupIdx > 0)
        text = "".concat(text, "\n")
      text = "".concat(text, loc(group.id), colonLocalized, "\n")
      foreach (idx, locId in group.list) {
        if (idx != 0)
          text = "".concat(text, ", ")
        text = "".concat(text, loc(locId))
      }
    }
    return text
  }

  function changeControlsWindowType(value) {
    if (this.changeControlsMode == value)
      return

    this.changeControlsMode = value
    if (value)
      this.backSceneParams = { eventbusName = "gui_start_controls_console" }
    switchControlsMode(value)
  }

  function goBack() {
    this.onApply()
  }

  function onApply() {
    this.doApply()
  }

  function closeWnd() {
    this.restoreMainOptions()
    base.goBack()
  }

  function afterSave() {
    if (!this.backAfterSave)
      return

    let reqList = this.getUnmappedByGroups()
    if (!reqList.len())
      return this.closeWnd()

    let msg = "".concat(loc("controls/warningUnmapped"), loc("ui/colon"), "\n",
      this.buildMsgFromGroupsList(reqList))
    this.msgBox("not_all_mapped", msg,
    [
      ["resetToDefaults", function() {
        this.changeControlsWindowType(false)
        this.guiScene.performDelayed(this, this.onDefaultPreset)
      }],
      ["backToControls", function() {
        this.changeControlsWindowType(false)
      }],
      ["stillContinue", function() {
        this.guiScene.performDelayed(this, this.closeWnd)
      }]
    ], "backToControls")
  }

  function updateMouseAxis(value, id) {
    let curItem = shortcutsList.findvalue(@(v) v.id == id)
    if (!curItem)
      return

    let curValue = curItem.values?[value]
    if (curValue == null)
      return

    this.curJoyParams.setMouseAxis(curItem.axis_num, curValue == "none" ? "" : curValue)
    this.updateSceneOptions()
  }

  function onMouseWheel(obj) {
    let value = obj.getValue()
    let item = this.getCurItem()
    if (!item || !("values" in item) || !obj)
      return this.updateMouseAxis(value, obj.id)

    let axisName = item.values?[value]
    const zoomPostfix = "zoom"
    if (axisName && axisName.len() >= zoomPostfix.len() && axisName.slice(-4) == zoomPostfix) {
      let zoomAxisIndex = get_axis_index(axisName)
      if (zoomAxisIndex < 0)
        return

      let axis = this.curJoyParams.getAxis(zoomAxisIndex)
      if (axis.axisId < 0)
        return

      if (this.filter == ControlHelpersMode.EM_MOUSE_AIM) {
        this.setAxisBind(zoomAxisIndex, -1, axisName)
        return
      }

      let curPreset = getCurControlsPreset()
      let msg = format(loc("msg/zoomAssignmentsConflict"),
        remapAxisName(curPreset, axis.axisId))
      this.guiScene.performDelayed(this, @()
        this.msgBox("zoom_axis_assigned", msg,
        [
          ["replace", @() this.setAxisBind(zoomAxisIndex, -1, axisName)],
          ["cancel", function() {
            if (checkObj(obj))
              obj.setValue(0)
          }]
        ], "replace"))
    }
    else if (axisName && (axisName == "camx" || axisName == "camy")
      && item.axis_num == MouseAxis.MOUSE_SCROLL) {
      let isMouseView = AIR_MOUSE_USAGE.VIEW ==
        getAircraftHelpersOptionValue(USEROPT_MOUSE_USAGE)
      let isMouseViewWhenNoAim = AIR_MOUSE_USAGE.VIEW ==
        getAircraftHelpersOptionValue(USEROPT_MOUSE_USAGE_NO_AIM)

      if (isMouseView || isMouseViewWhenNoAim) {
        let msg = isMouseView
          ? loc("msg/replaceMouseViewToScroll")
          : loc("msg/replaceMouseViewToScrollNoAim")
        this.guiScene.performDelayed(this, @()
          this.msgBox("mouse_used_for_view", msg,
          [
            ["replace", function() {
              setAircraftHelpersOptionValue(
                USEROPT_MOUSE_USAGE, AIR_MOUSE_USAGE.AIM)
              setAircraftHelpersOptionValue(
                USEROPT_MOUSE_USAGE_NO_AIM, AIR_MOUSE_USAGE.JOYSTICK)
              this.onAircraftHelpersChanged(null)
            }],
            ["cancel", function() {
              if (checkObj(obj))
                obj.setValue(0)
            }]
          ], "cancel"))
      }
    }
  }

  function onControlsHelp() {
    this.backAfterSave = false
    this.doApply()
    gui_modal_help(false, HELP_CONTENT_SET.CONTROLS)
  }

  function onControlsWizard() {
    this.backAfterSave = false
    this.doApply()
    gui_modal_controlsWizard()
  }

  onControlsWorkshop = @() openUrl(
    getCurCircuitOverride("liveControlsUrl", loc("url/workshop/controls")),
    true, false, "internal_browser")

  function saveShortcutsAndAxes() {
    this.doApplyJoystick()
    setShortcutsAndSaveControls(this.shortcuts, this.shortcutNames)
  }

  function updateCurPresetForExport() {
    this.saveShortcutsAndAxes()
    let curPreset = getCurControlsPreset()
    clearControlsPresetGuiOptions(curPreset)
    let mainOptionsMode = getGuiOptionsMode()
    setGuiOptionsMode(OPTIONS_MODE_GAMEPLAY)
    foreach (item in shortcutsList)
      if ("optionType" in item && item.optionType in userOptionNameByIdx) {
        let optionName = userOptionNameByIdx[item.optionType]
        let value = get_option(item.optionType).value
        if (value != null)
          curPreset.params[optionName] <- value
      }
    setGuiOptionsMode(mainOptionsMode)
    set_current_controls(curPreset)
  }

  function onManageBackup() {
    if (!this.isValid()) 
      return
    this.updateCurPresetForExport()
    ControlsBackupManager.open()
  }

  function onExportToFile() {
    if (!this.isValid()) 
      return
    this.updateCurPresetForExport()

    if (this.isScriptOpenFileDialogAllowed()) {
      loadHandler(FileDialog, {
        isSaveFile = true
        dirPath = get_save_load_path()
        pathTag = "controls"
        onSelectCallback = function(path) {
          let isSaved = export_current_layout_by_path(path)
          if (!isSaved)
            showInfoMsgBox(loc("msgbox/errorSavingPreset"))
          return isSaved
        }
        extension = "blk"
        currentFilter = "blk"
      })
    }
    else if (!export_current_layout())
      this.msgBox("errorSavingPreset", loc("msgbox/errorSavingPreset"),
             [["ok", function() {} ]], "ok", { cancel_fn = function() {} })
  }

  function onImportFromFile() {
    if (this.isScriptOpenFileDialogAllowed()) {
      loadHandler(FileDialog, {
        isSaveFile = false
        dirPath = get_save_load_path()
        pathTag = "controls"
        onSelectCallback = function(path) {
          let isOpened = import_current_layout_by_path(path)
          if (isOpened)
            broadcastEvent("ControlsPresetChanged")
          else
            showInfoMsgBox($"{loc("msgbox/errorLoadingPreset")}: {path}")
          return isOpened && isLastLoadControlsSucceeded.get()
        }
        extension = "blk"
        currentFilter = "blk"
      })
    }
    else {
      if (import_current_layout())
        broadcastEvent("ControlsPresetChanged")
      else
        this.msgBox("errorLoadingPreset", loc("msgbox/errorLoadingPreset"),
               [["ok", function() {} ]], "ok", { cancel_fn = function() {} })
    }
  }

  function onGroupTab(idx) {
    if (idx == controlsScreen.get().curGroupIdx)
      return
    setControlsScreenField("curGroupIdx", idx)
    this.onControlsGroupChange()
  }

  function onNavItem(idx) {
    if (idx in this.getNavItems())
      setControlsScreenField("curNavIdx", idx)
  }

  function getShortcutsVisibilityMap() {
    let helpersMode = getCurrentHelpersMode()
    local isHeaderShowed = true
    local isSectionShowed = true

    let visibilityMap = {}

    foreach (entry in shortcutsList) {
      let isShowed =
        (!("filterHide" in entry) || !isInArray(helpersMode, entry.filterHide)) &&
        (!("filterShow" in entry) || isInArray(helpersMode, entry.filterShow)) &&
        (!("showFunc" in entry) || entry.showFunc.call(this))
      if (entry.type == CONTROL_TYPE.HEADER) {
        isHeaderShowed = isShowed
        isSectionShowed = true
      }
      else if (entry.type == CONTROL_TYPE.SECTION)
        isSectionShowed = isShowed
      visibilityMap[entry.id] <- isShowed && isHeaderShowed && isSectionShowed
    }

    return visibilityMap
  }
}
register_gui_handler("Hotkeys", Hotkeys)

subscribeScreenActions("controlsScreen.action", Hotkeys, {
  function button(h, p) {
    let method = METHOD_BY_BUTTON?[p.id]
    if (method != null)
      h[method]()
  }
  rowButton = @(h, p) h.onActionButtonClick({ id = p.id })
  value = @(h, p) h.setControlValue(p.id, p.value)
  helpersFilter = @(h, p) h.setHelpersFilterIdx(p.idx)
  groupTab = @(h, p) h.onGroupTab(p.idx)
  navItem = @(h, p) h.onNavItem(p.idx)
  search = @(h, p) h.setSearchText(p.text)
  searchCancel = @(h, _) h.onSearchCancel()
  shortcutClick = @(h, p) h.onShortcutClick(p.rowIdx, p.byGamepad)
  shortcutDblClick = @(h, p) h.onShortcutDblClick(p.rowIdx)
  shortcutHover = @(h, p) h.onScHover({ scId = p.rowIdx })
  shortcutUnhover = @(h, p) h.onScUnHover({ scId = p.rowIdx })
})

function onControllerEvent() {
  handlersManager.findHandlerClassInScene(Hotkeys)?.updateButtons()
}

controllerState.add_event_handler(onControllerEvent)

on_module_unload(@(_) controllerState.remove_event_handler(onControllerEvent))

return freeze({ Hotkeys })
