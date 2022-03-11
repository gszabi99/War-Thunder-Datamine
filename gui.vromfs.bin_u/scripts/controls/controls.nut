let gamepadIcons = require("scripts/controls/gamepadIcons.nut")
let globalEnv = require("globalEnv")
let controllerState = require("controllerState")
let shortcutsListModule = require("scripts/controls/shortcutsList/shortcutsList.nut")
let shortcutsAxisListModule = require("scripts/controls/shortcutsList/shortcutsAxis.nut")
let { TRIGGER_TYPE,
        getLastWeapon,
        getCommonWeapons,
        getLastPrimaryWeapon } = require("scripts/weaponry/weaponryInfo.nut")
let { isBulletGroupActive } = require("scripts/weaponry/bulletsInfo.nut")
let { resetFastVoiceMessages } = require("scripts/wheelmenu/voiceMessages.nut")
let { unitClassType } = require("scripts/unit/unitClassType.nut")
let controlsPresetConfigPath = require("scripts/controls/controlsPresetConfigPath.nut")
let unitTypes = require("scripts/unit/unitTypesList.nut")
let { isPlatformSony, isPlatformPS4, isPlatformXboxOne, isPlatformPC } = require("scripts/clientState/platform.nut")
let { checkTutorialsList } = require("scripts/tutorials/tutorialsData.nut")
let { blkOptFromPath, blkFromPath } = require("sqStdLibs/helpers/datablockUtils.nut")
let vehicleModel = require("vehicleModel")
let { saveProfile } = require("scripts/clientState/saveProfile.nut")
let { setBreadcrumbGoBackParams } = require("scripts/breadcrumb.nut")
let { getPlayerCurUnit } = require("scripts/slotbar/playerCurUnit.nut")
let { useTouchscreen } = require("scripts/clientState/touchScreen.nut")
let { setGuiOptionsMode, getGuiOptionsMode } = ::require_native("guiOptions")
let { getShortcutById } = require("scripts/controls/shortcutsUtils.nut")
let { getUnitPresets, getWeaponsByPresetName } = require("scripts/weaponry/weaponryPresets.nut")

let PS4_CONTROLS_MODE_ACTIVATE = "ps4ControlsAdvancedModeActivated"

::preset_changed <- false

::shortcutsList <- shortcutsListModule.types

let function resetDefaultControlSettings() {
  ::set_option_multiplier(::OPTION_AILERONS_MULTIPLIER,         0.79); //::USEROPT_AILERONS_MULTIPLIER
  ::set_option_multiplier(::OPTION_ELEVATOR_MULTIPLIER,         0.64); //::USEROPT_ELEVATOR_MULTIPLIER
  ::set_option_multiplier(::OPTION_RUDDER_MULTIPLIER,           0.43); //::USEROPT_RUDDER_MULTIPLIER
  ::set_option_multiplier(::OPTION_HELICOPTER_CYCLIC_ROLL_MULTIPLIER,   0.79); //
  ::set_option_multiplier(::OPTION_HELICOPTER_CYCLIC_PITCH_MULTIPLIER,  0.64); //
  ::set_option_multiplier(::OPTION_HELICOPTER_PEDALS_MULTIPLIER,        0.43); //
  ::set_option_multiplier(::OPTION_ZOOM_SENSE,                  0); //::USEROPT_ZOOM_SENSE
  ::set_option_multiplier(::OPTION_MOUSE_SENSE,                 0.5); //::USEROPT_MOUSE_SENSE
  ::set_option_multiplier(::OPTION_MOUSE_AIM_SENSE,             0.5); //::USEROPT_MOUSE_AIM_SENSE
  ::set_option_multiplier(::OPTION_GUNNER_VIEW_SENSE,           1); //::USEROPT_GUNNER_VIEW_SENSE
  ::set_option_multiplier(::OPTION_ATGM_AIM_SENS_HELICOPTER,    1); //::USEROPT_ATGM_AIM_SENS_HELICOPTER
  ::set_option_multiplier(::OPTION_MOUSE_JOYSTICK_DEADZONE,     0.1); //mouseJoystickDeadZone
  ::set_option_multiplier(::OPTION_HELICOPTER_MOUSE_JOYSTICK_DEADZONE,     0.1);
  ::set_option_multiplier(::OPTION_MOUSE_JOYSTICK_SCREENSIZE,   0.6); //mouseJoystickScreenSize
  ::set_option_multiplier(::OPTION_HELICOPTER_MOUSE_JOYSTICK_SCREENSIZE,   0.6);
  ::set_option_multiplier(::OPTION_MOUSE_JOYSTICK_SENSITIVITY,  2); //mouseJoystickSensitivity
  ::set_option_multiplier(::OPTION_HELICOPTER_MOUSE_JOYSTICK_SENSITIVITY,  2);
  ::set_option_multiplier(::OPTION_MOUSE_JOYSTICK_SCREENPLACE,  0); //mouseJoystickScreenPlace
  ::set_option_multiplier(::OPTION_HELICOPTER_MOUSE_JOYSTICK_SCREENPLACE,  0);
  ::set_option_multiplier(::OPTION_MOUSE_AILERON_RUDDER_FACTOR, 0.5); //mouseAileronRudderFactor
  ::set_option_multiplier(::OPTION_HELICOPTER_MOUSE_AILERON_RUDDER_FACTOR, 0.5);
  ::set_option_multiplier(::OPTION_CAMERA_SMOOTH,               0); //
  ::set_option_multiplier(::OPTION_CAMERA_SPEED,                1.13); //
  ::set_option_multiplier(::OPTION_CAMERA_MOUSE_SPEED,          4); //
  ::set_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_AIR,        0.0); //
  ::set_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_HELICOPTER, 0.0); //
  ::set_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_TANK,       0.0); //
  ::set_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_SHIP,       0.0); //
  ::set_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_SUBMARINE,  0.0); //
  ::set_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_AIR,        0.5); //
  ::set_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_HELICOPTER, 0.5); //
  ::set_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_TANK,       0.5); //
  ::set_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_SHIP,       0.5); //
  ::set_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_SUBMARINE,  0.5); //

  ::set_option_mouse_joystick_square(0); //mouseJoystickSquare
  ::set_option_gain(1); //::USEROPT_FORCE_GAIN
}

::can_change_helpers_mode <- function can_change_helpers_mode()
{
  if (!::is_in_flight())
    return true

  let missionBlk = ::DataBlock()
  ::get_current_mission_info(missionBlk)

  foreach(part, block in checkTutorialsList)
    if(block.tutorial == missionBlk.name)
      return false
  return true
}

::switch_helpers_mode_and_option <- function switch_helpers_mode_and_option(preset = "")
{
  let joyCurSettings = ::joystick_get_cur_settings()
  if (joyCurSettings.useMouseAim)
    ::set_helpers_mode_and_option(globalEnv.EM_MOUSE_AIM)
  else if (isPlatformPS4 && preset == ::g_controls_presets.getControlsPresetFilename("thrustmaster_hotas4"))
  {
    if (::getCurrentHelpersMode() == globalEnv.EM_MOUSE_AIM)
      ::set_helpers_mode_and_option(globalEnv.EM_INSTRUCTOR)
  }
  else if (isPlatformSony || isPlatformXboxOne || ::is_platform_shield_tv())
    ::set_helpers_mode_and_option(globalEnv.EM_REALISTIC)
  else if (::getCurrentHelpersMode() == globalEnv.EM_MOUSE_AIM)
    ::set_helpers_mode_and_option(globalEnv.EM_INSTRUCTOR)
}


local shortcutsNotChangeByPreset = [
  "ID_INTERNET_RADIO",
  "ID_INTERNET_RADIO_PREV",
  "ID_INTERNET_RADIO_NEXT",
  "ID_PTT"
]

::apply_joy_preset_xchange <- function apply_joy_preset_xchange(preset, updateHelpersMode = true)
{
  if (!preset)
    preset = ::g_controls_manager.getCurPreset().getBasePresetFileName()

  if (!preset || preset == "")
    return

  let scToRestore = ::get_shortcuts(shortcutsNotChangeByPreset)

  ::restore_default_controls(preset)
  ::set_controls_preset(preset)

  let joyCurSettings = ::joystick_get_cur_settings()
  let curJoyParams = ::JoystickParams()
  curJoyParams.setFrom(joyCurSettings)
  ::joystick_set_cur_values(curJoyParams)

  ::g_controls_utils.restoreShortcuts(scToRestore, shortcutsNotChangeByPreset)

  if (::is_platform_pc)
    ::switch_show_console_buttons(preset.indexof("xinput") != null)

  if (updateHelpersMode)
    ::switch_helpers_mode_and_option(preset)

  saveProfile()
}

local axisMappedOnMouse = {
  mouse_aim_x            = @(isMouseAimMode) isMouseAimMode ? MOUSE_AXIS.HORIZONTAL_AXIS : MOUSE_AXIS.NOT_AXIS
  mouse_aim_y            = @(isMouseAimMode) isMouseAimMode ? MOUSE_AXIS.VERTICAL_AXIS : MOUSE_AXIS.NOT_AXIS
  gm_mouse_aim_x         = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  gm_mouse_aim_y         = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  ship_mouse_aim_x       = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  ship_mouse_aim_y       = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  helicopter_mouse_aim_x = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  helicopter_mouse_aim_y = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  submarine_mouse_aim_x  = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  submarine_mouse_aim_y  = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  //




  camx                   = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  camy                   = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  gm_camx                = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  gm_camy                = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  ship_camx              = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  ship_camy              = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  helicopter_camx        = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  helicopter_camy        = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  submarine_camx         = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  submarine_camy         = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  //



}
::is_axis_mapped_on_mouse <- function is_axis_mapped_on_mouse(shortcutId, helpersMode = null, joyParams = null)
{
  return get_mouse_axis(shortcutId, helpersMode, joyParams) != MOUSE_AXIS.NOT_AXIS
}

::get_mouse_axis <- function get_mouse_axis(shortcutId, helpersMode = null, joyParams = null)
{
  let axis = axisMappedOnMouse?[shortcutId]
  if (axis)
    return axis((helpersMode ?? ::getCurrentHelpersMode()) == globalEnv.EM_MOUSE_AIM)

  if (!joyParams)
  {
    joyParams = ::JoystickParams()
    joyParams.setFrom(::joystick_get_cur_settings())
  }
  for (local i = 0; i < MouseAxis.NUM_MOUSE_AXIS_TOTAL; ++i)
  {
    if (shortcutId == joyParams.getMouseAxis(i))
      return 1 << ::min(i, MOUSE_AXIS.TOTAL - 1)
  }

  return MOUSE_AXIS.NOT_AXIS
}

::gui_start_controls <- function gui_start_controls()
{
  if (isPlatformSony || isPlatformXboxOne || ::is_platform_shield_tv())
  {
    if (::load_local_account_settings(PS4_CONTROLS_MODE_ACTIVATE, true))
    {
      ::gui_start_controls_console()
      return
    }
  }

  ::gui_start_advanced_controls()
}

::gui_start_advanced_controls <- function gui_start_advanced_controls()
{
  if (!::has_feature("ControlsAdvancedSettings"))
    return
  ::gui_start_modal_wnd(::gui_handlers.Hotkeys)
}

::gui_handlers.Hotkeys <- class extends ::gui_handlers.GenericOptions
{
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

  function initScreen()
  {
    setBreadcrumbGoBackParams(this)
    mainOptionsMode = getGuiOptionsMode()
    setGuiOptionsMode(::OPTIONS_MODE_GAMEPLAY)

    scene.findObject("hotkeys_update").setUserData(this)

    if (::is_low_width_screen())
    {
      let helpersModeObj = scene.findObject("helpers_mode")
      if (::check_obj(helpersModeObj))
        helpersModeObj.smallFont = "yes"
    }

    shortcuts = []
    shortcutNames = []
    shortcutItems = []
    dontCheckControlsDupes = []
    notAssignedAxis = []

    initNavigation()
    initMainParams()

    if (!fetch_devices_inited_once())
      ::gui_start_controls_type_choice()

    if (controllerState?.add_event_handler) {
      updateButtonsHandler = updateButtons.bindenv(this)
      controllerState.add_event_handler(updateButtonsHandler)
    }
  }

  function onDestroy()
  {
    if (updateButtonsHandler && controllerState?.remove_event_handler)
      controllerState.remove_event_handler(updateButtonsHandler)
  }

  function onSwitchModeButton()
  {
    changeControlsWindowType(true)
    goBack()
  }

  function initMainParams()
  {
    initShortcutsNames()
    curJoyParams = ::JoystickParams()
    curJoyParams.setFrom(::joystick_get_cur_settings())
    updateButtons()

    ::g_controls_manager.restoreHardcodedKeys(max_shortcuts)
    shortcuts = ::get_shortcuts(shortcutNames)

    fillControlsType()
  }

  function initNavigation()
  {
    let handler = ::handlersManager.loadHandler(
      ::gui_handlers.navigationPanel,
      { scene = scene.findObject("control_navigation")
        onSelectCb = ::Callback(doNavigateToSection, this)
        panelWidth        = "0.35@sf, ph"
        // Align to helpers_mode and table first row
        headerHeight      = "0.05@sf + @sf/@pf"
        headerOffsetX     = "0.015@sf"
        headerOffsetY     = "0.015@sf"
      })
    registerSubHandler(navigationHandlerWeak)
    navigationHandlerWeak = handler.weakref()
  }

  function fillFilterObj()
  {
    if (filterObjId)
    {
      let filterObj = scene.findObject(filterObjId)
      if (::checkObj(filterObj) && filterValues && filterObj.childrenCount()==filterValues.len() && !::preset_changed)
        return //no need to refill filters
    }

    local modsBlock = null
    foreach(block in ::shortcutsList)
      if ("isFilterObj" in block && block.isFilterObj)
      {
        modsBlock = block
        break
      }

    if (modsBlock == null)
      return

    let options = ::get_option(modsBlock.optionType)

    filterObjId = modsBlock.id
    filterValues = options.values

    let view = { items = [] }
    foreach (idx, item in options.items)
      view.items.append({
        id = "option_" + options.values[idx]
        text = item.text
        selected = options.value == idx
        tooltip = item.tooltip
      })

    let listBoxObj = scene.findObject(modsBlock.id)
    let data = ::handyman.renderCached("%gui/commonParts/shopFilter", view)
    guiScene.replaceContentFromText(listBoxObj, data, data.len(), this)
    onOptionsFilter()
  }

  function fillControlsType()
  {
    fillFilterObj()
  }

  function onFilterEditBoxActivate() {}
  function onFilterEditBoxChangeValue()
  {
    if (::u.isEmpty(filledControlGroupTab))
      return

    let filterEditBox = scene.findObject("filter_edit_box")
    if (!::checkObj(filterEditBox))
      return

    let filterText = ::g_string.utf8ToLower(filterEditBox.getValue())

    foreach (idx, data in filledControlGroupTab)
    {
      let show = filterText == "" || data.text.indexof(filterText) != null
      showSceneBtn(data.id, show)
    }
  }

  function onFilterEditBoxCancel(obj)
  {
    if (obj.getValue() != "")
      resetSearch()
    else
      guiScene.performDelayed(this, function() {
        if (isValid())
          goBack()
      })
  }

  function resetSearch()
  {
    let filterEditBox = scene.findObject("filter_edit_box")
    if ( ! ::checkObj(filterEditBox))
      return

    filterEditBox.setValue("")
  }

  function isScriptOpenFileDialogAllowed()
  {
    return ::has_feature("ScriptImportExportControls")
      && "export_current_layout_by_path" in ::getroottable()
      && "import_current_layout_by_path" in ::getroottable()
  }

  function updateButtons()
  {
    let isTutorial = ::get_game_mode() == ::GM_TRAINING
    let isImportExportAllowed = !isTutorial
      && (isScriptOpenFileDialogAllowed() || ::is_platform_windows)

    showSceneBtn("btn_exportToFile", isImportExportAllowed)
    showSceneBtn("btn_importFromFile", isImportExportAllowed)
    showSceneBtn("btn_switchMode", isPlatformSony || isPlatformXboxOne || ::is_platform_shield_tv())
    showSceneBtn("btn_backupManager", ::gui_handlers.ControlsBackupManager.isAvailable())
    showSceneBtn("btn_controlsWizard", ::has_feature("ControlsPresets"))
    showSceneBtn("btn_clearAll", !isTutorial)
    showSceneBtn("btn_controlsHelp", ::has_feature("ControlsHelp"))
  }

  function fillControlGroupsList()
  {
    let groupsList = scene.findObject("controls_groups_list")
    if (!::checkObj(groupsList))
      return

    local curValue = 0
    controlsGroupsIdList = []
    let currentUnit = getPlayerCurUnit()
    local unitType = unitTypes.INVALID
    local classType = unitClassType.UNKNOWN
    local unitTags = []
    if (curGroupId == "" && currentUnit)
    {
      unitType = currentUnit.unitType
      classType = currentUnit.expClass
      unitTags = ::getTblValue("tags", currentUnit, [])
    }

    for(local i=0; i < ::shortcutsList.len(); i++)
      if (::shortcutsList[i].type == CONTROL_TYPE.HEADER)
      {
        let header = ::shortcutsList[i]
        if ("filterShow" in header)
          if (!isInArray(filter, header.filterShow))
            continue
        if ("showFunc" in header)
          if (!header.showFunc.bindenv(this)())
            continue

        controlsGroupsIdList.append(header.id)
        local isSuitable = unitType != unitTypes.INVALID
          && (header?.unitTypes.contains(unitType) ?? false)
        if (isSuitable && "unitClassTypes" in header)
          isSuitable = ::isInArray(classType, header.unitClassTypes)
        if (isSuitable && "unitTag" in header)
          isSuitable = ::isInArray(header.unitTag, unitTags)
        if (isSuitable)
          curGroupId = header.id
        if (header.id == curGroupId)
          curValue = controlsGroupsIdList.len()-1
      }

    let view = { tabs = [] }
    foreach(idx, group in controlsGroupsIdList)
      view.tabs.append({
        id = group
        tabName = "#hotkeys/" + group
        navImagesText = ::get_navigation_images_text(idx, controlsGroupsIdList.len())
      })

    let data = ::handyman.renderCached("%gui/frameHeaderTabs", view)
    guiScene.replaceContentFromText(groupsList, data, data.len(), this)

    let listValue = groupsList.getValue()
    if (groupsList.getValue() != curValue)
      groupsList.setValue(curValue)
    if (listValue <= 0 && curValue == 0) //when list value == -1 it doesnt send on_select event when we switch value to 0
      onControlsGroupChange()
  }

  function onControlsGroupChange()
  {
    doControlsGroupChange()
  }

  function doControlsGroupChange(forceUpdate = false)
  {
    if (!::checkObj(scene))
      return

    local groupId = scene.findObject("controls_groups_list").getValue()
    if (groupId < 0)
      groupId = 0

    if (!(groupId in controlsGroupsIdList))
      return

    let newGroupId = controlsGroupsIdList[groupId]
    let isGroupChanged = curGroupId != newGroupId
    if (!isGroupChanged && filter==lastFilter && !::preset_changed && !forceUpdate)
      return

    lastFilter = filter
    if (!::preset_changed)
      doApplyJoystick()
    curGroupId = newGroupId
    fillControlGroupTab(curGroupId)
  }

  function fillControlGroupTab(groupId)
  {
    local data = "";
    let joyParams = ::joystick_get_cur_settings();
    local gRow = 0  //for even and odd color by groups
    local isSectionShowed = true
    local isHelpersVisible = false

    let navigationItems = []
    filledControlGroupTab = []

    for(local n=0; n < ::shortcutsList.len(); n++)
    {
      if (::shortcutsList[n].id != groupId)
        continue

      isHelpersVisible = ::getTblValue("isHelpersVisible", ::shortcutsList[n])
      for(local i=n+1; i < ::shortcutsList.len(); i++)
      {
        let entry = ::shortcutsList[i]
        if (entry.type == CONTROL_TYPE.HEADER)
          break
        if (entry.type == CONTROL_TYPE.SECTION)
        {
          isSectionShowed =
            (!("filterHide" in entry) || !::isInArray(filter, entry.filterHide)) &&
            (!("filterShow" in entry) || ::isInArray(filter, entry.filterShow)) &&
            (!("showFunc" in entry) || entry.showFunc.call(this))
          if (isSectionShowed)
            navigationItems.append({
              id = entry.id
              text = "#hotkeys/" + entry.id
            })
        }
        if (!isSectionShowed)
          continue

        let hotkeyData = ::buildHotkeyItem(i, shortcuts, entry, joyParams, gRow%2 == 0)
        filledControlGroupTab.append(hotkeyData)
        if (hotkeyData.markup == "")
          continue

        data += hotkeyData.markup
        gRow++
      }

      break
    }

    let controlTblObj = scene.findObject(optionTableId);
    if (::checkObj(controlTblObj))
      guiScene.replaceContentFromText(controlTblObj, data, data.len(), this);
    showSceneBtn("helpers_mode", isHelpersVisible)
    if (navigationHandlerWeak)
      navigationHandlerWeak.setNavItems(navigationItems)
    updateSceneOptions()
    optionsFilterApply()
    onFilterEditBoxChangeValue()
  }

  function doNavigateToSection(navItem)
  {
    let sectionId = navItem.id
    shouldUpdateNavigationSection = false
    let rowIdx = getRowIdxBYId(sectionId)
    let rowId = "table_row_" + rowIdx
    let rowObj = scene.findObject(rowId)

    rowObj.scrollToView(true)
    selectRowByRowIdx(rowIdx)
    shouldUpdateNavigationSection = true
  }

  function checkCurrentNavagationSection()
  {
    let item = getCurItem()
    if (!navigationHandlerWeak || !shouldUpdateNavigationSection || !item)
      return

    let navItems = navigationHandlerWeak.getNavItems()
    if (navItems.len() > 1)
    {
      local navId = null
      for (local i = 0; i < ::shortcutsList.len(); i++)
      {
        let entry = ::shortcutsList[i]
        if (entry.type == CONTROL_TYPE.SECTION)
          navId = entry.id
        if (entry.id != item.id)
          continue

        let curItem = ::u.search(navItems, @(it) it.id == navId)
        if (curItem != null)
          navigationHandlerWeak.setCurrentItem(curItem)

        break
      }
    }
  }

  function onUpdate(obj, dt)
  {
    if (!::preset_changed)
      return

    initMainParams()
    updateAxisControlsHandlerParams()
    ::preset_changed = false
    if (forceLoadWizard)
    {
      forceLoadWizard = false
      onControlsWizard()
    }
  }

  function initShortcutsNames()
  {
    let axisScNames = []
    modifierSymbols = {}

    foreach (item in shortcutsAxisListModule.types)
    {
      if (item.type != CONTROL_TYPE.AXIS_SHORTCUT || ::isInArray(item.id, axisScNames))
        continue

      axisScNames.append(item.id)
      if ("symbol" in item)
        modifierSymbols[item.id] <- ::loc(item.symbol) + ::loc("ui/colon")
    }

    shortcutNames = []
    shortcutItems = []

    let addShortcutNames = function(arr)
    {
      for(local i=0; i < arr.len(); i++)
        if (arr[i].type == CONTROL_TYPE.SHORTCUT)
        {
          arr[i].shortcutId = shortcutNames.len()
          shortcutNames.append(arr[i].id)
          shortcutItems.append(arr[i])
        }
    }
    addShortcutNames(::shortcutsList)
    addShortcutNames(shortcutsAxisListModule.types)

    for(local i=0; i < ::shortcutsList.len(); i++)
    {
      let item = ::shortcutsList[i]

      if (item.type != CONTROL_TYPE.AXIS)
        continue

      item.modifiersId = {}
      foreach(name in axisScNames)
      {
        item.modifiersId[name] <- shortcutNames.len()
        shortcutNames.append(item.axisName + ((name=="")?"" : "_" + name))
        shortcutItems.append(item)
      }
    }
  }

  function getSymbol(name)
  {
    if (name in modifierSymbols)
      return "<color=@axisSymbolColor>" + modifierSymbols[name] + "</color>"
    return ""
  }

  function updateAxisText(device, item)
  {
    let itemTextObj = scene.findObject("txt_sc_" + item.id)
    if (!::checkObj(itemTextObj))
      return

    if (device == null)
    {
      itemTextObj.setValue(::loc("joystick/no_available_joystick"))
      return
    }

    let axis = item.axisIndex >= 0
      ? curJoyParams.getAxis(item.axisIndex)
      : ::ControlsPreset.getDefaultAxis()
    local axisText = ""
    local data = ""
    let curPreset = ::g_controls_manager.getCurPreset()
    if (axis.axisId >= 0)
      axisText = ::remapAxisName(curPreset, axis.axisId)

    if ("modifiersId" in item)
    {
      if ("" in item.modifiersId)
      {
        let activationShortcut = ::get_shortcut_text({shortcuts = shortcuts, shortcutId = item.modifiersId[""], cantBeEmpty = false})
        if (activationShortcut != "")
          data += activationShortcut + " + "
      }
      if (axisText!="")
        data += ::addHotkeyTxt(getSymbol("") + axisText, "")

      //--- options controls list  ---
      foreach(modifier, id in item.modifiersId)
        if (modifier != "")
        {
          let scText = ::get_shortcut_text({shortcuts = shortcuts, shortcutId = id, cantBeEmpty = false})
          if (scText!="")
          {
            data += (data=="" ? "" : ";  ") +
              getSymbol(modifier) +
              scText;
          }
        }
    } else
      data = ::addHotkeyTxt(axisText)

    let notAssignedId = ::find_in_array(notAssignedAxis, item)
    if (data == "")
    {
      data = ::loc("joystick/axis_not_assigned")
      if (notAssignedId<0)
        notAssignedAxis.append(item)
    } else
      if (notAssignedId>=0)
        notAssignedAxis.remove(notAssignedId)

    itemTextObj.setValue(data)
  }

  function updateSceneOptions()
  {
    let device = ::joystick_get_default()

    for(local i=0; i < ::shortcutsList.len(); i++)
    {
      if (::shortcutsList[i].type == CONTROL_TYPE.AXIS && ::shortcutsList[i].axisIndex>=0)
        updateAxisText(device, ::shortcutsList[i])
      else
      if (::shortcutsList[i].type== CONTROL_TYPE.SLIDER)
        updateSliderValue(::shortcutsList[i])
    }
  }

  function getRowIdx(rowObj)
  {
    let id = rowObj?.id
    if (!id || id.len() <= 10 || id.slice(0, 10) != "table_row_")
      return -1
    return id.slice(10).tointeger()
  }

  function getRowIdxBYId(id)
  {
    return ::shortcutsList.findindex(@(s) s.id == id) ?? -1
  }

  getCurItem = @() curShortcut
  getScById = @(scId) ::shortcutsList?[(scId ?? "-1").tointeger()]

  function onScHover(obj) {
    if (!::show_console_buttons)
      return
    curShortcut = getScById(obj?.scId)
    updateButtonsChangeValue()
  }

  function onScUnHover(obj) {
    if (!::show_console_buttons || curShortcut != getScById(obj?.scId))
      return
    curShortcut = null
    updateButtonsChangeValue()
  }

  function onScClick(obj) {
    let sc = getScById(obj?.scId)
    if (sc == null)
      return
    if (sc == curShortcut) {
      obj.selected = "no"
      curShortcut = null
      curShortcutBtn = null
    }
    else {
      if (::check_obj(curShortcutBtn))
        curShortcutBtn.selected = "no"
      obj.selected = "yes"
      curShortcut = sc
      curShortcutBtn = obj
    }
    updateButtonsChangeValue()
  }

  function onScDblClick(obj)
  {
    let sc = getScById(obj?.scId)
    if (sc == null)
      return
    if (sc != curShortcut)
      onScClick(obj)
    onTblDblClick()
  }

  function applyAirHelpersChange(obj = null)
  {
    if (isAircraftHelpersChangePerformed)
      return
    isAircraftHelpersChangePerformed = true

    if (::checkObj(obj))
    {
      let valueIdx = obj.getValue()
      local item = null
      for(local i = 0; i < ::shortcutsList.len(); i++)
        if (obj?.id == ::shortcutsList[i].id)
        {
          item = ::shortcutsList[i]
          break
        }
      if (item != null && "optionType" in item)
        ::set_option(item.optionType, valueIdx)
    }

    let options = ::u.values(::g_aircraft_helpers.controlHelpersOptions)
    foreach (optionId in options)
    {
      if (optionId == ::USEROPT_HELPERS_MODE)
        continue
      let option = ::get_option(optionId)
      for (local i = 0; i < ::shortcutsList.len(); i++)
        if (::shortcutsList[i]?.optionType == optionId)
        {
          let object = scene.findObject(::shortcutsList[i].id)
          if (::checkObj(object) && object.getValue() != option.value)
            object.setValue(option.value)
        }
    }

    curJoyParams.mouseJoystick = ::getTblValue("mouseJoystick",
      ::g_controls_manager.getCurPreset().params, false)

    isAircraftHelpersChangePerformed = false
  }

  function onAircraftHelpersChanged(obj = null)
  {
    if (isAircraftHelpersChangePerformed)
      return

    applyAirHelpersChange(obj)
    doControlsGroupChangeDelayed(obj)
  }

  function onOptionsFilter(obj = null)
  {
    applyAirHelpersChange(obj)

    if (!filterObjId)
      return

    let filterObj = scene.findObject(filterObjId)
    if (!::checkObj(filterObj))
      return

    let filterId = filterObj.getValue()
    if (!(filterId in filterValues))
      return

    if (!::can_change_helpers_mode() && filter!=null)
    {
      foreach(idx, value in filterValues)
        if (value == filter)
        {
          if (idx != filterId)
            msgBox("cant_change_controls", ::loc("msgbox/tutorial_controls_type_locked"),
                   [["ok", (@(filterObj, idx) function() {
                       if (::checkObj(filterObj))
                         filterObj.setValue(idx)
                     })(filterObj, idx)
                   ]], "ok")
          break
        }
      return
    }
    ::set_control_helpers_mode(filterId);
    filter = filterValues[filterId];
    fillControlGroupsList();
    //doControlsGroupChange();
  }

  function selectRowByRowIdx(idx)
  {
    let controlTblObj = scene.findObject(optionTableId)
    if (!::checkObj(controlTblObj) || idx < 0)
      return

    let id = "table_row_" + idx
    for(local i = 0; i < controlTblObj.childrenCount(); i++) {
      let child = controlTblObj.getChild(i)
      if (child.id == id)
        child.scrollToView()
    }
  }

  function getFilterObj()
  {
    if (!::check_obj(scene) || !filterObjId)
      return null
    return scene.findObject(filterObjId)
  }

  delayedControlsGroupStrated = false
  function doControlsGroupChangeDelayed(obj = null)
  {
    delayedControlsGroupStrated = true
    guiScene.performDelayed(this, function()
    {
      delayedControlsGroupStrated = false
      let filterOption = ::get_option(::USEROPT_HELPERS_MODE)
      let filterObj = getFilterObj()
      if (::checkObj(filterObj) && filterObj.getValue() != filterOption.value)
        filterObj.setValue(filterOption.value)
      doControlsGroupChange(true)
    })
  }

  function updateHidden()
  {
    for(local i = 0; i < ::shortcutsList.len(); i++)
    {
      let item = ::shortcutsList[i]
      local show = true
      local canBeHidden = true

      if ("filterHide" in item)
      {
        show = !isInArray(filter, item.filterHide)
      } else
      if ("filterShow" in item)
      {
        show = isInArray(filter, item.filterShow)
      } else
        canBeHidden = false

      if ("showFunc" in item)
      {
        show = show && item.showFunc.bindenv(this)()
        canBeHidden = true
      }
      if (!canBeHidden)
        continue

      item.isHidden = !show
    }
  }

  function optionsFilterApply()
  {
    updateHidden()
    let mainTbl = scene.findObject(optionTableId)
    if (!::checkObj(mainTbl))
      return

    let totalRows = mainTbl.childrenCount()

    for(local i=0; i<totalRows; i++)
    {
      let obj = mainTbl.getChild(i)
      let itemIdx = getRowIdx(obj)
      if (itemIdx < 0)
        continue

      let item = ::shortcutsList[itemIdx]
      let show = !item.isHidden

      if (obj)
      {
        obj.hiddenTr = show ? "no" : "yes"
        obj.inactive = (show && item.type != CONTROL_TYPE.HEADER
          && item.type != CONTROL_TYPE.SECTION) ? null : "yes"
      }
    }

    showSceneBtn("btn_preset", filter!=globalEnv.EM_MOUSE_AIM)
    showSceneBtn("btn_defaultpreset", filter==globalEnv.EM_MOUSE_AIM)

    dontCheckControlsDupes = ::refillControlsDupes()
  }

  function loadPresetWithMsg(msg, presetSelected, askKeyboardDefault=false)
  {
    msgBox(
      "controls_restore_question", msg,
      [
        ["yes", function() {
          if (askKeyboardDefault)
          {
            let presetNames = ::recomended_control_presets
            let presets = presetNames.map(@(name) [
              name,
              function() {
                applySelectedPreset(::get_controls_preset_by_selected_type(name).fileName)
              }
            ])
            msgBox("ask_kbd_type", ::loc("controls/askKeyboardWasdType"), presets, "classic")
            return
          }

          local preset = "empty_ver1"
          let opdata = ::get_option(::USEROPT_CONTROLS_PRESET)
          if (presetSelected in opdata.values)
            preset = opdata.values[presetSelected]
          else
            forceLoadWizard = ::is_platform_pc

          preset = ::g_controls_presets.parsePresetName(preset)
          preset = ::g_controls_presets.getHighestVersionPreset(preset)
          applySelectedPreset(preset.fileName)
          resetFastVoiceMessages()
        }],
        ["no", @() null],
      ], "no"
    )
  }

  function applySelectedPreset(preset)
  {
    resetDefaultControlSettings()
    ::apply_joy_preset_xchange(preset);
    ::broadcastEvent("ControlsPresetChanged")
  }

  function onClearAll()
  {
    backAfterSave = false
    doApply()
    loadPresetWithMsg(::loc("hotkeys/msg/clearAll"), -1)
  }

  function onDefaultPreset()
  {
    backAfterSave = false
    doApply()
    loadPresetWithMsg(::loc("controls/askRestoreDefaults"), 0, isPlatformPC)
  }

  function onButtonReset()
  {
    let item = getCurItem()
    if (!item) return
    if (item.type == CONTROL_TYPE.AXIS)
      return onAxisReset()
    if (!(item.shortcutId in shortcuts))
      return

    guiScene.performDelayed(this, function() {
      if (scene && scene.isValid())
      {
        let obj = scene.findObject("controls_input_root")
        if (obj) guiScene.destroyElement(obj)
      }

      if (!item) return

      shortcuts[item.shortcutId] = []
      ::set_controls_preset("")
      ::broadcastEvent("ControlsChangedShortcuts", {changedShortcuts = [item.shortcutId]})
    })
  }

  function onTblSelect()
  {
    updateButtonsChangeValue()
  }

  function updateButtonsChangeValue()
  {
    let item = getCurItem()
    let isShortcut = item != null && (item.type == CONTROL_TYPE.SHORTCUT || item.type == CONTROL_TYPE.AXIS_SHORTCUT)
    let isAxis = item != null && item.type == CONTROL_TYPE.AXIS

    showSceneBtn("btn_reset_shortcut", isShortcut)
    showSceneBtn("btn_reset_axis", isAxis)
    let btnA = showSceneBtn("btn_assign", isShortcut || isAxis)
    btnA.setValue(isAxis ? ::loc("mainmenu/btnEditAxis") : ::loc("mainmenu/btnAssign"))

    checkCurrentNavagationSection()
  }

  function onTblDblClick()
  {
    let item = getCurItem()
    if (!item) return

    if (item.type == CONTROL_TYPE.AXIS)
      openAxisBox(item)
    else if (item.type == CONTROL_TYPE.SHORTCUT || item.type == CONTROL_TYPE.AXIS_SHORTCUT)
      openShortcutInputBox()
    else if (item.type == CONTROL_TYPE.BUTTON)
      doItemAction(item)
  }

  function openShortcutInputBox()
  {
    ::assignButtonWindow(this, onAssignButton)
  }

  function onAssignButton(dev, btn)
  {
    if (dev.len() > 0 && dev.len() == btn.len())
    {
      let item = getCurItem()
      if (item)
        bindShortcut(dev, btn, item.shortcutId)
    }
  }

  function doBind(devs, btns, shortcutId)
  {
    let event = shortcuts[shortcutId]
    event.append({dev = devs, btn = btns})
    if (event.len() > max_shortcuts)
      event.remove(0)

    ::set_controls_preset(""); //custom mode
    ::broadcastEvent("ControlsChangedShortcuts", {changedShortcuts = [shortcutId]})
  }

  function updateShortcutText(shortcutId)
  {
    if (!(shortcutId in shortcuts))
      return

    let item = shortcutItems[shortcutId]
    let obj = scene.findObject("txt_sc_"+shortcutNames[shortcutId])

    if (obj)
      obj.setValue(::get_shortcut_text({shortcuts = shortcuts, shortcutId = shortcutId}))

    if (item.type == CONTROL_TYPE.AXIS)
    {
      let device = ::joystick_get_default()
      if (device != null)
        updateAxisText(device, item)
    }
  }

  function bindShortcut(devs, btns, shortcutId)
  {
    if (!(shortcutId in shortcuts))
      return false

    let curBinding = findButtons(devs, btns, shortcutId)
    if (!curBinding || curBinding.len() == 0)
    {
      doBind(devs, btns, shortcutId)
      return false
    }

    for(local i = 0; i < curBinding.len(); i++)
      if (curBinding[i][0]==shortcutId)
        return false

    let msg = ::loc("hotkeys/msg/unbind_question", {
      action = ::g_string.implode(
        curBinding.map((@(b) ::loc("hotkeys/"+shortcutNames[b[0]])).bindenv(this)),
        ::loc("ui/comma")
      )
    })
    msgBox("controls_bind_existing_shortcut", msg, [
      ["add", (@(curBinding, devs, btns, shortcutId) function() {
        doBind(devs, btns, shortcutId)
      })(curBinding, devs, btns, shortcutId)],
      ["replace", (@(curBinding, devs, btns, shortcutId) function() {
        for(local i = curBinding.len() - 1; i >= 0; i--)
        {
          let binding = curBinding[i]
          if (!(binding[1] in shortcuts[binding[0]]))
            continue

          shortcuts[binding[0]].remove(binding[1])
          updateShortcutText(binding[0])
        }
        doBind(devs, btns, shortcutId)
      })(curBinding, devs, btns, shortcutId)],
      ["cancel", function() { }],
    ], "cancel")
    return true
  }

  function findButtons(devs, btns, shortcutId)
  {
    let visibilityMap = getShortcutsVisibilityMap()

    if (::find_in_array(dontCheckControlsDupes, shortcutNames[shortcutId]) >= 0)
      return null

    let res = []

    foreach (index, event in shortcuts)
      if ((shortcutItems[index].checkGroup & shortcutItems[shortcutId].checkGroup) &&
        ::getTblValue(shortcutNames[index], visibilityMap) &&
        (shortcutItems[index]?.conflictGroup == null ||
          shortcutItems[index]?.conflictGroup != shortcutItems[shortcutId]?.conflictGroup ||
          index == shortcutId))
        foreach (button_index, button in event)
        {
          if (!button || button.dev.len() != devs.len())
            continue
          local numEqual = 0
          for (local i = 0; i < button.dev.len(); i++)
            for (local j = 0; j < devs.len(); j++)
              if ((button.dev[i] == devs[j]) && (button.btn[i] == btns[j]))
                numEqual++

          if (numEqual == btns.len() && ::find_in_array(dontCheckControlsDupes, shortcutNames[index]) < 0)
            res.append([index, button_index])
        }
    return res
  }

  getAxisHandlerParams = @() {
    curJoyParams = curJoyParams,
    shortcuts = shortcuts,
    shortcutItems = shortcutItems
  }

  function openAxisBox(axisItem)
  {
    if (!curJoyParams || !axisItem || axisItem.axisIndex < 0 )
      return

    let handler = ::handlersManager.loadHandler(::gui_handlers.AxisControls,
      getAxisHandlerParams().__update({ axisItem = axisItem }))
    axisControlsHandlerWeak = handler.weakref()
  }

  function updateAxisControlsHandlerParams() {
    if (axisControlsHandlerWeak?.isValid() ?? false)
      axisControlsHandlerWeak.setShortcutsParams(getAxisHandlerParams())
  }

  function onAxisReset()
  {
    local axisMode = -1
    let item = getCurItem()
    if (item && item.type == CONTROL_TYPE.AXIS)
      axisMode = item.axisIndex

    if (axisMode<0)
      return

    ::set_controls_preset("");
    curJoyParams.resetAxis(axisMode)

    if (item)
      foreach(name, idx in item.modifiersId)
        shortcuts[idx] = []

    curJoyParams.bindAxis(axisMode, -1)
    let device = ::joystick_get_default()
    curJoyParams.applyParams(device)
    updateSceneOptions()

    ::broadcastEvent("ControlsChangedAxes", {changedAxes = [item]})
  }

  function setAxisBind(axisIdx, axisNum, axisName)
  {
    ::set_controls_preset("");
    curJoyParams.bindAxis(axisIdx, axisNum)
    let device = ::joystick_get_default()
    curJoyParams.applyParams(device)
    updateSceneOptions()

    let axisItem = getShortcutById(axisName)
    ::broadcastEvent("ControlsChangedAxes", {changedAxes = [axisItem]})
  }

  function onChangeAxisRelative(obj)
  {
    if (!obj)
      return

    let isRelative = obj.getValue() == 1
    local txtObj = scene.findObject("txt_rangeMax")
    if (txtObj) txtObj.setValue(::loc(isRelative? "hotkeys/rangeInc" : "hotkeys/rangeMax"))
    txtObj = scene.findObject("txt_rangeMin")
    if (txtObj) txtObj.setValue(::loc(isRelative? "hotkeys/rangeDec" : "hotkeys/rangeMin"))
  }

  function getUnmappedByGroups()
  {
    local currentHeader = null
    let unmapped = []
    let mapped = {}

    foreach(item in ::shortcutsList)
    {
      if (item.type == CONTROL_TYPE.HEADER)
      {
        let isHeaderVisible = !("showFunc" in item) || item.showFunc.call(this)
        if (isHeaderVisible)
          currentHeader = "hotkeys/" + item.id
        else
          currentHeader = null
      }
      let isRequired = typeof(item.checkAssign) == "function" ? item.checkAssign() : item.checkAssign
      if (!currentHeader || item.isHidden || !isRequired)
        continue
      if (filter == globalEnv.EM_MOUSE_AIM && !item.reqInMouseAim)
        continue

      if (item.type == CONTROL_TYPE.SHORTCUT)
      {
        if ((item.shortcutId in shortcuts)
            && !::g_controls_utils.isShortcutMapped(shortcuts[item.shortcutId]))
          unmapped.append({ item = item, header = currentHeader })
        else if ("alternativeIds" in item)
        {
          mapped[item.id] <- true
          foreach (alternativeId in item.alternativeIds)
            mapped[alternativeId] <- true
        }
      }
      else if (item.type == CONTROL_TYPE.AXIS)
      {
        local isMapped = false
        if (::is_axis_mapped_on_mouse(item.id, filter, curJoyParams))
          isMapped = true

        if (!isMapped)
        {
          let axisId = item.axisIndex >= 0
            ? curJoyParams.getAxis(item.axisIndex).axisId : -1
          if (axisId >= 0 || !("modifiersId" in item))
            isMapped = true
        }

        if (!isMapped)
          foreach(name in ["rangeMin", "rangeMax"])
            if (name in item.modifiersId)
            {
              let id = item.modifiersId[name]
              if (!(id in shortcuts) || ::g_controls_utils.isShortcutMapped(shortcuts[id]))
              {
                isMapped = true
                break
              }
            }

        if (!isMapped)
          unmapped.append({ item = item, header = currentHeader })
        else if ("alternativeIds" in item)
        {
          mapped[item.id] <- true
          foreach (alternativeId in item.alternativeIds)
            mapped[alternativeId] <- true
        }
      }
    }

    let unmappedByGroups = {}
    let unmappedList = []
    foreach(unmappedItem in unmapped)
    {
      let item = unmappedItem.item
      if ("alternativeIds" in item || mapped?[item.id])
        continue

      let header = unmappedItem.header
      local unmappedGroup = unmappedByGroups?[header]
      if (!unmappedGroup)
      {
        unmappedGroup = { id = header, list = [] }
        unmappedByGroups[header] <- unmappedGroup
        unmappedList.append(unmappedGroup)
      }

      if (item.type == CONTROL_TYPE.SHORTCUT)
        unmappedGroup.list.append("hotkeys/" + shortcutNames[item.shortcutId])
      else if (item.type == CONTROL_TYPE.AXIS)
        unmappedGroup.list.append("controls/" + item.axisName)
    }
    return unmappedList
  }

  function updateSliderValue(item)
  {
    let valueObj = scene.findObject(item.id+"_value")
    if (!valueObj) return
    let vlObj = scene.findObject(item.id)
    if (!vlObj) return

    let value = vlObj.getValue()
    local valueText = ""
    if ("showValueMul" in item)
      valueText = (item.showValueMul * value).tostring()
    else
      valueText = value * (("showValuePercMul" in item)? item.showValuePercMul : 1) + "%"
    valueObj.setValue(valueText)
  }

  function onSliderChange(obj)
  {
    if (obj?.id)
      updateSliderValue(shortcutsListModule?[obj.id])
  }

  function onActionButtonClick(obj) {
    if (!obj?.id)
      return

    let item = shortcutsListModule?[obj.id]
    doItemAction(item)
  }

  function doItemAction(item) {
    saveShortcutsAndAxes()
    if (item.onClick())
      doControlsGroupChangeDelayed()
  }

  function doApplyJoystick() {
    if (curJoyParams != null)
      doApplyJoystickImpl(shortcutsListModule.types, curJoyParams)
  }

  function doApplyJoystickImpl(itemsList, setValueContext) {
    foreach (item in itemsList)
    {
      if ((("condition" in item) && !item.condition())
          || item.type == CONTROL_TYPE.SHORTCUT)
        continue

      let obj = scene.findObject(item.id)
      if (!::checkObj(obj)) continue

      if ("optionType" in item)
      {
        let value = obj.getValue()
        ::set_option(item.optionType, value)
        continue
      }

      if (item.type== CONTROL_TYPE.MOUSE_AXIS && ("axis_num" in item))
      {
        let value = obj.getValue()
        if (value in item.values)
          if (item.values[value] == "none")
            curJoyParams.setMouseAxis(item.axis_num, "")
          else
            curJoyParams.setMouseAxis(item.axis_num, item.values[value])
      }

      if (!("setValue" in item))
        continue

      let value = obj.getValue()
      if ((item.type == CONTROL_TYPE.SPINNER || item.type== CONTROL_TYPE.DROPRIGHT || item.type== CONTROL_TYPE.LISTBOX)
          && (item.options.len() > 0))
        if (value in item.options)
          item.setValue(setValueContext, value)

      if (item.type == CONTROL_TYPE.SLIDER)
        item.setValue(setValueContext, value)
      else if (item.type == CONTROL_TYPE.SWITCH_BOX)
        item.setValue(setValueContext, value)
    }

    ::joystick_set_cur_settings(curJoyParams)
  }

  function onEventControlsPresetChanged(p)
  {
    ::preset_changed = true
  }

  function onEventControlsChangedShortcuts(p)
  {
    foreach (sc in (p?.changedShortcuts ?? []))
      updateShortcutText(sc)
  }

  function onEventControlsChangedAxes(p)
  {
    let device = ::joystick_get_default()
    foreach (axis in p.changedAxes)
      updateAxisText(device, axis)
  }

  function doApply()
  {
    if (!::checkObj(scene))
      return

    applyApproved = true
    saveShortcutsAndAxes()
    save(false)
    backAfterSave = true
  }

  function buildMsgFromGroupsList(list)
  {
    local text = ""
    let colonLocalized = ::loc("ui/colon")
    foreach(groupIdx, group in list)
    {
      if (groupIdx > 0)
        text += "\n"
      text += ::loc(group.id) + colonLocalized + "\n"
      foreach(idx, locId in group.list)
      {
        if (idx != 0)
          text += ", "
        text += ::loc(locId)
      }
    }
    return text
  }

  function changeControlsWindowType(value)
  {
    if (changeControlsMode==value)
      return

    changeControlsMode = value
    if (value)
      backSceneFunc = ::gui_start_controls_console
    ::switchControlsMode(value)
  }

  function goBack()
  {
    onApply()
  }

  function onApply()
  {
    doApply()
  }

  function closeWnd()
  {
    restoreMainOptions()
    base.goBack()
  }

  function afterSave()
  {
    if (!backAfterSave)
      return

    let reqList = getUnmappedByGroups()
    if (!reqList.len())
      return closeWnd()

    let msg = ::loc("controls/warningUnmapped") + ::loc("ui/colon") + "\n" +
      buildMsgFromGroupsList(reqList)
    msgBox("not_all_mapped", msg,
    [
      ["resetToDefaults", function()
      {
        changeControlsWindowType(false)
        guiScene.performDelayed(this, onDefaultPreset)
      }],
      ["backToControls", function() {
        changeControlsWindowType(false)
      }],
      ["stillContinue", function()
      {
        guiScene.performDelayed(this, closeWnd)
      }]
    ], "backToControls")
  }

  function onMouseWheel(obj)
  {
    let item = getCurItem()
    if (!item || !("values" in item) || !obj)
      return

    let value = obj.getValue()
    let axisName = ::getTblValue(value, item.values)
    let zoomPostfix = "zoom"
    if (axisName && axisName.len() >= zoomPostfix.len() && axisName.slice(-4) == zoomPostfix)
    {
      let zoomAxisIndex = ::get_axis_index(axisName)
      if (zoomAxisIndex<0) return

      let axis = curJoyParams.getAxis(zoomAxisIndex)
      if (axis.axisId<0) return

      if (filter==globalEnv.EM_MOUSE_AIM)
      {
        setAxisBind(zoomAxisIndex, -1, axisName)
        return
      }

      let curPreset = ::g_controls_manager.getCurPreset()
      let msg = format(::loc("msg/zoomAssignmentsConflict"),
        ::remapAxisName(curPreset, axis.axisId))
      guiScene.performDelayed(this, @()
        msgBox("zoom_axis_assigned", msg,
        [
          ["replace", (@(zoomAxisIndex) function() {
            setAxisBind(zoomAxisIndex, -1, axisName)
          })(zoomAxisIndex)],
          ["cancel", function() {
            if (::check_obj(obj))
              obj.setValue(0)
          }]
        ], "replace"))
    }
    else if (axisName && (axisName == "camx" || axisName == "camy")
      && item.axis_num == MouseAxis.MOUSE_SCROLL)
    {
      let isMouseView = AIR_MOUSE_USAGE.VIEW ==
        ::g_aircraft_helpers.getOptionValue(::USEROPT_MOUSE_USAGE)
      let isMouseViewWhenNoAim = AIR_MOUSE_USAGE.VIEW ==
        ::g_aircraft_helpers.getOptionValue(::USEROPT_MOUSE_USAGE_NO_AIM)

      if (isMouseView || isMouseViewWhenNoAim)
      {
        let msg = isMouseView
          ? ::loc("msg/replaceMouseViewToScroll")
          : ::loc("msg/replaceMouseViewToScrollNoAim")
        guiScene.performDelayed(this, @()
          msgBox("mouse_used_for_view", msg,
          [
            ["replace", function() {
              ::set_controls_preset("")
              ::g_aircraft_helpers.setOptionValue(
                ::USEROPT_MOUSE_USAGE, AIR_MOUSE_USAGE.AIM)
              ::g_aircraft_helpers.setOptionValue(
                ::USEROPT_MOUSE_USAGE_NO_AIM, AIR_MOUSE_USAGE.JOYSTICK)
              onAircraftHelpersChanged(null)
            }],
            ["cancel", function() {
              if (::check_obj(obj))
                obj.setValue(0)
            }]
          ], "cancel"))
      }
    }
  }

  function onControlsHelp()
  {
    backAfterSave = false
    doApply()
    ::gui_modal_help(false, HELP_CONTENT_SET.CONTROLS)
  }

  function onControlsWizard()
  {
    backAfterSave = false
    doApply()
    ::gui_modal_controlsWizard()
  }

  function saveShortcutsAndAxes()
  {
    ::set_shortcuts(shortcuts, shortcutNames)
    doApplyJoystick()
  }

  function updateCurPresetForExport()
  {
    saveShortcutsAndAxes()
    ::g_controls_manager.clearGuiOptions()
    let curPreset = ::g_controls_manager.getCurPreset()
    let mainOptionsMode = getGuiOptionsMode()
    setGuiOptionsMode(::OPTIONS_MODE_GAMEPLAY)
    foreach (item in ::shortcutsList)
      if ("optionType" in item && item.optionType in ::user_option_name_by_idx)
      {
        let optionName = ::user_option_name_by_idx[item.optionType]
        let value = ::get_option(item.optionType).value
        if (value != null)
          curPreset.params[optionName] <- value
      }
    setGuiOptionsMode(mainOptionsMode)
    ::set_current_controls(curPreset, ::g_controls_manager.getShortcutGroupMap())
  }

  function onManageBackup()
  {
    if (!isValid()) //updateCurPresetForExport use scene objects, and no need open backup manager, if controls window is not valid
      return
    updateCurPresetForExport()
    ::gui_handlers.ControlsBackupManager.open()
  }

  function onExportToFile()
  {
    if (!isValid()) //updateCurPresetForExport use scene objects, and no need open export to file modal, if controls window is not valid
      return
    updateCurPresetForExport()

    if (isScriptOpenFileDialogAllowed())
    {
      ::gui_start_modal_wnd(::gui_handlers.FileDialog, {
        isSaveFile = true
        dirPath = ::get_save_load_path()
        pathTag = "controls"
        onSelectCallback = function(path) {
          let isSaved = ::export_current_layout_by_path(path)
          if (!isSaved)
            ::showInfoMsgBox(::loc("msgbox/errorSavingPreset"))
          return isSaved
        }
        extension = "blk"
        currentFilter = "blk"
      })
    }
    else if (!::export_current_layout())
      msgBox("errorSavingPreset", ::loc("msgbox/errorSavingPreset"),
             [["ok", function() {} ]], "ok", { cancel_fn = function() {}})
  }

  function onImportFromFile()
  {
    if (isScriptOpenFileDialogAllowed())
    {
      ::gui_start_modal_wnd(::gui_handlers.FileDialog, {
        isSaveFile = false
        dirPath = ::get_save_load_path()
        pathTag = "controls"
        onSelectCallback = function(path) {
          let isOpened = ::import_current_layout_by_path(path)
          if (isOpened)
            ::broadcastEvent("ControlsPresetChanged")
          else
            ::showInfoMsgBox($"{::loc("msgbox/errorLoadingPreset")}: {path}")
          return isOpened && ::is_last_load_controls_succeeded
        }
        extension = "blk"
        currentFilter = "blk"
      })
    }
    else
    {
      if (::import_current_layout())
        ::broadcastEvent("ControlsPresetChanged")
      else
        msgBox("errorLoadingPreset", ::loc("msgbox/errorLoadingPreset"),
               [["ok", function() {} ]], "ok", { cancel_fn = function() {}})
    }
  }

  function onOptionsListboxDblClick(obj) {}

  function getShortcutsVisibilityMap()
  {
    let helpersMode = ::getCurrentHelpersMode()
    local isHeaderShowed = true
    local isSectionShowed = true

    let visibilityMap = {}

    foreach (entry in ::shortcutsList)
    {
      let isShowed =
        (!("filterHide" in entry) || !::isInArray(helpersMode, entry.filterHide)) &&
        (!("filterShow" in entry) || ::isInArray(helpersMode, entry.filterShow)) &&
        (!("showFunc" in entry) || entry.showFunc.call(this))
      if (entry.type == CONTROL_TYPE.HEADER)
      {
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

::refillControlsDupes <- function refillControlsDupes()
{
  let arr = []
  for(local i = 0; i < ::shortcutsList.len(); i++)
  {
    let item = ::shortcutsList[i]
    if ((item.type == CONTROL_TYPE.SHORTCUT)
        && (item.isHidden || (("dontCheckDupes" in item) && item.dontCheckDupes)))
      arr.append(item.id)
  }
  return arr
}

let mkTextShortcutRow = ::kwarg(@(scId, id, trAdd, trName, shortcutText = "")
  "\n".concat("tr { {0} ".subst(trAdd),
    "td { width:t='@controlsLeftRow'; overflow:t='hidden'; optiontext{id:t='{0}'; text:t='{1}'; }}"
      .subst($"txt_{id}", trName),
    "td { width:t='pw-1@controlsLeftRow'; cellType:t='right'; padding-left:t='@optPad';",
      "shortcutCell { scId:t='{0}'; ".subst(scId),
        "on_hover:t='onScHover'; on_unhover:t='onScUnHover'; ",
        "on_click:t='onScClick'; on_dbl_click:t='onScDblClick'; ",
        "textareaNoTab {id:t='{0}'; pos:t='0, 0.5ph-0.5h'; position:t='relative'; text:t='{1}'; }"
          .subst($"txt_sc_{id}", shortcutText),
  "} } }\n"))

::buildHotkeyItem <- function buildHotkeyItem(rowIdx, shortcuts, item, params, even, rowParams = "")
{
  let hotkeyData = {
    id = "table_row_" + rowIdx
    markup = ""
    text = ""
  }

  if (("condition" in item) && !item.condition())
    return hotkeyData

  let trAdd = ::format("id:t='%s'; even:t='%s'; %s", hotkeyData.id, even? "yes" : "no", rowParams)
  local res = ""
  local elemTxt = ""
  local elemIdTxt = "controls/" + item.id

  if (item.type == CONTROL_TYPE.SECTION)
  {
    let hotkeyId = "hotkeys/" + item.id
    res = ::format("tr { %s inactive:t='yes';" +
                   "td { width:t='@controlsLeftRow'; overflow:t='visible';" +
                     "optionBlockHeader { text:t='#%s'; }}\n" +
                   "td { width:t='pw-1@controlsLeftRow'; }\n" +
                 "}\n", trAdd, hotkeyId)

    hotkeyData.text = ::g_string.utf8ToLower(::loc(hotkeyId))
    hotkeyData.markup = res
  }
  else if (item.type == CONTROL_TYPE.SHORTCUT || item.type == CONTROL_TYPE.AXIS_SHORTCUT)
  {
    let trName = "hotkeys/" + ((item.id=="")? "enable" : item.id)
    res = mkTextShortcutRow({
      scId = rowIdx
      id = item.id
      trAdd = trAdd
      trName = $"#{trName}"
      shortcutText = ::get_shortcut_text({shortcuts = shortcuts, shortcutId = item.shortcutId, strip_tags = true})
    })
    hotkeyData.text = ::g_string.utf8ToLower(::loc(trName))
    hotkeyData.markup = res
  }
  else if (item.type == CONTROL_TYPE.AXIS && item.axisIndex >= 0)
  {
    res = mkTextShortcutRow({
      scId = rowIdx
      id = item.id
      trAdd = trAdd
      trName = $"#controls/{item.id}"
    })
    hotkeyData.text = ::g_string.utf8ToLower(::loc("controls/"+item.id))
    hotkeyData.markup = res
  }
  else if (item.type == CONTROL_TYPE.SPINNER || item.type== CONTROL_TYPE.DROPRIGHT)
  {
    local createOptFunc = ::create_option_list
    if (item.type== CONTROL_TYPE.DROPRIGHT)
      createOptFunc = ::create_option_dropright

    let callBack = ("onChangeValue" in item)? item.onChangeValue : null

    if ("optionType" in item)
    {
      let config = ::get_option(item.optionType)
      elemIdTxt = "options/" + config.id
      elemTxt = createOptFunc(item.id, config.items, config.value, callBack, true)
    }
    else if ("options" in item && (item.options.len() > 0))
    {
      let value = ("value" in item)? item.value(params) : 0
      elemTxt = createOptFunc(item.id, item.options, value, callBack, true)
    }
    else
      dagor.debug("Error: No optionType nor options field");
  }
  else if (item.type== CONTROL_TYPE.SLIDER)
  {
    if ("optionType" in item)
    {
      let config = ::get_option(item.optionType)
      elemIdTxt = "options/" + config.id
      elemTxt = ::create_option_slider(item.id, config.value, "onSliderChange", true, "slider", config)
    }
    else
    {
      let value = ("value" in item)? item.value(params) : 50
      elemTxt = ::create_option_slider(item.id, value.tointeger(), "onSliderChange", true, "slider", item)
    }

    elemTxt += format("activeText{ id:t='%s'; margin-left:t='0.01@sf' } ", item.id+"_value")
  }
  else if (item.type== CONTROL_TYPE.SWITCH_BOX)
  {
    local config = null
    if ("optionType" in item)
    {
      config = ::get_option(item.optionType)
      elemIdTxt = "options/" + config.id
      config.id = item.id
    }
    else
    {
      let value = ("value" in item)? item.value(params) : false
      config = {
        id = item.id
        value = value
      }
    }
    config.cb <- ::getTblValue("onChangeValue", item)
    elemTxt = ::create_option_switchbox(config)
  }
  else if (item.type== CONTROL_TYPE.MOUSE_AXIS && (item.values.len() > 0) && ("axis_num" in item))
  {
    let value = params.getMouseAxis(item.axis_num)
    let callBack = ("onChangeValue" in item)? item.onChangeValue : null
    let options = []
    for (local i = 0; i < item.values.len(); i++)
      options.append("#controls/" + item.values[i])
    local sel = ::find_in_array(item.values, value)
    if (!(sel in item.values))
      sel = 0
    elemTxt = ::create_option_list(item.id, options, sel, callBack, true)
  }
  else if (item.type == CONTROL_TYPE.BUTTON)
  {
    elemIdTxt = "";
    elemTxt = ::handyman.renderCached("%gui/commonParts/button", {
      id = item.id
      text = "#controls/" + item.id
      funcName = "onActionButtonClick"
    })
  }
  else
  {
    res = "tr { display:t='hide'; td {} td { tdiv{} } }"
    ::dagor.debug("Error: wrong shortcut - " + item.id)
  }

  if (elemTxt!="")
  {
    res = ::format("tr { css-hier-invalidate:t='all'; width:t='pw'; %s " +
                   "td { width:t='@controlsLeftRow'; overflow:t='hidden'; optiontext { text:t ='%s'; }} " +
                   "td { width:t='pw-1@controlsLeftRow'; cellType:t='right'; padding-left:t='@optPad'; %s } " +
                 "}\n",
                 trAdd, elemIdTxt != "" ? "#" + elemIdTxt : "", elemTxt)
    hotkeyData.text = ::g_string.utf8ToLower(::loc(elemIdTxt))
    hotkeyData.markup = res
  }
  return hotkeyData
}

::get_shortcut_text <- ::kwarg(function get_shortcut_text(shortcuts,
  shortcutId, cantBeEmpty = true, strip_tags = false, preset = null, colored = true)
{
  if (!(shortcutId in shortcuts))
    return ""

  preset = preset || ::g_controls_manager.getCurPreset()
  local data = ""
  for (local i = 0; i < shortcuts[shortcutId].len(); i++)
  {
    local text = ""
    let sc = shortcuts[shortcutId][i]

    for (local j = 0; j < sc.dev.len(); j++)
      text += ((j != 0)? " + ":"") + ::getLocalizedControlName(preset, sc.dev[j], sc.btn[j])

    if (text=="")
      continue

    data = ::addHotkeyTxt(strip_tags? ::g_string.stripTags(text) : text, data, colored)
  }

  if (cantBeEmpty && data=="")
    data = "---"

  return data
})

::addHotkeyTxt <- function addHotkeyTxt(hotkeyTxt, baseTxt="", colored = true)
{
  hotkeyTxt = colored ? ::colorize("hotkeyColor", hotkeyTxt) : hotkeyTxt
  return ::loc("ui/comma").join([ baseTxt, hotkeyTxt ], true)
}

//works like get_shortcut_text, but returns only first bound shortcut for action
//needed wor hud
::get_first_shortcut_text <- function get_first_shortcut_text(shortcutData)
{
  local text = ""
  if (shortcutData.len() > 0)
  {
    let sc = shortcutData[0]

    let curPreset = ::g_controls_manager.getCurPreset()
    for (local j = 0; j < sc.btn.len(); j++)
      text += ((j != 0)? " + " : "") + ::getLocalizedControlName(curPreset, sc.dev[j], sc.btn[j])
  }

  return text
}

::get_shortcut_gamepad_textures <- function get_shortcut_gamepad_textures(shortcutData)
{
  let res = []
  foreach(sc in shortcutData)
  {
    if (sc.dev.len() <= 0 || sc.dev[0] != ::JOYSTICK_DEVICE_0_ID)
      continue

    for (local i = 0; i < sc.dev.len(); i++)
      res.append(gamepadIcons.getTextureByButtonIdx(sc.btn[i]))
    return res
  }
  return res
}

//*************************Functions***************************//

::applySelectedPreset <- function applySelectedPreset(presetName)
{
  if(::isInArray(presetName, ["keyboard", "keyboard_shooter"]))
    ::set_option(::USEROPT_HELPERS_MODE, globalEnv.EM_MOUSE_AIM)
  return ($"{controlsPresetConfigPath.value}config/hotkeys/hotkey." + presetName + ".blk")
}

::getSeparatedControlLocId <- function getSeparatedControlLocId(text)
{
  local txt = text
  local index_txt = ""

  if (txt.indexof("Button ") == 0) //"Button 1" in "Button" and "1"
    index_txt = " " + txt.slice("Button ".len())
  else if (txt.indexof("Button") == 0) //"Button1" in "Button" and "1"
    index_txt = " " + txt.slice("Button".len())

  if (index_txt != "")
    txt = ::loc("key/Button") + index_txt

  return txt
}

::getLocaliazedPS4controlName <- function getLocaliazedPS4controlName(text)
{
  return ::loc("xinp/" + text, "")
}

::getLocalizedControlName <- function getLocalizedControlName(preset, deviceId, buttonId)
{
  let text = preset.getButtonName(deviceId, buttonId)
  if (deviceId != ::STD_KEYBOARD_DEVICE_ID) {
    let locText = getLocaliazedPS4controlName(text)
    if (locText != "")
      return locText
  }

  let locText = ::loc("key/" + text, "")
  if (locText != "")
    return locText

  return ::getSeparatedControlLocId(text)
}

::remapAxisName <- function remapAxisName(preset, axisId)
{
  let text = preset.getAxisName(axisId)
  if (text == null)
    return "?"

  if (text.indexof("Axis ") == 0) //"Axis 1" in "Axis" and "1"
  {
    return ::loc("composite/axis")+text.slice("Axis ".len());
  }
  else if (text.indexof("Axis") == 0) //"Axis1" in "Axis" and "1"
  {
    return ::loc("composite/axis")+text.slice("Axis".len());
  }

  local locText = getLocaliazedPS4controlName(text)
  if (locText != "")
    return locText

  locText = ::loc("joystick/" + text, "")
  if (locText != "")
    return locText

  locText = ::loc("key/" + text, "")
  if (locText != "")
    return locText

  return text
}

::hackTextAssignmentForR2buttonOnPS4 <- function hackTextAssignmentForR2buttonOnPS4(mainText)
{
  if (isPlatformSony)
  {
    let hack = ::getLocaliazedPS4controlName("R2") + " + " + ::getLocaliazedPS4controlName("MouseLB")
    if (mainText.len() >= hack.len())
    {
      let replaceButtonText = ::getLocaliazedPS4controlName("R2")
      if (mainText.slice(0, hack.len()) == hack)
        mainText = replaceButtonText + mainText.slice(hack.len())
      else if (mainText.slice(mainText.len() - hack.len()) == hack)
        mainText = mainText.slice(0, mainText.len() - hack.len()) + replaceButtonText
    }
  }
  return mainText
}

::switchControlsMode <- function switchControlsMode(value)
{
  ::save_local_account_settings(PS4_CONTROLS_MODE_ACTIVATE, value)
}

::getUnmappedControlsForCurrentMission <- function getUnmappedControlsForCurrentMission()
{
  let gm = ::get_game_mode()
  if (gm == ::GM_BENCHMARK)
    return []

  let unit = getPlayerCurUnit()
  let helpersMode = ::getCurrentHelpersMode()
  let required = ::getRequiredControlsForUnit(unit, helpersMode)

  let unmapped = ::getUnmappedControls(required, helpersMode, true, false)
  if (::is_in_flight() && gm == ::GM_TRAINING)
  {
    let tutorialUnmapped = ::getUnmappedControlsForTutorial(::current_campaign_mission, helpersMode)
    foreach (id in tutorialUnmapped)
      ::u.appendOnce(id, unmapped)
  }
  return unmapped
}

::getCurrentHelpersMode <- function getCurrentHelpersMode()
{
  let difficulty = ::is_in_flight() ? ::get_mission_difficulty_int() : ::get_current_shop_difficulty().diffCode
  if (difficulty == 2)
    return (::is_platform_pc ? globalEnv.EM_FULL_REAL : globalEnv.EM_REALISTIC)
  let option = ::get_option_in_mode(::USEROPT_HELPERS_MODE, ::OPTIONS_MODE_GAMEPLAY)
  return option.values[option.value]
}

::getUnmappedControlsForTutorial <- function getUnmappedControlsForTutorial(missionId, helpersMode)
{
  local res = []

  local mis_file = null
  let chapters = ::get_meta_missions_info_by_chapters(::GM_TRAINING)
  foreach(chapter in chapters)
    foreach(m in chapter)
      if (m.name == missionId)
      {
        mis_file = m.mis_file
        break
      }
  if (mis_file==null)
    return res
  let missionBlk = blkFromPath(mis_file)
  if (!missionBlk?.triggers)
    return res

  let tutorialControlAliases = {
    ["ANY"]                = null,
    ["ID_CONTINUE"]        = null,
    ["ID_SKIP_CUTSCENE"]   = null,
    ["ID_FIRE"]            = "ID_FIRE_MGUNS",
    ["ID_TRANS_GEAR_UP"]   = "gm_throttle",
    ["ID_TRANS_GEAR_DOWN"] = "gm_throttle",
  }

  let isXinput = ::is_xinput_device()
  let isAllowedCondition = @(condition) condition?.gamepadControls == null || condition.gamepadControls == isXinput

  let conditionsList = []
  foreach (trigger in missionBlk.triggers)
  {
    if (typeof(trigger) != "instance")
      continue

    let condition = (trigger?.props.conditionsType != "ANY") ? "ALL" : "ANY"

    let shortcuts = []
    if (trigger?.conditions)
    {
      foreach (playerShortcutPressed in trigger.conditions % "playerShortcutPressed")
        if (playerShortcutPressed?.control && isAllowedCondition(playerShortcutPressed))
        {
          let id = playerShortcutPressed.control
          let alias = (id in tutorialControlAliases) ? tutorialControlAliases[id] : id
          if (alias && !::isInArray(alias, shortcuts))
            shortcuts.append(alias)
        }

      foreach (playerWhenOptions in trigger.conditions % "playerWhenOptions")
        if (playerWhenOptions?.currentView)
          conditionsList.append({ condition = "ONE", shortcuts = [ "ID_TOGGLE_VIEW" ] })

      foreach (unitWhenInArea in trigger.conditions % "unitWhenInArea")
        if (unitWhenInArea?.target == "gears_area")
          conditionsList.append({ condition = "ONE", shortcuts = [ "ID_GEAR" ] })

      foreach (unitWhenStatus in trigger.conditions % "unitWhenStatus")
        if (unitWhenStatus?.object_type == "isTargetedByPlayer")
          conditionsList.append({ condition = "ONE", shortcuts = [ "ID_LOCK_TARGET" ] })

      foreach (playerWhenCameraState in trigger.conditions % "playerWhenCameraState")
        if (playerWhenCameraState?.state == "fov")
          conditionsList.append({ condition = "ONE", shortcuts = [ "ID_ZOOM_TOGGLE" ] })
    }

    if (shortcuts.len())
      conditionsList.append({ condition = condition, shortcuts = shortcuts })
  }

  foreach (cond in conditionsList)
    if (cond.shortcuts.len() == 1)
      cond.condition = "ALL"

  for (local i = conditionsList.len() - 1; i >= 0; i--)
  {
    local duplicate = false
    for (local j = i - 1; j >= 0; j--)
      if (::u.isEqual(conditionsList[i], conditionsList[j]))
      {
        duplicate = true
        break
      }
    if (duplicate)
      conditionsList.remove(i)
  }

  let controlsList = []
  foreach (cond in conditionsList)
    foreach (id in cond.shortcuts)
      if (!::isInArray(id, controlsList))
        controlsList.append(id)
  let unmapped = ::getUnmappedControls(controlsList, helpersMode, false, false)

  foreach (cond in conditionsList)
  {
    if (cond.condition == "ALL")
      foreach (id in cond.shortcuts)
        if (::isInArray(id, unmapped) && !::isInArray(id, res))
          res.append(id)
  }

  foreach (cond in conditionsList)
  {
    if (cond.condition == "ANY" || cond.condition == "ONE")
    {
      local allUnmapped = true
      foreach (id in cond.shortcuts)
        if (!::isInArray(id, unmapped) || ::isInArray(id, res))
        {
          allUnmapped = false
          break
        }
      if (allUnmapped)
        foreach (id in cond.shortcuts)
          if (!::isInArray(id, res))
          {
            res.append(id)
            if (cond.condition == "ONE")
              break
          }
    }
  }

  res = ::getUnmappedControls(res, helpersMode, true, false)
  return res
}

let function getWeaponFeatures(weaponsList)
{
  let res = {
    gotMachineGuns = false
    gotCannons = false
    gotAdditionalGuns = false
    gotBombs = false
    gotTorpedoes = false
    gotMines = false
    gotRockets = false
    gotAGM = false // air-to-ground missiles, anti-tank guided missiles
    gotAAM = false // air-to-air missiles
    gotGuidedBombs = false
    gotGunnerTurrets = false
    gotSchraegeMusik = false
  }

  foreach (weaponSet in weaponsList)
    foreach (w in weaponSet) {
      if (!w?.blk || w?.dummy)
        continue

      if (w?.trigger == TRIGGER_TYPE.MACHINE_GUN)
        res.gotMachineGuns = true
      if (w?.trigger == TRIGGER_TYPE.CANNON)
        res.gotCannons = true
      if (w?.trigger == TRIGGER_TYPE.ADD_GUN)
        res.gotAdditionalGuns = true
      if (w?.trigger == TRIGGER_TYPE.BOMBS)
        res.gotBombs = true
      if (w?.trigger == TRIGGER_TYPE.TORPEDOES)
        res.gotTorpedoes = true
      if (w?.trigger == TRIGGER_TYPE.MINES)
        res.gotMines = true
      if (w?.trigger == TRIGGER_TYPE.ROCKETS)
        res.gotRockets = true
      if (w?.trigger == TRIGGER_TYPE.AGM || w?.trigger == TRIGGER_TYPE.ATGM)
        res.gotAGM = true
      if (w?.trigger == TRIGGER_TYPE.AAM)
        res.gotAAM = true
      if (w?.trigger == TRIGGER_TYPE.GUIDED_BOMBS)
        res.gotGuidedBombs = true
      if (::g_string.startsWith(w?.trigger ?? "", "gunner"))
        res.gotGunnerTurrets = true
      if (::is_platform_pc && w?.schraegeMusikAngle != null)
        res.gotSchraegeMusik = true
    }

  return res
}

::getRequiredControlsForUnit <- function getRequiredControlsForUnit(unit, helpersMode)
{
  local controls = []
  if (!unit || useTouchscreen)
    return controls

  let unitId = unit.name
  let unitType = unit.unitType

  let preset = ::g_controls_manager.getCurPreset()
  local actionBarShortcutFormat = null

  let unitBlk = ::get_full_unit_blk(unitId)
  let commonWeapons = getCommonWeapons(unitBlk, getLastPrimaryWeapon(unit))
  local weaponPreset = []

  let curWeaponPresetId = ::is_in_flight() ? ::get_cur_unit_weapon_preset() : getLastWeapon(unitId)

  let presets = getUnitPresets(unitBlk)
  weaponPreset = getWeaponsByPresetName(
    unitBlk, (curWeaponPresetId == "" ? presets?[0].name : curWeaponPresetId))

  local hasControllableRadar = false
  if (unitBlk?.sensors)
    foreach (sensor in (unitBlk.sensors % "sensor"))
      hasControllableRadar = hasControllableRadar || blkOptFromPath(sensor?.blk)?.type == "radar"

  let isMouseAimMode = helpersMode == globalEnv.EM_MOUSE_AIM

  if (unitType == unitTypes.AIRCRAFT)
  {
    let fmBlk = ::get_fm_file(unitId, unitBlk)
    let unitControls = fmBlk?.AvailableControls || ::DataBlock()

    let gotInstructor = isMouseAimMode || helpersMode == globalEnv.EM_INSTRUCTOR
    let option = ::get_option_in_mode(::USEROPT_INSTRUCTOR_GEAR_CONTROL, ::OPTIONS_MODE_GAMEPLAY)
    let instructorGearControl = gotInstructor && option.value

    controls = [ "throttle" ]

    if (::get_mission_difficulty_int() == ::g_difficulty.SIMULATOR.diffCode && !::CONTROLS_ALLOW_ENGINE_AUTOSTART) // warning disable: -const-in-bool-expr
      controls.append("ID_TOGGLE_ENGINE")

    if (isMouseAimMode)
      controls.append("mouse_aim_x", "mouse_aim_y")
    else
    {
      if (unitControls?.hasAileronControl)
        controls.append("ailerons")
      if (unitControls?.hasElevatorControl)
        controls.append("elevator")
      if (unitControls?.hasRudderControl)
        controls.append("rudder")
    }

    if (unitControls?.hasGearControl && !instructorGearControl)
      controls.append("ID_GEAR")
    if (unitControls?.hasAirbrake)
      controls.append("ID_AIR_BRAKE")
    if (unitControls?.hasFlapsControl)
    {
      let shortcuts = ::get_shortcuts([ "ID_FLAPS", "ID_FLAPS_UP", "ID_FLAPS_DOWN" ])
      let flaps   = ::g_controls_utils.isShortcutMapped(shortcuts[0])
      let flapsUp = ::g_controls_utils.isShortcutMapped(shortcuts[1])
      let flapsDn = ::g_controls_utils.isShortcutMapped(shortcuts[2])

      if (!flaps && !flapsUp && !flapsDn)
        controls.append("ID_FLAPS")
      else if (!flaps && !flapsUp && flapsDn)
        controls.append("ID_FLAPS_UP")
      else if (!flaps && flapsUp && !flapsDn)
        controls.append("ID_FLAPS_DOWN")
    }

    if (vehicleModel.hasEngineVtolControl())
      controls.append("vtol")

    if (unitBlk?.parachutes)
      controls.append("ID_CHUTE")

    let w = getWeaponFeatures([ commonWeapons, weaponPreset ])

    if (preset.getAxis("fire").axisId == -1)
    {
      if (w.gotMachineGuns || (!w.gotCannons && (w.gotGunnerTurrets || w.gotSchraegeMusik))) // Gunners require either Mguns or Cannons shortcut.
        controls.append("ID_FIRE_MGUNS")
      if (w.gotCannons)
        controls.append("ID_FIRE_CANNONS")
      if (w.gotAdditionalGuns)
        controls.append("ID_FIRE_ADDITIONAL_GUNS")
    }
    if (w.gotBombs || w.gotTorpedoes)
      controls.append("ID_BOMBS")
    if (w.gotRockets)
      controls.append("ID_ROCKETS")
    if (w.gotAGM)
      controls.append("ID_AGM")
    if (w.gotAAM)
      controls.append("ID_AAM")
    if (w.gotGuidedBombs)
      controls.append("ID_GUIDED_BOMBS")
    if (w.gotSchraegeMusik)
      controls.append("ID_SCHRAEGE_MUSIK")

    if (hasControllableRadar && !::is_xinput_device())
    {
      controls.append("ID_SENSOR_SWITCH")
      controls.append("ID_SENSOR_TARGET_SWITCH")
      controls.append("ID_SENSOR_TARGET_LOCK")
    }
  }
  else if (unitType == unitTypes.HELICOPTER)
  {
    controls = [ "helicopter_collective", "helicopter_climb", "helicopter_cyclic_roll", "helicopter_sensor_cue_x", "helicopter_sensor_cue_y" ]

    if (::is_xinput_device())
      controls.append("helicopter_mouse_aim_x", "helicopter_mouse_aim_y")

    let w = getWeaponFeatures([ commonWeapons, weaponPreset ])

    if (preset.getAxis("fire").axisId == -1)
    {
      if (w.gotMachineGuns || (!w.gotCannons && w.gotGunnerTurrets)) // Gunners require either Mguns or Cannons shortcut.
        controls.append("ID_FIRE_MGUNS_HELICOPTER")
      if (w.gotCannons)
        controls.append("ID_FIRE_CANNONS_HELICOPTER")
      if (w.gotAdditionalGuns)
        controls.append("ID_FIRE_ADDITIONAL_GUNS_HELICOPTER")
    }
    if (w.gotBombs || w.gotTorpedoes)
      controls.append("ID_BOMBS_HELICOPTER")
    if (w.gotRockets)
      controls.append("ID_ROCKETS_HELICOPTER")
    if (w.gotAGM)
      controls.append("ID_ATGM_HELICOPTER")
    if (w.gotAAM)
      controls.append("ID_AAM_HELICOPTER")
    if (w.gotGuidedBombs)
      controls.append("ID_GUIDED_BOMBS_HELICOPTER")
  }
  //






  else if (unitType == unitTypes.TANK)
  {
    controls = [ "gm_throttle", "gm_steering", "gm_mouse_aim_x", "gm_mouse_aim_y", "ID_TOGGLE_VIEW_GM", "ID_FIRE_GM", "ID_REPAIR_TANK" ]

    if (::is_platform_pc && !::is_xinput_device())
    {
      if (::shop_is_modification_enabled(unitId, "manual_extinguisher"))
        controls.append("ID_ACTION_BAR_ITEM_6")
      if (::shop_is_modification_enabled(unitId, "art_support"))
      {
        controls.append("ID_ACTION_BAR_ITEM_5")
        controls.append("ID_SHOOT_ARTILLERY")
      }
    }

    if (hasControllableRadar && !::is_xinput_device())
    {
      controls.append("ID_SENSOR_TARGET_SWITCH_TANK")
      controls.append("ID_SENSOR_TARGET_LOCK_TANK")
    }

    let gameParams = ::dgs_get_game_params()
    let missionDifficulty = ::get_mission_difficulty()
    let difficultyName = ::g_difficulty.getDifficultyByName(missionDifficulty).settingsName
    let difficultySettings = gameParams?.difficulty_settings?.baseDifficulty?[difficultyName]

    let tags = unit?.tags || []
    let scoutPresetId = difficultySettings?.scoutPreset ?? ""
    if (::has_feature("ActiveScouting") && tags.indexof("scout") != null
      && gameParams?.scoutPresets?[scoutPresetId]?.enabled)
      controls.append("ID_SCOUT")

    actionBarShortcutFormat = "ID_ACTION_BAR_ITEM_%d"
  }
  else if (unitType == unitTypes.SHIP || unitType == unitTypes.BOAT)
  {
    controls = ["ship_steering", "ID_TOGGLE_VIEW_SHIP"]

    let isSeperatedEngineControl =
      ::get_gui_option_in_mode(::USEROPT_SEPERATED_ENGINE_CONTROL_SHIP, ::OPTIONS_MODE_GAMEPLAY)
    if (isSeperatedEngineControl)
      controls.append("ship_port_engine", "ship_star_engine")
    else
      controls.append("ship_main_engine")

    let weaponGroups = [
      {
        triggerGroup = "primary"
        shortcuts = ["ID_SHIP_WEAPON_ALL", "ID_SHIP_WEAPON_PRIMARY"]
      }
      {
        triggerGroup = "secondary"
        shortcuts = ["ID_SHIP_WEAPON_ALL", "ID_SHIP_WEAPON_SECONDARY"]
      }
      {
        triggerGroup = "machinegun"
        shortcuts = ["ID_SHIP_WEAPON_ALL", "ID_SHIP_WEAPON_MACHINEGUN"]
      }
      {
        triggerGroup = "torpedoes"
        shortcuts = ["ID_SHIP_WEAPON_TORPEDOES"]
      }
      {
        triggerGroup = "depth_charge"
        shortcuts = ["ID_SHIP_WEAPON_DEPTH_CHARGE"]
      }
      {
        triggerGroup = "mortar"
        shortcuts = ["ID_SHIP_WEAPON_MORTAR"]
      }
      {
        triggerGroup = "rockets"
        shortcuts = ["ID_SHIP_WEAPON_ROCKETS"]
      }
    ]

    foreach (weaponSet in [ commonWeapons, weaponPreset ]) {
      foreach (weapon in weaponSet) {
        if (!weapon?.blk || weapon?.dummy)
          continue

        foreach (group in weaponGroups) {
          if (group?.isRequired || group.triggerGroup != weapon?.triggerGroup)
            continue

          group.isRequired <- true
          break
        }
      }
    }

    foreach (group in weaponGroups)
      if (group?.isRequired)
      {
        local isMapped = false
        foreach (shortcut in group.shortcuts)
          if (preset.getHotkey(shortcut).len() > 0)
          {
            isMapped = true
            break
          }
        if (!isMapped)
          foreach (shortcut in group.shortcuts)
            if (controls.indexof(shortcut) == null)
              controls.append(shortcut)
      }

    actionBarShortcutFormat = "ID_SHIP_ACTION_BAR_ITEM_%d"
  }

  if (actionBarShortcutFormat)
  {
    if (::is_platform_pc && !::is_xinput_device())
    {
      local bulletsChoice = 0
      for (local groupIndex = 0; groupIndex < unitType.bulletSetsQuantity; groupIndex++)
      {
        if (isBulletGroupActive(unit, groupIndex))
        {
          let bullets = ::get_unit_option(unitId, ::USEROPT_BULLET_COUNT0 + groupIndex)
          if (bullets != null && bullets > 0)
            bulletsChoice++
        }
      }
      if (bulletsChoice > 1)
        for (local i = 0; i < bulletsChoice; i++)
          controls.append(::format(actionBarShortcutFormat, i + 1))
    }
  }

  if (unitType.wheelmenuAxis.len())
  {
    controls.append("ID_SHOW_MULTIFUNC_WHEEL_MENU")
    if (::is_xinput_device())
      controls.extend(unitType.wheelmenuAxis)
  }

  return controls
}

::getUnmappedControls <- function getUnmappedControls(controls, helpersMode, getLocNames = true, shouldCheckRequirements = false)
{
  let unmapped = []

  let joyParams = ::JoystickParams()
  joyParams.setFrom(::joystick_get_cur_settings())

  foreach (item in ::shortcutsList)
  {
    if (::isInArray(item.id, controls))
    {
      if ((("filterHide" in item) && ::isInArray(helpersMode, item.filterHide))
        || (("filterShow" in item) && !::isInArray(helpersMode, item.filterShow))
        || (shouldCheckRequirements && helpersMode == globalEnv.EM_MOUSE_AIM && !item.reqInMouseAim))
        continue

      if (item.type == CONTROL_TYPE.SHORTCUT)
      {
        let shortcuts = ::get_shortcuts([ item.id ])
        if (!shortcuts.len() || ::g_controls_utils.isShortcutMapped(shortcuts[0]))
          continue

        let altIds = item?.alternativeIds ?? []
        foreach (otherItem in ::shortcutsList)
          if ((otherItem?.alternativeIds ?? []).indexof(item.id) != null)
            ::u.appendOnce(otherItem.id, altIds)
        local isMapped = false
        foreach (s in ::get_shortcuts(altIds))
          if (::g_controls_utils.isShortcutMapped(s))
          {
            isMapped = true
            break
          }
        if (isMapped)
          continue

        unmapped.append((getLocNames ? "hotkeys/" : "") + item.id)
      }
      else if (item.type == CONTROL_TYPE.AXIS)
      {
        if (::is_axis_mapped_on_mouse(item.id, helpersMode, joyParams))
          continue

        let axisIndex = ::get_axis_index(item.id)
        let axisId = axisIndex >= 0
          ? joyParams.getAxis(axisIndex).axisId : -1
        if (axisId == -1)
        {
          let modifiers = ["rangeMin", "rangeMax"]
          local shortcutsCount = 0
          foreach (modifier in modifiers)
          {
            if (!("hideAxisOptions" in item) || !::isInArray(modifier, item.hideAxisOptions))
            {
              let shortcuts = ::get_shortcuts([ item.id + "_" + modifier ])
              if (shortcuts.len() && ::g_controls_utils.isShortcutMapped(shortcuts[0]))
                shortcutsCount++
            }
          }
          if (shortcutsCount < modifiers.len())
            unmapped.append((getLocNames ? "controls/" : "") + item.axisName)
        }
      }
    }
  }

  return unmapped
}


::is_shortcut_display_equal <- function is_shortcut_display_equal(sc1, sc2)
{
  foreach(i, sb in sc1)
    if (::is_bind_in_shortcut(sb, sc2))
      return true
  return false
}

::is_bind_in_shortcut <- function is_bind_in_shortcut(bind, shortcut)
{
  foreach(sc in shortcut)
    if (sc.btn.len() == bind.btn.len())
    {
      local same = true
      foreach(ib, btn in bind.btn)
      {
        let i = ::find_in_array(sc.btn, btn)
        if (i < 0 || sc.dev[i] != bind.dev[ib])
        {
          same = false
          break
        }
      }
      if (same)
        return true
    }
  return false
}

::is_device_connected <- function is_device_connected(devId = null)
{
  if (!devId)
    return false

  let blk = ::DataBlock()
  ::fill_joysticks_desc(blk)

  for (local i = 0; i < blk.blockCount(); i++)
  {
    let device = blk.getBlock(i)
    if (device?.disconnected)
      continue

    if (device?.devId && device.devId.tolower() == devId.tolower())
      return true
  }

  return false
}
