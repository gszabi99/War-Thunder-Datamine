from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import set_current_controls, import_current_layout_by_path,
  import_current_layout, set_option_gain, fetch_devices_inited_once, get_save_load_path,
  get_axis_index, export_current_layout, export_current_layout_by_path
from "gameOptions" import *
from "%scripts/controls/controlsConsts.nut" import AIR_MOUSE_USAGE
from "%scripts/mainConsts.nut" import HELP_CONTENT_SET
let { is_windows, isPC } = require("%sqstd/platform.nut")
let { g_shortcut_type } = require("%scripts/controls/shortcutType.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { is_low_width_screen } = require("%scripts/options/safeAreaMenu.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { AXIS_MODIFIERS, MAX_SHORTCUTS, CONTROL_TYPE } = require("%scripts/controls/controlsConsts.nut")
let { format } = require("string")
let { ControlHelpersMode, setControlHelpersMode } = require("globalEnv")
let controllerState = require("controllerState")
let shortcutsAxisListModule = require("%scripts/controls/shortcutsList/shortcutsAxis.nut")
let { resetFastVoiceMessages } = require("%scripts/wheelmenu/voiceMessages.nut")
let { unitClassType } = require("%scripts/unit/unitClassType.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { isPlatformSony, isPlatformPS4, isPlatformXbox, isPlatformPC, isPlatformShieldTv
} = require("%scripts/clientState/platform.nut")
let { saveProfile } = require("%scripts/clientState/saveProfile.nut")
let { setBreadcrumbGoBackParams } = require("%scripts/breadcrumb.nut")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { setGuiOptionsMode, getGuiOptionsMode } = require("guiOptions")
let { getTextMarkup, getShortcutData, getInputsMarkup, isShortcutMapped,
  restoreShortcuts, isAxisMappedOnMouse, refillControlsDupes, buildHotkeyItem
} = require("%scripts/controls/shortcutsUtils.nut")
let { get_game_mode } = require("mission")
let { utf8ToLower } = require("%sqstd/string.nut")
let { recommendedControlPresets, getControlsPresetBySelectedType,
  canChangeHelpersMode, gui_modal_controlsWizard } = require("%scripts/controls/controlsUtils.nut")
let { joystickSetCurSettings, setShortcutsAndSaveControls,
  joystickGetCurSettings, getShortcuts } = require("%scripts/controls/controlsCompatibility.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { set_option, get_option } = require("%scripts/options/optionsExt.nut")
let { showConsoleButtons, switchShowConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_HELPERS_MODE, USEROPT_CONTROLS_PRESET, USEROPT_MOUSE_USAGE,
  USEROPT_MOUSE_USAGE_NO_AIM, userOptionNameByIdx
} = require("%scripts/options/optionsExtNames.nut")
let { remapAxisName } = require("%scripts/controls/controlsVisual.nut")
let { switchControlsMode, gui_start_controls_type_choice
} = require("%scripts/controls/startControls.nut")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")
let { Button } = require("%scripts/controls/input/button.nut")
let { Combination } = require("%scripts/controls/input/combination.nut")
let { Axis } = require("%scripts/controls/input/axis.nut")
let { gui_modal_help } = require("%scripts/help/helpWnd.nut")
let { assignButtonWindow } = require("%scripts/controls/assignButtonWnd.nut")
let { getAircraftHelpersOptionValue, setAircraftHelpersOptionValue, controlHelpersOptions,
  getCurrentHelpersMode } = require("%scripts/controls/aircraftHelpers.nut")
let getNavigationImagesText = require("%scripts/utils/getNavigationImagesText.nut")

let ControlsPreset = require("%scripts/controls/controlsPreset.nut")
let { getControlsPresetFilename, parseControlsPresetName, getHighestVersionControlsPreset
} = require("%scripts/controls/controlsPresets.nut")
let { getCurControlsPreset, isPresetChanged } = require("%scripts/controls/controlsState.nut")
let { getShortcutById, shortcutsList } = require("%scripts/controls/shortcutsList/shortcutsList.nut")
let { setHelpersModeAndOption } = require("%scripts/controls/controlsTypeUtils.nut")

let { restoreHardcodedKeys, clearCurControlsPresetGuiOptions, setAndCommitCurControlsPreset,
  isLastLoadControlsSucceeded
} = require("%scripts/controls/controlsManager.nut")

let { set_option_mouse_joystick_square,
  set_option_mouse_joystick_square_helicopter
} = require("controlsOptions")


function getAxisActivationShortcutData(shortcuts, item, preset) {
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
      buttons.append(Button(sc.dev[j], sc.btn[j], preset))

    if (buttons.len() > 1)
      inputs.append(Combination(buttons))
    else
      inputs.extend(buttons)
  }
  
  if (scArr.len() == 0 && axisInput)
    inputs.append(axisInput)

  return getInputsMarkup(inputs)
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

function switchHelpersModeAndOption(preset = "") {
  let joyCurSettings = joystickGetCurSettings()
  if (joyCurSettings.useMouseAim)
    setHelpersModeAndOption(ControlHelpersMode.EM_MOUSE_AIM)
  else if (isPlatformPS4 && preset == getControlsPresetFilename("thrustmaster_hotas4")) {
    if (getCurrentHelpersMode() == ControlHelpersMode.EM_MOUSE_AIM)
      setHelpersModeAndOption(ControlHelpersMode.EM_INSTRUCTOR)
  }
  else if (isPlatformSony || isPlatformXbox || isPlatformShieldTv())
    setHelpersModeAndOption(ControlHelpersMode.EM_REALISTIC)
  else if (getCurrentHelpersMode() == ControlHelpersMode.EM_MOUSE_AIM)
    setHelpersModeAndOption(ControlHelpersMode.EM_INSTRUCTOR)
}


local shortcutsNotChangeByPreset = [
  "ID_INTERNET_RADIO",
  "ID_INTERNET_RADIO_PREV",
  "ID_INTERNET_RADIO_NEXT",
  "ID_PTT"
]

::apply_joy_preset_xchange <- function apply_joy_preset_xchange(preset, updateHelpersMode = true) {
  if (!preset || preset == "")
    return

  let scToRestore = getShortcuts(shortcutsNotChangeByPreset)
  setAndCommitCurControlsPreset(ControlsPreset(preset))
  restoreShortcuts(scToRestore, shortcutsNotChangeByPreset)

  if (isPC)
    switchShowConsoleButtons(preset.indexof("xinput") != null)

  if (updateHelpersMode)
    switchHelpersModeAndOption(preset)

  saveProfile()
}

gui_handlers.Hotkeys <- class (gui_handlers.GenericOptions) {
  wndType = handlerType.BASE
  sceneBlkName = "%gui/controls.blk"
  sceneNavBlkName = null

  filterValues = null
  filterObjId = null
  filter = null
  lastFilter = null

  navigationHandlerWeak = null
  shouldUpdateNavigationSection = true

  shortcuts = null
  shortcutNames = null
  shortcutItems = null
  modifierSymbols = null

  dontCheckControlsDupes = null
  notAssignedAxis = null

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

  updateButtonsHandler = null
  optionTableId = "controls_tbl"
  curShortcut = null
  curShortcutBtn = null

  axisControlsHandlerWeak = null

  function initScreen() {
    setBreadcrumbGoBackParams(this)
    this.mainOptionsMode = getGuiOptionsMode()
    setGuiOptionsMode(OPTIONS_MODE_GAMEPLAY)

    this.scene.findObject("hotkeys_update").setUserData(this)

    if (is_low_width_screen()) {
      let helpersModeObj = this.scene.findObject("helpers_mode")
      if (checkObj(helpersModeObj))
        helpersModeObj.smallFont = "yes"
    }

    this.shortcuts = []
    this.shortcutNames = []
    this.shortcutItems = []
    this.dontCheckControlsDupes = []
    this.notAssignedAxis = []

    this.initNavigation()
    this.initMainParams()

    if (!fetch_devices_inited_once())
      gui_start_controls_type_choice()

    if (controllerState?.add_event_handler) {
      this.updateButtonsHandler = this.updateButtons.bindenv(this)
      controllerState.add_event_handler(this.updateButtonsHandler)
    }
  }

  function onDestroy() {
    if (this.updateButtonsHandler && controllerState?.remove_event_handler)
      controllerState.remove_event_handler(this.updateButtonsHandler)
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

  function initNavigation() {
    let handler = loadHandler(
      gui_handlers.navigationPanel,
      { scene = this.scene.findObject("control_navigation")
        onSelectCb = Callback(this.doNavigateToSection, this)
        panelWidth        = "0.35@sf, ph"
        
        headerHeight      = "0.05@sf + @sf/@pf"
        headerOffsetX     = "0.015@sf"
        headerOffsetY     = "0.015@sf"
      })
    this.registerSubHandler(this.navigationHandlerWeak)
    this.navigationHandlerWeak = handler.weakref()
  }

  function fillFilterObj() {
    if (this.filterObjId) {
      let filterObj = this.scene.findObject(this.filterObjId)
      if (checkObj(filterObj) && this.filterValues && filterObj.childrenCount() == this.filterValues.len() && !isPresetChanged.get())
        return 
    }

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

    let view = { items = [] }
    foreach (idx, item in options.items)
      view.items.append({
        id = $"option_{options.values[idx]}"
        text = item.text
        selected = options.value == idx
        tooltip = item.tooltip
      })

    let listBoxObj = this.scene.findObject(modsBlock.id)
    let data = handyman.renderCached("%gui/commonParts/shopFilter.tpl", view)
    this.guiScene.replaceContentFromText(listBoxObj, data, data.len(), this)
    this.onOptionsFilter()
  }

  function fillControlsType() {
    this.fillFilterObj()
  }

  function onFilterEditBoxActivate() {}
  function onFilterEditBoxChangeValue() {
    if (u.isEmpty(this.filledControlGroupTab))
      return

    let filterEditBox = this.scene.findObject("filter_edit_box")
    if (!checkObj(filterEditBox))
      return

    let filterText = utf8ToLower(filterEditBox.getValue())

    local parentId = ""
    foreach (_idx, data in this.filledControlGroupTab) {
      local show = filterText == "" || data.text.indexof(filterText) != null
      if(show && data?.isHeader == true)
        parentId = data.id
      if(parentId != "" && data?.parentId == parentId)
        show = true
      showObjById(data.id, show, this.scene)
    }
  }

  function onFilterEditBoxCancel(obj) {
    if (obj.getValue() != "")
      this.resetSearch()
    else
      this.guiScene.performDelayed(this, function() {
        if (this.isValid())
          this.goBack()
      })
  }

  function resetSearch() {
    let filterEditBox = this.scene.findObject("filter_edit_box")
    if (! checkObj(filterEditBox))
      return

    filterEditBox.setValue("")
  }

  function isScriptOpenFileDialogAllowed() {
    return hasFeature("ScriptImportExportControls")
  }

  function updateButtons() {
    let isTutorial = get_game_mode() == GM_TRAINING
    let isImportExportAllowed = !isTutorial
      && (this.isScriptOpenFileDialogAllowed() || is_windows)

    showObjById("btn_exportToFile", isImportExportAllowed, this.scene)
    showObjById("btn_importFromFile", isImportExportAllowed, this.scene)
    showObjById("btn_switchMode", isPlatformSony || isPlatformXbox || isPlatformShieldTv(), this.scene)
    showObjById("btn_backupManager", gui_handlers.ControlsBackupManager.isAvailable(), this.scene)
    showObjById("btn_controlsWizard", hasFeature("ControlsPresets"), this.scene)
    showObjById("btn_clearAll", !isTutorial, this.scene)
    showObjById("btn_controlsHelp", hasFeature("ControlsHelp"), this.scene)
    showObjById("btn_controls_workshop_online", isPlatformPC, this.scene)
  }

  function fillControlGroupsList() {
    let groupsList = this.scene.findObject("controls_groups_list")
    if (!checkObj(groupsList))
      return

    local curValue = 0
    this.controlsGroupsIdList = []
    let currentUnit = getPlayerCurUnit()
    local unitType = unitTypes.INVALID
    local classType = unitClassType.UNKNOWN
    local unitTags = []
    if (this.curGroupId == "" && currentUnit) {
      unitType = currentUnit.unitType
      classType = currentUnit.expClass
      unitTags = getTblValue("tags", currentUnit, [])
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

    let view = { tabs = [] }
    foreach (idx, group in this.controlsGroupsIdList)
      view.tabs.append({
        id = group
        tabName = $"#hotkeys/{group}"
        navImagesText = getNavigationImagesText(idx, this.controlsGroupsIdList.len())
      })

    let data = handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
    this.guiScene.replaceContentFromText(groupsList, data, data.len(), this)

    let listValue = groupsList.getValue()
    if (groupsList.getValue() != curValue)
      groupsList.setValue(curValue)
    if (listValue <= 0 && curValue == 0) 
      this.onControlsGroupChange()
  }

  function onControlsGroupChange() {
    this.doControlsGroupChange()
  }

  function doControlsGroupChange(forceUpdate = false) {
    if (!checkObj(this.scene))
      return

    local groupId = this.scene.findObject("controls_groups_list").getValue()
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

  function fillControlGroupTab(groupId) {
    local data = "";
    let joyParams = joystickGetCurSettings();
    local gRow = 0  
    local isSectionShowed = true
    local isHelpersVisible = false

    let navigationItems = []
    this.filledControlGroupTab = []
    local headerId = ""

    for (local n = 0; n < shortcutsList.len(); n++) {
      if (shortcutsList[n].id != groupId)
        continue

      isHelpersVisible = getTblValue("isHelpersVisible", shortcutsList[n])
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

        this.filledControlGroupTab.append(hotkeyData)
        if (hotkeyData.markup == "")
          continue

        data = $"{data}{hotkeyData.markup}"
        gRow++
      }

      break
    }

    let controlTblObj = this.scene.findObject(this.optionTableId);
    if (checkObj(controlTblObj))
      this.guiScene.replaceContentFromText(controlTblObj, data, data.len(), this);
    showObjById("helpers_mode", isHelpersVisible, this.scene)
    if (this.navigationHandlerWeak)
      this.navigationHandlerWeak.setNavItems(navigationItems)
    this.updateSceneOptions()
    this.optionsFilterApply()
    this.onFilterEditBoxChangeValue()
  }

  function doNavigateToSection(navItem) {
    let sectionId = navItem.id
    this.shouldUpdateNavigationSection = false
    let rowIdx = this.getRowIdxBYId(sectionId)
    let rowId = $"table_row_{rowIdx}"
    let rowObj = this.scene.findObject(rowId)

    rowObj.scrollToView(true)
    this.selectRowByRowIdx(rowIdx)
    this.shouldUpdateNavigationSection = true
  }

  function checkCurrentNavagationSection() {
    let item = this.getCurItem()
    if (!this.navigationHandlerWeak || !this.shouldUpdateNavigationSection || !item)
      return

    let navItems = this.navigationHandlerWeak.getNavItems()
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
          this.navigationHandlerWeak.setCurrentItem(curItem)

        break
      }
    }
  }

  function onUpdate(_obj, _dt) {
    if (!isPresetChanged.get())
      return

    this.initMainParams()
    this.updateAxisControlsHandlerParams()
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
    let itemObj = this.scene.findObject($"sc_{item.id}")
    if (!checkObj(itemObj))
      return

    local data = ""
    let curPreset = getCurControlsPreset()
    if ("modifiersId" in item) {
      if ("" in item.modifiersId && item.modifiersId[""] in this.shortcuts) {
        let activationShortcut = getAxisActivationShortcutData(this.shortcuts, item, curPreset)
        if (activationShortcut != "")
          data = $"{getTextMarkup(this.getSymbol(""))}{activationShortcut}"
      }
      
      foreach (modifier, id in item.modifiersId)
        if (modifier != "") {
          let scData = getShortcutData(this.shortcuts, id, false, curPreset)
          if (scData != "")
          data = "".concat(data, (data == "" ? "" : getTextMarkup(loc("ui/semicolon"))),
            getTextMarkup(this.getSymbol(modifier)), scData)
        }
    }

    let notAssignedId = u.find_in_array(this.notAssignedAxis, item)
    if (data == "") {
      data = getTextMarkup(loc("joystick/axis_not_assigned"))
      if (notAssignedId < 0)
        this.notAssignedAxis.append(item)
    }
    else if (notAssignedId >= 0)
        this.notAssignedAxis.remove(notAssignedId)

    this.guiScene.replaceContentFromText(itemObj, data, data.len(), this)
  }

  function updateSceneOptions() {
    for (local i = 0; i < shortcutsList.len(); i++) {
      if (shortcutsList[i].type == CONTROL_TYPE.AXIS && shortcutsList[i].axisIndex >= 0)
        this.updateAxisShortcuts(shortcutsList[i])
      else if (shortcutsList[i].type == CONTROL_TYPE.SLIDER)
        this.updateSliderValue(shortcutsList[i])
    }
  }

  function getRowIdx(rowObj) {
    let id = rowObj?.id
    if (!id || id.len() <= 10 || id.slice(0, 10) != "table_row_")
      return -1
    return id.slice(10).tointeger()
  }

  function getRowIdxBYId(id) {
    return shortcutsList.findindex(@(s) s.id == id) ?? -1
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

  function onScClick(obj) {
    let sc = this.getScById(obj?.scId)
    if (sc == null)
      return
    if (sc == this.curShortcut) {
      obj.selected = "no"
      this.curShortcut = null
      this.curShortcutBtn = null
    }
    else {
      if (checkObj(this.curShortcutBtn))
        this.curShortcutBtn.selected = "no"
      obj.selected = "yes"
      this.curShortcut = sc
      this.curShortcutBtn = obj
    }
    this.updateButtonsChangeValue()
  }

  function onScDblClick(obj) {
    let sc = this.getScById(obj?.scId)
    if (sc == null)
      return
    if (sc != this.curShortcut)
      this.onScClick(obj)
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
          let object = this.scene.findObject(shortcutsList[i].id)
          if (checkObj(object) && object.getValue() != option.value)
            object.setValue(option.value)
        }
    }

    this.curJoyParams.mouseJoystick = getTblValue("mouseJoystick",
      getCurControlsPreset().params, false)

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

    if (!this.filterObjId)
      return

    let filterObj = this.scene.findObject(this.filterObjId)
    if (!checkObj(filterObj))
      return

    let filterId = filterObj.getValue()
    if (!(filterId in this.filterValues))
      return

    if (!canChangeHelpersMode() && this.filter != null) {
      foreach (idx, value in this.filterValues)
        if (value == this.filter) {
          if (idx != filterId) {
            let newValue = idx
            this.msgBox("cant_change_controls", loc("msgbox/tutorial_controls_type_locked"),
                   [["ok", function() {
                       if (checkObj(filterObj))
                         filterObj.setValue(newValue)
                     }
                   ]], "ok")
          }
          break
        }
      return
    }
    setControlHelpersMode(filterId);
    this.filter = this.filterValues[filterId];
    this.fillControlGroupsList();
    
  }

  function selectRowByRowIdx(idx) {
    let controlTblObj = this.scene.findObject(this.optionTableId)
    if (!checkObj(controlTblObj) || idx < 0)
      return

    let id = $"table_row_{idx}"
    for (local i = 0; i < controlTblObj.childrenCount(); i++) {
      let child = controlTblObj.getChild(i)
      if (child.id == id)
        child.scrollToView()
    }
  }

  function getFilterObj() {
    if (!checkObj(this.scene) || !this.filterObjId)
      return null
    return this.scene.findObject(this.filterObjId)
  }

  delayedControlsGroupStrated = false
  function doControlsGroupChangeDelayed(_obj = null) {
    this.delayedControlsGroupStrated = true
    this.guiScene.performDelayed(this, function() {
      this.delayedControlsGroupStrated = false
      let filterOption = get_option(USEROPT_HELPERS_MODE)
      let filterObj = this.getFilterObj()
      if (checkObj(filterObj) && filterObj.getValue() != filterOption.value)
        filterObj.setValue(filterOption.value)
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

  function optionsFilterApply() {
    this.updateHidden()
    let mainTbl = this.scene.findObject(this.optionTableId)
    if (!checkObj(mainTbl))
      return

    let totalRows = mainTbl.childrenCount()

    for (local i = 0; i < totalRows; i++) {
      let obj = mainTbl.getChild(i)
      let itemIdx = this.getRowIdx(obj)
      if (itemIdx < 0)
        continue

      let item = shortcutsList[itemIdx]
      let show = !item.isHidden

      if (obj) {
        obj.hiddenTr = show ? "no" : "yes"
        obj.inactive = (show && item.type != CONTROL_TYPE.HEADER
          && item.type != CONTROL_TYPE.SECTION) ? null : "yes"
      }
    }

    showObjById("btn_preset", this.filter != ControlHelpersMode.EM_MOUSE_AIM, this.scene)
    showObjById("btn_defaultpreset", this.filter == ControlHelpersMode.EM_MOUSE_AIM, this.scene)

    this.dontCheckControlsDupes = refillControlsDupes()
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
            this.msgBox("ask_kbd_type", loc("controls/askKeyboardWasdType"), presets, "classic")
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
    ::apply_joy_preset_xchange(preset);
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
    this.loadPresetWithMsg(loc("controls/askRestoreDefaults"), 0, isPlatformPC)
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
      if (this.scene && this.scene.isValid()) {
        let obj = this.scene.findObject("controls_input_root")
        if (obj)
          this.guiScene.destroyElement(obj)
      }

      if (!item)
        return

      this.shortcuts[item.shortcutId] = []
      broadcastEvent("ControlsChangedShortcuts", { changedShortcuts = [item.shortcutId] })
    })
  }

  function onTblSelect() {
    this.updateButtonsChangeValue()
  }

  function updateButtonsChangeValue() {
    let item = this.getCurItem()
    let isShortcut = item != null && (item.type == CONTROL_TYPE.SHORTCUT || item.type == CONTROL_TYPE.AXIS_SHORTCUT)
    let isAxis = item != null && item.type == CONTROL_TYPE.AXIS

    showObjById("btn_reset_shortcut", isShortcut, this.scene)
    showObjById("btn_reset_axis", isAxis, this.scene)
    let btnA = showObjById("btn_assign", isShortcut || isAxis, this.scene)
    btnA.setValue(isAxis ? loc("mainmenu/btnEditAxis") : loc("mainmenu/btnAssign"))

    this.checkCurrentNavagationSection()
  }

  function onTblDblClick() {
    let item = this.getCurItem()
    if (!item)
      return

    if (item.type == CONTROL_TYPE.AXIS)
      this.openAxisBox(item)
    else if (item.type == CONTROL_TYPE.SHORTCUT || item.type == CONTROL_TYPE.AXIS_SHORTCUT)
      this.openShortcutInputBox()
    else if (item.type == CONTROL_TYPE.BUTTON)
      this.doItemAction(item)
  }

  function openShortcutInputBox() {
    assignButtonWindow(this, this.onAssignButton)
  }

  function onAssignButton(dev, btn) {
    if (dev.len() > 0 && dev.len() == btn.len()) {
      let item = this.getCurItem()
      if (item)
        this.bindShortcut(dev, btn, item.shortcutId)
    }
  }

  function doBind(devs, btns, shortcutId) {
    let event = this.shortcuts[shortcutId]
    event.append({ dev = devs, btn = btns })
    if (event.len() > MAX_SHORTCUTS)
      event.remove(0)

    broadcastEvent("ControlsChangedShortcuts", { changedShortcuts = [shortcutId] })
  }

  function updateShortcutText(shortcutId) {
    if (!(shortcutId in this.shortcuts))
      return

    let item = this.shortcutItems[shortcutId]
    let itemObj = this.scene.findObject($"sc_{this.shortcutNames[shortcutId]}")

    if (itemObj?.isValid()) {
      let data = getShortcutData(this.shortcuts, shortcutId)
      this.guiScene.replaceContentFromText(itemObj, data, data.len(), this)
    }

    if (item.type == CONTROL_TYPE.AXIS)
      this.updateAxisShortcuts(item)
  }

  function bindShortcut(devs, btns, shortcutId) {
    if (!(shortcutId in this.shortcuts))
      return false

    let curBinding = this.findButtons(devs, btns, shortcutId)
    if (!curBinding || curBinding.len() == 0) {
      this.doBind(devs, btns, shortcutId)
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
      ["add", @() this.doBind(devs, btns, shortcutId)],
      ["replace", function() {
        for (local i = curBinding.len() - 1; i >= 0; i--) {
          let binding = curBinding[i]
          if (!(binding[1] in this.shortcuts[binding[0]]))
            continue

          this.shortcuts[binding[0]].remove(binding[1])
          this.updateShortcutText(binding[0])
        }
        this.doBind(devs, btns, shortcutId)
      }],
      ["cancel", function() { }],
    ], "cancel")
    return true
  }

  function findButtons(devs, btns, shortcutId) {
    let visibilityMap = this.getShortcutsVisibilityMap()

    if (u.find_in_array(this.dontCheckControlsDupes, this.shortcutNames[shortcutId]) >= 0)
      return null

    let res = []

    foreach (index, event in this.shortcuts)
      if ((this.shortcutItems[index].checkGroup & this.shortcutItems[shortcutId].checkGroup) &&
        getTblValue(this.shortcutNames[index], visibilityMap) &&
        (this.shortcutItems[index]?.conflictGroup == null ||
          this.shortcutItems[index]?.conflictGroup != this.shortcutItems[shortcutId]?.conflictGroup ||
          index == shortcutId))
        foreach (button_index, button in event) {
          if (!button || button.dev.len() != devs.len())
            continue
          local numEqual = 0
          for (local i = 0; i < button.dev.len(); i++)
            for (local j = 0; j < devs.len(); j++)
              if ((button.dev[i] == devs[j]) && (button.btn[i] == btns[j]))
                numEqual++

          if (numEqual == btns.len() && u.find_in_array(this.dontCheckControlsDupes, this.shortcutNames[index]) < 0)
            res.append([index, button_index])
        }
    return res
  }

  getAxisHandlerParams = @() {
    curJoyParams = this.curJoyParams,
    shortcuts = this.shortcuts,
    shortcutItems = this.shortcutItems
  }

  function openAxisBox(axisItem) {
    if (!this.curJoyParams || !axisItem || axisItem.axisIndex < 0)
      return

    let handler = loadHandler(gui_handlers.AxisControls,
      this.getAxisHandlerParams().__update({ axisItem = axisItem }))
    this.axisControlsHandlerWeak = handler.weakref()
  }

  function updateAxisControlsHandlerParams() {
    if (this.axisControlsHandlerWeak?.isValid() ?? false)
      this.axisControlsHandlerWeak.setShortcutsParams(this.getAxisHandlerParams())
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

  function onChangeAxisRelative(obj) {
    if (!obj)
      return

    let isRelative = obj.getValue() == 1
    local txtObj = this.scene.findObject("txt_rangeMax")
    if (txtObj)
      txtObj.setValue(loc(isRelative ? "hotkeys/rangeInc" : "hotkeys/rangeMax"))
    txtObj = this.scene.findObject("txt_rangeMin")
    if (txtObj)
      txtObj.setValue(loc(isRelative ? "hotkeys/rangeDec" : "hotkeys/rangeMin"))
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
      let isRequired = type(item.checkAssign) == "function" ? item.checkAssign() : item.checkAssign
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
    let valueObj = this.scene.findObject($"{item.id}_value")
    if (!valueObj)
      return
    let vlObj = this.scene.findObject(item.id)
    if (!vlObj)
      return

    let value = vlObj.getValue()
    local valueText = ""
    if ("showValueMul" in item)
      valueText = (item.showValueMul * value).tostring()
    else
      valueText = "".concat(value * (("showValuePercMul" in item) ? item.showValuePercMul : 1), "%")
    valueObj.setValue(valueText)
  }

  function onSliderChange(obj) {
    if (obj?.id)
      this.updateSliderValue(getShortcutById(obj.id))
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

  function doApplyJoystickImpl(itemsList, setValueContext) {
    if (!this.isValid())
      return
    foreach (item in itemsList) {
      if ((("condition" in item) && !item.condition())
          || item.type == CONTROL_TYPE.SHORTCUT)
        continue

      let obj = this.scene.findObject(item.id)
      if (!checkObj(obj))
        continue

      if ("optionType" in item) {
        let value = obj.getValue()
        set_option(item.optionType, value)
        continue
      }

      if (item.type == CONTROL_TYPE.MOUSE_AXIS && ("axis_num" in item)) {
        let value = obj.getValue()
        if (value in item.values)
          if (item.values[value] == "none")
            this.curJoyParams.setMouseAxis(item.axis_num, "")
          else
            this.curJoyParams.setMouseAxis(item.axis_num, item.values[value])
      }

      if (!("setValue" in item))
        continue

      let value = obj.getValue()
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

    let axisName = getTblValue(value, item.values)
    let zoomPostfix = "zoom"
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
    clearCurControlsPresetGuiOptions()
    let curPreset = getCurControlsPreset()
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
    gui_handlers.ControlsBackupManager.open()
  }

  function onExportToFile() {
    if (!this.isValid()) 
      return
    this.updateCurPresetForExport()

    if (this.isScriptOpenFileDialogAllowed()) {
      loadHandler(gui_handlers.FileDialog, {
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
      loadHandler(gui_handlers.FileDialog, {
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

  function onOptionsListboxDblClick(_obj) {}

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