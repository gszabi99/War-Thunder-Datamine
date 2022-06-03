let { format } = require("string")
let globalEnv = require("globalEnv")
let { setDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")

::aircraft_controls_wizard_config <- [
  { id="helpers_mode"
    type= CONTROL_TYPE.LISTBOX
    optionType = ::USEROPT_HELPERS_MODE
    isFilterObj = true
    skipAllBefore = [null, "msg/use_mouse_for_control", "msg/use_mouse_for_control", "msg/use_mouse_for_control"]
  }
    { id="msg_defaults",
      text=::loc("msg/mouseAimDefaults"),
      type= CONTROL_TYPE.MSG_BOX,
      options = ["#options/resetToDefaults", "#options/no"],
      defValue = 1,
      skipAllBefore = [null, "ID_BASIC_CONTROL_HEADER"]
    }
    { id="msg_wasd_type",
      text=::loc("controls/askKeyboardWasdType"),
      type= CONTROL_TYPE.MSG_BOX
      options = ::recomended_control_presets.map(@(name) "#msgbox/btn_" + name)
      defValue = 1,
      onButton = function(value)
      {
        let cType = ::recomended_control_presets[value]
        let preset = ::get_controls_preset_by_selected_type(cType)
        applyPreset(preset.fileName)
      }
    }
  { id="msg/use_mouse_for_control", type= CONTROL_TYPE.MSG_BOX
    filterHide = [globalEnv.EM_MOUSE_AIM]
    needSkip = @() (isPlatformSony || isPlatformXboxOne)
    options = ["controls/useMouseControl", "controls/useMouseView", "controls/UseMouseNone"],
    skip = [null, null, ["msg/mouseWheelAction", "ID_CAMERA_NEUTRAL"]]
    onButton = function(value)
    {
      curJoyParams.setMouseAxis(0, ["ailerons", "camx", ""][value])
      curJoyParams.setMouseAxis(1, ["elevator", "camy", ""][value])
      curJoyParams.mouseJoystick = value == 0;
    }
  }


  { id ="ID_BASIC_CONTROL_HEADER", type= CONTROL_TYPE.HEADER }
    { id="elevator", type = CONTROL_TYPE.AXIS, isVertical = true, showInverted = function() { return true }, msgType = "_elevator"
      images = ["wizard_elevator_up", "wizard_elevator_down"]}
    { id="ailerons", type = CONTROL_TYPE.AXIS, msgType = "_horizontal"
      images = ["wizard_ailerons_right", "wizard_ailerons_left"]}
    { id="rudder", type = CONTROL_TYPE.AXIS, msgType = "_horizontal"
      images = ["wizard_rudder_right", "wizard_rudder_left"]}
    { id="throttle", type = CONTROL_TYPE.AXIS, isVertical = true,
      images = ["wizard_throttle_up", "wizard_throttle_down"]
      isSlider = true
      onAxisDone = function(isAxis, isSkipped)
        {
          if (isSkipped)
          {
            skipList.append("msg/holdThrottleForWEP")
            return
          }
          if (isAxis)
          {
            curJoyParams.holdThrottleForWEP = false
            skipList.append("msg/holdThrottleForWEP")
          }
          let axis = curJoyParams.getAxis(::get_axis_index("throttle"))
          axis.relative = !isAxis
          let device = ::joystick_get_default()
          curJoyParams.applyParams(device)
        }
      skip = ["msg/holdThrottleForWEP"] //dont work in axis, but need to correct prevItem work, when skipList used in onAxisDone
    }
    { id="msg/holdThrottleForWEP", type= CONTROL_TYPE.MSG_BOX
      options = ["#options/yes", "#options/no", "options/skip"],
      onButton = function(value) { if (value<2) curJoyParams.holdThrottleForWEP = value==0 }
    }
    "ID_IGNITE_BOOSTERS"
    "ID_FIRE_MGUNS"
    "ID_FIRE_CANNONS"
    "ID_BAY_DOOR"
    "ID_BOMBS"
    "ID_ROCKETS"
    "ID_WEAPON_LOCK"
    "ID_AGM_LOCK"
    "ID_GUIDED_BOMBS_LOCK"
    "ID_FLARES"
    "ID_FUEL_TANKS"
    "ID_AIR_DROP"
    "ID_SENSOR_SWITCH"
    "ID_SENSOR_TYPE_SWITCH"
    "ID_SENSOR_MODE_SWITCH"
    "ID_SENSOR_ACM_SWITCH"
    "ID_SENSOR_SCAN_PATTERN_SWITCH"
    "ID_SENSOR_RANGE_SWITCH"
    "ID_SENSOR_TARGET_SWITCH"
    "ID_SENSOR_TARGET_LOCK"
    { id="weapon_aim_heading", type = CONTROL_TYPE.AXIS, msgType = "_horizontal", buttonRelative = true }
    { id="weapon_aim_pitch",   type = CONTROL_TYPE.AXIS, isVertical = true,       buttonRelative = true }
    "ID_RELOAD_GUNS"
    "ID_GEAR"
    { id="ID_AIR_BRAKE", filterShow = [globalEnv.EM_REALISTIC, globalEnv.EM_FULL_REAL] }
    "ID_FLAPS"
    "ID_LOCK_TARGET"
    "ID_TOGGLE_LASER_DESIGNATOR"
    "ID_NEXT_TARGET"
    "ID_PREV_TARGET"
    "ID_TACTICAL_MAP"
    "ID_MPSTATSCREEN"
    "ID_TOGGLE_CHAT_TEAM"
    "ID_TOGGLE_CHAT"


  { id="ID_VIEW_CONTROL_HEADER", type= CONTROL_TYPE.HEADER }
    { id="msg/viewControl", type= CONTROL_TYPE.MSG_BOX
      options = ["#options/yes", "#options/no"], //defValue = 0
      skipAllBefore = [null, "ID_FULL_AERODYNAMICS_HEADER"]
    }

    { id="viewtype", type= CONTROL_TYPE.MSG_BOX
      optionType = ::USEROPT_VIEWTYPE
    }
    "ID_CAMERA_DEFAULT"
    { id="camx", type = CONTROL_TYPE.AXIS, msgType = "_horizontal", relSens = 0.75
      images = ["wizard_camx_right", "wizard_camx_left"]
      axesList = ["camx", "turret_x"]
      filterHide = [globalEnv.EM_MOUSE_AIM] }
    { id="camy", type = CONTROL_TYPE.AXIS, isVertical = true, relSens = 0.75
      images = ["wizard_camy_up", "wizard_camy_down"]
      axesList = ["camy", "turret_y"]
      filterHide = [globalEnv.EM_MOUSE_AIM] }
    { id="msg/relative_camera_axis", type= CONTROL_TYPE.MSG_BOX
      options = ["#options/yes", "#options/no"],
      skip = ["neutral_cam_pos", null]
      onButton = function(value)
      {
        foreach(a in ["camx", "camy", "turret_x", "turret_y"])
        {
          let axis = curJoyParams.getAxis(::get_axis_index(a))
          axis.relative = value !=0
          axis.innerDeadzone = (value!=0)? 0.25 : 0.05
        }
        let device = ::joystick_get_default()
        curJoyParams.applyParams(device)
      }
    }
      { id="neutral_cam_pos", type= CONTROL_TYPE.SHORTCUT_GROUP
        shortcuts=["camx_rangeSet", "camy_rangeSet", "turret_x_rangeSet", "turret_y_rangeSet"]
      }
    "ID_TOGGLE_VIEW"
    "ID_TARGET_CAMERA"

      //hidden when no use mouse
      { id="msg/mouseWheelAction", type= CONTROL_TYPE.MSG_BOX
        options = ["controls/none", "controls/zoom", "controls/throttle"], defValue = 1
        onButton = function(value)
        {
          curJoyParams.setMouseAxis(2, ["", "zoom", "throttle"][value])
        }
      }
      "ID_CAMERA_NEUTRAL" //mouse look

    "ID_ZOOM_TOGGLE"
    { id="zoom", type = CONTROL_TYPE.AXIS, filterHide = [globalEnv.EM_MOUSE_AIM]
      isSlider = true }
    { id="msg/trackIR", type= CONTROL_TYPE.MSG_BOX
      filterHide = [globalEnv.EM_MOUSE_AIM]
      options = ["#options/yes", "#options/no", "options/skip"], defValue = 1
      skip = [null, "trackIrZoom", "trackIrZoom"]
    }
      { id = "trackIrZoom", type= CONTROL_TYPE.MSG_BOX
        filterHide = [globalEnv.EM_MOUSE_AIM]
        options = ["#options/yes", "#options/no"]
        onButton = function(value) { if (value<2) curJoyParams.trackIrZoom = value==0 }
      }


  { id ="ID_FULL_AERODYNAMICS_HEADER", type= CONTROL_TYPE.HEADER
    filterShow = [globalEnv.EM_FULL_REAL]
  }
    { id="ID_TRIM", filterShow = [globalEnv.EM_FULL_REAL] }
    { id="ID_TRIM_RESET", filterShow = [globalEnv.EM_FULL_REAL] }
    { id="ID_TRIM_SAVE", filterShow = [globalEnv.EM_FULL_REAL] }
    { id="helicopter_trim_elevator", type = CONTROL_TYPE.AXIS, isVertical = true, buttonRelative = true
      images = ["wizard_elevator_up", "wizard_elevator_down"]
      filterShow = [globalEnv.EM_FULL_REAL] }
    { id="helicopter_trim_ailerons", type = CONTROL_TYPE.AXIS, msgType = "_horizontal", buttonRelative = true
      images = ["wizard_ailerons_right", "wizard_ailerons_left"]
      filterShow = [globalEnv.EM_FULL_REAL] }
    { id="helicopter_trim_rudder", type = CONTROL_TYPE.AXIS, msgType = "_horizontal", buttonRelative = true
      images = ["wizard_rudder_right", "wizard_rudder_left"]
      filterShow = [globalEnv.EM_FULL_REAL] }
    { id="trim_elevator", type = CONTROL_TYPE.AXIS, isVertical = true, buttonRelative = true
      images = ["wizard_elevator_up", "wizard_elevator_down"]
      filterShow = [globalEnv.EM_FULL_REAL] }
    { id="trim_ailerons", type = CONTROL_TYPE.AXIS, msgType = "_horizontal", buttonRelative = true
      images = ["wizard_ailerons_right", "wizard_ailerons_left"]
      filterShow = [globalEnv.EM_FULL_REAL] }
    { id="trim_rudder", type = CONTROL_TYPE.AXIS, msgType = "_horizontal", buttonRelative = true
      images = ["wizard_rudder_right", "wizard_rudder_left"]
      filterShow = [globalEnv.EM_FULL_REAL] }
    { id="ID_FLAPS_DOWN", filterShow = [globalEnv.EM_FULL_REAL] }
    { id="ID_FLAPS_UP", filterShow = [globalEnv.EM_FULL_REAL] }
    { id="brake_right",  type = CONTROL_TYPE.AXIS, filterHide = [globalEnv.EM_MOUSE_AIM]
      images = ["wizard_brake_right_stop", "wizard_brake_right_go"]
      isSlider = true }
    { id="brake_left",   type = CONTROL_TYPE.AXIS, filterHide = [globalEnv.EM_MOUSE_AIM]
      images = ["wizard_brake_left_stop", "wizard_brake_left_go"]
      isSlider = true }


  { id ="ID_ENGINE_CONTROL_HEADER", type= CONTROL_TYPE.HEADER
    filterShow = [globalEnv.EM_FULL_REAL]
  }
    { id="ID_COMPLEX_ENGINE", filterShow = [globalEnv.EM_FULL_REAL] }
    { id="ID_TOGGLE_ENGINE", filterShow = [globalEnv.EM_FULL_REAL] }
    { id="prop_pitch", type = CONTROL_TYPE.AXIS, isSlider = true, buttonRelative = true
      filterShow = [globalEnv.EM_FULL_REAL] }
    { id="ID_PROP_PITCH_AUTO", filterShow = [globalEnv.EM_FULL_REAL] }
    { id="mixture", type = CONTROL_TYPE.AXIS, isSlider = true, buttonRelative = true
      filterShow = [globalEnv.EM_FULL_REAL] }
    { id="radiator", type = CONTROL_TYPE.AXIS, isSlider = true, buttonRelative = true
      filterShow = [globalEnv.EM_FULL_REAL] }
    { id="oil_radiator", type = CONTROL_TYPE.AXIS, isSlider = true, buttonRelative = true,
      filterShow = [globalEnv.EM_FULL_REAL]  }
    { id="ID_RADIATOR_AUTO", filterShow = [globalEnv.EM_FULL_REAL] }
    { id="turbo_charger", type = CONTROL_TYPE.AXIS, isSlider = true, buttonRelative = true
      filterShow = [globalEnv.EM_FULL_REAL] }
    { id="ID_TOGGLE_AUTO_TURBO_CHARGER", filterShow = [globalEnv.EM_FULL_REAL] }
    { id="ID_SUPERCHARGER", filterShow = [globalEnv.EM_FULL_REAL] }


  { id="msg/wizard_done_msg", type= CONTROL_TYPE.MSG_BOX }
]

::tank_controls_wizard_config <- [
  { id="helpers_mode"
    type= CONTROL_TYPE.LISTBOX
    optionType = ::USEROPT_HELPERS_MODE_GM
    isFilterObj = true
  }
  { id ="ID_ENGINE_CONTROL_HEADER", type= CONTROL_TYPE.HEADER }
    { id="gm_throttle", type = CONTROL_TYPE.AXIS, isVertical = true }
    { id="gm_steering", type = CONTROL_TYPE.AXIS, msgType = "_horizontal", showInverted = function() { return true } }
    { id="gm_clutch", type = CONTROL_TYPE.AXIS, isVertical = true, filterHide = [globalEnv.EM_MOUSE_AIM]}

  { id = "ID_BASIC_CONTROL_HEADER", type= CONTROL_TYPE.HEADER }
    "ID_FIRE_GM"
    "ID_FIRE_GM_SECONDARY_GUN"
    "ID_FIRE_GM_MACHINE_GUN"
    "ID_REPAIR_TANK"
    "ID_ACTION_BAR_ITEM_1"
    "ID_ACTION_BAR_ITEM_2"
    "ID_ACTION_BAR_ITEM_3"
    "ID_ACTION_BAR_ITEM_4"
    "ID_ACTION_BAR_ITEM_5"
    "ID_ACTION_BAR_ITEM_6"
    "ID_SHOOT_ARTILLERY"
    "ID_SENSOR_SWITCH_TANK"
    "ID_SENSOR_TYPE_SWITCH_TANK"
    "ID_SENSOR_MODE_SWITCH_TANK"
    "ID_SENSOR_ACM_SWITCH_TANK"
    "ID_SENSOR_SCAN_PATTERN_SWITCH_TANK"
    "ID_SENSOR_RANGE_SWITCH_TANK"
    "ID_SENSOR_TARGET_LOCK_SWITCH"
    "ID_SENSOR_TARGET_LOCK_TANK"

  { id="ID_VIEW_CONTROL_HEADER", type= CONTROL_TYPE.HEADER }
    { id="gm_mouse_aim_x", type = CONTROL_TYPE.AXIS, filterHide = [globalEnv.EM_MOUSE_AIM], msgType = "_horizontal" }
    { id="gm_mouse_aim_y", type = CONTROL_TYPE.AXIS, filterHide = [globalEnv.EM_MOUSE_AIM], isVertical = true }
    "ID_TOGGLE_VIEW_GM"
    "ID_ZOOM_TOGGLE"

  { id = "ID_MISC_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
    "ID_TACTICAL_MAP"  //common for everyone
    "ID_MPSTATSCREEN"  //common for everyone
    "ID_TOGGLE_CHAT_TEAM" //common for everyone
    "ID_TOGGLE_CHAT" //common for everyone

  { id="msg/wizard_done_msg", type= CONTROL_TYPE.MSG_BOX }
]

::initControlsWizardConfig <- function initControlsWizardConfig(arr)
{
  for(local i=0; i < arr.len(); i++)
  {
    if (typeof(arr[i]) == "string")
      arr[i] = { id=arr[i] }
    if (!("type" in arr[i]))
      arr[i].type <- CONTROL_TYPE.SHORTCUT
    if (arr[i].type == CONTROL_TYPE.AXIS)
    {
      if (!("axesList" in arr[i]) || arr[i].axesList.len()<1)
        arr[i].axesList <- [arr[i].id]
      arr[i].axisIndex <- []
      foreach(a in arr[i].axesList)
        arr[i].axisIndex.append(::get_axis_index(a))
      arr[i].modifiersId <- {}
    }
    arr[i].shortcutId <- -1
  }
}

::gui_modal_controlsWizard <- function gui_modal_controlsWizard()
{
  if (!::has_feature("ControlsPresets"))
    return
  ::gui_start_modal_wnd(::gui_handlers.controlsWizardModalHandler)
}

::gui_handlers.controlsWizardModalHandler <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/controlsWizard.blk"
  sceneNavBlkName = null

  unitType = ::ES_UNIT_TYPE_AIRCRAFT
  controls_wizard_config = null

  filter = null
  skipAllBefore = null
  skipList = null

  curDivName = ""
  msgTimer = 0.0
  waitAxisAddTime = 3.0

  presetSelected = ""
  curJoyParams = null
  presetupAxisRawValues = null
  shortcutNames = null
  shortcutItems = null
  shortcuts = null
  deviceMapping = null

  curIdx = -1
  curItem = null
  isPresetAlreadyApplied = false
  maxCheckSc = -1  //max shortcutIdx to checkassign dupes
  isListenButton = false
  isListenAxis = false
  isButtonsListenInCurBox = false
  isAxisListenInCurBox = false

  prevItems = null

  axisApplyParams = null

  repeatItemsList = null
  isRepeat = false

  axisMaxChoosen = false
  axisTypeButtons = false

  bindAxisNum = -1
  lastBindAxisNum = -1
  selectedAxisNum = -1
  bindAxisFixVal = 0.0
  bindAxisCurVal = 0.0
  isAxisVertical = false
  axisFixTime = 0.8
  axisCurTime = 0.0
  axisFixed = false
  axisFixDeviation = 1000

  lastTryAxisNum = -1
  lastTryTime = 0.0

  lastNumButtons = 0
  curBtnText = ""

  optionsToSave = null

  msgButtons = null
  waitMsgButton = false

  function initScreen()
  {
    scene.findObject("input-listener").setUserData(this)
    scene.findObject("update-timer").setUserData(this)

    skipList = []
    optionsToSave = []
    repeatItemsList = []
    prevItems = []
    shortcutNames = []
    shortcutItems = []

    curJoyParams = ::JoystickParams()
    curJoyParams.setFrom(::joystick_get_cur_settings())
    deviceMapping = ::u.copy(::g_controls_manager.getCurPreset().deviceMapping)

    initAxisPresetup()
    askPresetsWnd()
  }

  function initShortcutsNames()
  {
    shortcutNames = []
    shortcutItems = []

    for(local i=0; i < controls_wizard_config.len(); i++)
    {
      let item = controls_wizard_config[i]

      if (item.type == CONTROL_TYPE.SHORTCUT)
      {
        item.shortcutId = shortcutNames.len()
        shortcutNames.append(item.id)
        shortcutItems.append(item)
      }
      else if (item.type== CONTROL_TYPE.SHORTCUT_GROUP)
      {
        item.shortcutId = []
        foreach(idx, name in item.shortcuts)
        {
          item.shortcutId.append(shortcutNames.len())
          shortcutNames.append(name)
          shortcutItems.append(item)
        }
      }
      else if (item.type == CONTROL_TYPE.AXIS)
      {
        item.modifiersId = {}
        foreach(name in ["rangeMax", "rangeMin"]) //order is important
        {
          item.modifiersId[name] <- []
          foreach(a in item.axesList)
          {
            item.modifiersId[name].append(shortcutNames.len())
            shortcutNames.append(a + "_" + name)
            shortcutItems.append(item)
          }
        }
      }
    }
  }

  function getItemText(item)
  {
    if ("text" in item)
      return item.text
    if (item.type == CONTROL_TYPE.AXIS)
      return "controls/"+item.id
    else if ("optionType" in item)
      return "options/" + ::get_option(item.optionType).id

    return "hotkeys/" + item.id
  }

  function getItemName(item)
  {
    if ("name" in item)
      return item.name
    else if (item.type == CONTROL_TYPE.AXIS)
      return "controls/"+item.id
    return "hotkeys/" + item.id
  }

  function nextItem()
  {
    if (!::checkObj(scene))
      return

    isButtonsListenInCurBox = false
    isAxisListenInCurBox = false

    local isItemOk = true
    isRepeat = false
    if (repeatItemsList.len()>0)
    {
      curItem = repeatItemsList[0]
      repeatItemsList.remove(0)
      isItemOk = false
      isRepeat = true
    }
    else
    {
      curIdx++
      if (!(curIdx in controls_wizard_config))
      {
        doApply()
        return
      }

      curItem = controls_wizard_config[curIdx]

      switchListenAxis(false)
      switchListenButton(false)

      if (skipAllBefore!=null)
        if (skipAllBefore==curItem.id)
          skipAllBefore=null
        else
          return nextItem()
      if (isInArray(curItem.id, skipList))
        return nextItem()
      if (("isFilterObj" in curItem) && curItem.isFilterObj && !::can_change_helpers_mode())
      {
        if ("optionType" in curItem)
        {
          let config = ::get_option(curItem.optionType)
          filter = config.values[config.value]
        } else
          ::dagor.assertf(false, "Error: not found optionType in wizard filterObj.")
        return nextItem()
      }
      if (filter!=null &&
           ((("filterShow" in curItem) && !::isInArray(filter, curItem.filterShow))
             || (("filterHide" in curItem) && ::isInArray(filter, curItem.filterHide))))
        return nextItem()

      if ("needSkip" in curItem && curItem.needSkip && curItem.needSkip())
        return nextItem()
    }

    if (curItem.type== CONTROL_TYPE.HEADER)
    {
      scene.findObject("wizard-title").setValue(::loc(getItemText(curItem)))
      isItemOk = false
      nextItem()
    }
    else if (curItem.type == CONTROL_TYPE.SHORTCUT || curItem.type== CONTROL_TYPE.SHORTCUT_GROUP)
    {
      switchToDiv("shortcut-wnd")
      askShortcut()
    }
    else if (curItem.type == CONTROL_TYPE.AXIS)
    {
      axisMaxChoosen=false
      askAxis()
    }
    else if (curItem.type== CONTROL_TYPE.MSG_BOX)
    {
      switchToDiv("msgBox-wnd")
      showMsgBox()
    }
    else if (curItem.type== CONTROL_TYPE.LISTBOX)
    {
      switchToDiv("listbox-wnd")
      showMsgBox(true)
    }
    else
    {
      isItemOk = false
      nextItem()
    }

    if (isItemOk)
      prevItems.append(curIdx)

    updateButtons()
    this.showSceneBtn("btn_prevItem", prevItems.len() > 0)
    this.showSceneBtn("btn_controlsWizard", prevItems.len()==0)
  }

  function onPrevItem()
  {
    isButtonsListenInCurBox = false
    isAxisListenInCurBox = false

    if (curIdx == 0)
    {
      askPresetsWnd()
      return
    }

    if (prevItems.len()==0)
      return

    if (msgTimer>0) //after axis bind message
    {
      msgTimer=0
      isRepeat = true
    }

    repeatItemsList = []

    local lastIdx = prevItems[prevItems.len()-1]
    if (isRepeat)
    {
      curIdx = lastIdx-1
      prevItems.remove(prevItems.len()-1)
      nextItem()
    }
    else if (curItem.type == CONTROL_TYPE.AXIS && axisMaxChoosen)
    {
      axisMaxChoosen = false
      axisFixed = false
      selectedAxisNum = -1
      askAxis()
    }
    else
    {
      prevItems.remove(prevItems.len()-1)
      if (prevItems.len()==0)
        return

      lastIdx = prevItems[prevItems.len()-1]
      prevItems.remove(prevItems.len()-1)
      curIdx = lastIdx-1

      let lastItem = controls_wizard_config[lastIdx]
      if ("skip" in lastItem)
        for(local i=skipList.len()-1; i>=0; i--)
          if (::isInArrayRecursive(skipList[i], lastItem.skip))
            skipList.remove(i)

      nextItem()
    }

    updateButtons()
  }

  function switchToDiv(divName)
  {
    if (!::checkObj(scene))
      return

    foreach(name in ["msgBox-wnd", "shortcut-wnd", "listbox-wnd", "options-wnd", "msg-wnd"])
    {
      let divObj = scene.findObject(name)
      if (!::checkObj(divObj))
        continue

      divObj.show(divName == name)
    }

    if (divName != "msg-wnd")
      curDivName = divName

    enableListenerObj(curDivName == "shortcut-wnd")
  }

  function enableListenerObj(isEnable)
  {
    let obj = this.showSceneBtn("input-listener", isEnable)
    if (isEnable)
      obj.select()
  }

  function askShortcut()
  {
    if (!::checkObj(scene))
      return

    axisMaxChoosen = false
    scene.findObject("shortcut_text").setValue(::loc(getItemText(curItem)))
    let textObj = scene.findObject("hold_axis")
    if (::checkObj(textObj))
    {
      textObj.setValue(::loc("hotkeys/msg/press_a_key"))
      textObj.show(true)
    }
    scene.findObject("shortcut_image")["background-image"] = ""
    this.showSceneBtn("btn-reset-axis-input", false)
    clearShortcutInfo()

    isButtonsListenInCurBox = true
    switchListenButton(true)
    setCurAssignedButtonsText()
  }

  function askAxis()
  {
    switchToDiv("shortcut-wnd")
    axisApplyParams = null
    scene.findObject("shortcut_text").setValue(::loc(getItemText(curItem)))

    isButtonsListenInCurBox = !axisMaxChoosen || axisTypeButtons
    scene.findObject("shortcut_current_button").setValue(isButtonsListenInCurBox? "?" : "")
    clearShortcutInfo()
    switchListenButton(isButtonsListenInCurBox)

    isAxisListenInCurBox = !axisMaxChoosen || !axisTypeButtons
    switchListenAxis(isAxisListenInCurBox, !axisMaxChoosen)
    if (!axisMaxChoosen)
    {
      bindAxisNum = -1
      selectedAxisNum = -1
    }
    updateAxisPressKey()
    updateAxisName()
    setCurAssignedButtonsText()
    updateButtons()
  }

  function setCurAssignedButtonsText()
  {
    local axisAssignText = ""
    local buttonAssignText = ""

    if (curItem.type == CONTROL_TYPE.AXIS)
    {
      let axis = curJoyParams.getAxis(curItem.axisIndex[0])
      let curPreset = ::g_controls_manager.getCurPreset()
      if (axis.axisId >= 0)
        axisAssignText = ::addHotkeyTxt(::remapAxisName(curPreset, axis.axisId))
      if (isButtonsListenInCurBox)
        buttonAssignText = ::get_shortcut_text({
          shortcuts = shortcuts,
          shortcutId = curItem.modifiersId[axisMaxChoosen? "rangeMin" : "rangeMax"][0],
          cantBeEmpty = false
        })
    }
    else if (curItem.type == CONTROL_TYPE.SHORTCUT)
      buttonAssignText = ::get_shortcut_text({
        shortcuts = shortcuts,
        shortcutId = curItem.shortcutId,
        cantBeEmpty = false
      })

    local assignText = axisAssignText + ((buttonAssignText == "" || axisAssignText == "")? "" : ::loc("ui/semicolon")) + buttonAssignText
    if (assignText == "")
      assignText = "---"

    scene.findObject("curAssign_text").setValue(::loc("controls/currentAssign") + ::loc("ui/colon") + assignText)
  }

  function updateAxisPressKey()
  {
    local imgId = 0
    local msgLocId = "hotkeys/msg/choose_maxValue"
    if (axisTypeButtons && axisMaxChoosen)
    {
      msgLocId = "hotkeys/msg/choose_minValue_button"
      imgId = 1
    }
    if (!axisTypeButtons)
      if (selectedAxisNum>=0)
      {
        msgLocId = "hotkeys/msg/choose_minValue_axis"
        imgId = 1
      }
    if ("msgType" in curItem)
      msgLocId += curItem.msgType

    let textObj = scene.findObject("hold_axis")
    if (::checkObj(textObj))
    {
      textObj.setValue(::loc(msgLocId))
      textObj.show(true)
    }

    local image = ""
    if (("images" in curItem) && (imgId in curItem.images))
      image = "#ui/images/wizard/" + curItem.images[imgId]
    scene.findObject("shortcut_image")["background-image"] = image
  }

  function setAxisType(isButtons)
  {
    axisTypeButtons = isButtons
    if (axisTypeButtons)
      switchListenAxis(false)
    else
    {
      clearShortcutInfo()
      switchListenButton(false)
    }

    this.showSceneBtn("btn-reset-axis-input", selectedAxisNum>=0 || axisMaxChoosen)
  }

  function switchListenButton(value)
  {
    isListenButton = value
    let obj = scene.findObject("shortcut_current_button")
    if (::checkObj(obj))
    {
      obj.show(value)
      obj.setValue("?")
    }

    guiScene.sleepKeyRepeat(value)
    ::set_bind_mode(value)
  }

  function switchListenAxis(value, reinitPresetup=false)
  {
    isListenAxis = value

    isAxisVertical = ("isVertical" in curItem)? curItem.isVertical : false
    scene.findObject("test-axis").show(value && !isAxisVertical)
    scene.findObject("test-axis-vert").show(value && isAxisVertical)
    scene.findObject("bind-axis-name").show(value)

    if (value)
    {
      axisFixed = false
      if (reinitPresetup)
        initAxisPresetup()
    }
    this.showSceneBtn("btn-reset-axis-input", axisMaxChoosen)
  }

  function updateSwitchModesButton()
  {
    let isShow = curDivName == "shortcut-wnd" && selectedAxisNum < 0 && !axisMaxChoosen
    this.showSceneBtn("btn_switchAllModes", isShow)

    if (!isShow)
      return

    let isEnabled = isListenAxis || isListenButton
    let sampleText = ::loc("mainmenu/shortcuts") + " (%s" + ::loc("options/" + (isEnabled? "enabled" : "disabled")) + "%s)"
    let coloredText = format(sampleText, "<color=@" + (isEnabled? "goodTextColor" : "warningTextColor") + ">", "</color>")
    let NotColoredText = format(sampleText, "", "")

    setDoubleTextToButton(scene, "btn_switchAllModes", NotColoredText, coloredText)
  }

  function switchAllListenModes(obj)
  {
    axisCurTime = 0.0
    let btnObj = scene.findObject("btn_switchAllModes")
    if (!btnObj.isEnabled())
      onResetAxisInput()
    else
    {
      clearShortcutInfo()
      switchButtonMode()
    }
    updateButtons()
  }

  function switchButtonMode()
  {
    if (curDivName != "shortcut-wnd")
      return
    let enable = !(isListenAxis || isListenButton)
    enableListenerObj(enable)
    scene.findObject("hold_axis").show(enable)
    if (isAxisListenInCurBox)
      switchListenAxis(enable, true)
    if (isButtonsListenInCurBox)
      switchListenButton(enable)
  }

  function updateButtons()
  {
    let isInListenWnd = curDivName == "shortcut-wnd"
    let isListening   = isInListenWnd && (isListenAxis || isListenButton)

    if (::show_console_buttons)
    {
      foreach(name in ["keep_assign_btn", "btn_prevItem", "btn_controlsWizard", "btn_selectPreset"])
      {
        let btnObj = scene.findObject(name)
        if (::checkObj(btnObj))
        {
          btnObj.hideConsoleImage = isListening ? "yes" : "no"
          btnObj.inactiveColor = isListening ? "yes" : "no"
        }
      }
    }

    updateSwitchModesButton()
    this.showSceneBtn("keep_assign_btn", isInListenWnd)
    this.showSceneBtn("btn-reset-axis-input", isInListenWnd && (axisMaxChoosen || selectedAxisNum >= 0))
    this.showSceneBtn("btn_back", !isListening)
  }

  function onButtonDone()
  {
    if (curItem.type == CONTROL_TYPE.AXIS)
      if (!axisMaxChoosen)
      {
        axisMaxChoosen=true
        setAxisType(true)
        askAxis()
        return
      } else
      {
        let axis = curJoyParams.getAxis(curItem.axisIndex[0])
        axis.relative = ("buttonRelative" in curItem)? curItem.buttonRelative : false
        axis.relSens = ("relSens" in curItem)? curItem.relSens : 1.0
        axis.relStep = ("relStep" in curItem)? curItem.relStep : 0
        let device = ::joystick_get_default()
        curJoyParams.applyParams(device)
      }

    if (curItem.type == CONTROL_TYPE.AXIS && ("onAxisDone" in curItem))
      curItem.onAxisDone.call(this, !axisTypeButtons, false)
    nextItem()
  }

  function onButtonEntered(obj)
  {
    if (isButtonsListenInCurBox && !isListenButton)
      return

    switchListenButton(false)
    let sc = readShortcutInfo(obj)
    if (sc.dev.len() > 0 && sc.dev.len() == sc.btn.len())
      if (bindShortcut(sc.dev, sc.btn))
        return

    onButtonDone()
  }

  function isKbdOrMouse(devs) // warning disable: -named-like-return-bool
  {
    local isKbd = null
    foreach(d in devs)
      if (d>0)
        if (isKbd==null)
          isKbd = d < ::JOYSTICK_DEVICE_0_ID
        else
          if (isKbd != (d < ::JOYSTICK_DEVICE_0_ID))
            return null
    return isKbd
  }

  function doBind(devs, btns, shortcutId)
  {
    if (typeof(shortcutId)=="array")
    {
      foreach(id in shortcutId)
        doBind(devs, btns, id)
    } else
    if (typeof(shortcutId)=="integer" && devs.len() > 0)
    {
      let isKbd = isKbdOrMouse(devs)
      if (isKbd==null)
        shortcuts[shortcutId] = [{dev = devs, btn = btns}]
      else
      {
        for(local i=shortcuts[shortcutId].len()-1; i>=0; i--)
          if (isKbd == isKbdOrMouse(shortcuts[shortcutId][i].dev))
            shortcuts[shortcutId].remove(i)   //remove shortcuts by same device type
        shortcuts[shortcutId].append({dev = devs, btn = btns})
        if (shortcuts[shortcutId].len() > max_shortcuts)
          shortcuts[shortcutId].remove(0)
      }
    }
  }

  function bindShortcut(devs, btns)
  {
    local shortcutId = curItem.shortcutId
    if (curItem.type == CONTROL_TYPE.AXIS)
      shortcutId = curItem.modifiersId[axisMaxChoosen? "rangeMin" : "rangeMax"]

    let curBinding = findButtons(devs, btns, shortcutId)
    if (!curBinding || curBinding.len() == 0)
    {
      doBind(devs, btns, shortcutId)
      return false
    }

    local actionText = ""
    foreach(binding in curBinding)
      actionText += ((actionText=="")? "":", ") + ::loc("hotkeys/"+shortcutNames[binding[0]])
    let msg = ::loc("hotkeys/msg/unbind_question", { action=actionText })
    this.msgBox("controls_wizard_bind_existing_shortcut", msg, [
      ["add", (@(curBinding, devs, btns, shortcutId) function() {
        doBind(devs, btns, shortcutId)
        onButtonDone()
      })(curBinding, devs, btns, shortcutId)],
      ["replace", (@(curBinding, devs, btns, shortcutId) function() {
        foreach(binding in curBinding)
        {
          shortcuts[binding[0]].remove(binding[1])
          let item = shortcutItems[binding[0]]
          if (!isInArray(item, repeatItemsList))
            repeatItemsList.append(item)
        }
        doBind(devs, btns, shortcutId)
        onButtonDone()
      })(curBinding, devs, btns, shortcutId)],
      ["cancel", function() { askShortcut() }],
      ["skip", function() { onButtonDone() }],
    ], "add")
    return true
  }

  function findButtons(devs, btns, shortcutId)
  {
    let firstSc = (typeof(shortcutId)=="integer")? shortcutId : shortcutId[0]
    let scItem = shortcutItems[firstSc]
    if (firstSc>maxCheckSc)
      maxCheckSc = firstSc
    let res = []
    let foundedItems = []

    for(local i = 0; i<maxCheckSc; i++)
    {
      if (firstSc==i || ((typeof(shortcutId)=="array") && isInArray(i, shortcutId)))
        continue
      let item = shortcutItems[i]
      if (item==scItem && (item.type!= CONTROL_TYPE.AXIS || i==scItem.modifiersId[axisMaxChoosen? "rangeMin" : "rangeMax"]))
        continue
      if (isInArray(item, repeatItemsList) || isInArray(item, foundedItems))
        continue

      let event = shortcuts[i]
      foreach (btnIdx, button in event)
      {
        if (!button || button.dev.len() != devs.len())
          continue
        local numEqual = 0
        for (local j = 0; j < button.dev.len(); j++)
          for (local k = 0; k < devs.len(); k++)
            if ((button.dev[j] == devs[k]) && (button.btn[j] == btns[k]))
              numEqual++

        if (numEqual == btns.len())
        {
          res.append([i, btnIdx])
          foundedItems.append(item)
        }
      }
    }
    return res
  }

  function onCancelButtonInput(obj)
  {
    if (isButtonsListenInCurBox || (curItem.type == CONTROL_TYPE.AXIS && !axisTypeButtons))
    {
      switchListenButton(false)
      switchListenAxis(false)
      selectedAxisNum = -1
      axisApplyParams = null
      if ("onAxisDone" in curItem)
        curItem.onAxisDone.call(this, !axisTypeButtons, true)
      nextItem()
    }
  }

  function onButtonAdded(obj)
  {
    if (!isButtonsListenInCurBox && !isListenButton)
      return

    let sc = readShortcutInfo(obj)
    curBtnText = getShortcutText(sc) + ((lastNumButtons>=3)? "" : (lastNumButtons>0)? " + ?" : "?")
    scene.findObject("shortcut_current_button").setValue(curBtnText)
  }

  function getShortcutText(sc)
  {
    local text = ""
    let curPreset = ::g_controls_manager.getCurPreset()
    for (local i = 0; i < sc.dev.len(); i++)
      text += ((i != 0)? " + ":"") + ::getLocalizedControlName(curPreset, sc.dev[i], sc.btn[i])
    return text
  }

  function readShortcutInfo(obj)
  {
    let res = { dev = [], btn = [] }
    lastNumButtons = 0

    for (local i = 0; i < 3; i++)
    {
      if (obj["device" + i]!="" && obj["button" + i]!="")
      {
        let devId = obj["device" + i].tointeger()
        let btnId = obj["button" + i].tointeger()
        res.dev.append(devId)
        res.btn.append(btnId)
        lastNumButtons++
      }
    }

    return res
  }

  function clearShortcutInfo()
  {
    let obj = scene.findObject("input-listener")
    for (local i = 0; i < 3; i++)
    {
      obj["device" + i] = ""
      obj["button" + i] = ""
    }
  }

  function onAxisSelected()
  {
    switchListenAxis(false)
    onAxisDone()
  }

  function onAxisDone()
  {
    switchListenAxis(false)
    foreach(name in ["keep_assign_btn", "btn_prevItem", "btn_controlsWizard", "btn_selectPreset", "btn-reset-axis-input"])
      this.showSceneBtn(name, false)

    let config = presetupAxisRawValues[selectedAxisNum]

    axisApplyParams = {}
    axisApplyParams.invert <- false
    if (fabs(config.min-bindAxisFixVal) < fabs(config.max-bindAxisFixVal))
      axisApplyParams.invert = true
    axisApplyParams.relSens <- ("relSens" in curItem)? curItem.relSens : 1.0
    axisApplyParams.relStep <- ("relStep" in curItem)? curItem.relStep : 0

    axisApplyParams.isSlider <- ("isSlider" in curItem)? curItem.isSlider : false
    axisApplyParams.kAdd <- 0
    axisApplyParams.kMul <- 1.0

    if (!axisApplyParams.isSlider)
    {
      let minDev = min(::abs(config.max), ::abs(config.min))
      if (minDev>=3200) //10%
        axisApplyParams.kMul = 0.1*::floor(320000.0/minDev)
      else
        axisApplyParams.isSlider = true  //count this axis as slider
    }
    if (axisApplyParams.isSlider)
    {
      axisApplyParams.kMul = 2.0*32000/(config.max-config.min) * 1.05 //accuracy 5%
      axisApplyParams.kMul = 0.1*::ceil(10.0*axisApplyParams.kMul)
      axisApplyParams.kAdd = -0.5*(config.min+config.max) / 32000 * axisApplyParams.kMul
    }

    let curPreset = ::g_controls_manager.getCurPreset()
    curBtnText = ::remapAxisName(curPreset, selectedAxisNum)
    showMsg(::loc("hotkeys/msg/axis_choosen") + "\n" + curBtnText, config)
  }

  function bindAxis()
  {
    if (!axisApplyParams) return

    foreach(idx, aName in curItem.axesList)
    {
      let axisIndex = curItem.axisIndex[idx]
      curJoyParams.bindAxis(axisIndex, selectedAxisNum)
      let axis = curJoyParams.getAxis(axisIndex)
      axis.inverse = axisApplyParams.invert
      axis.innerDeadzone = axisApplyParams.isSlider? 0 : 0.02
      axis.nonlinearity = axisApplyParams.isSlider? 0 : 1
      axis.relative = false
      axis.relSens = axisApplyParams.relSens
      axis.relStep = axisApplyParams.relStep
      axis.kAdd = axisApplyParams.kAdd
      axis.kMul = axisApplyParams.kMul
    }

    let device = ::joystick_get_default()
    curJoyParams.applyParams(device)

    //clear hotkey min|max when use axis
    foreach(arr in curItem.modifiersId)
      foreach(id in arr)
        shortcuts[id] = []

    if ("onAxisDone" in curItem)
      curItem.onAxisDone.call(this, !axisTypeButtons, false)

    axisApplyParams = null
    selectedAxisNum = -1
    nextItem()
  }

  function onAxisApply()
  {
    let curBinding = findAxis(selectedAxisNum)
    if (curBinding.len() == 0)
    {
      bindAxis()
      return false
    }

    local actionText = ""
    foreach(binding in curBinding)
      actionText += ((actionText=="")? "":", ") + ::loc(getItemName(binding))
    let msg = ::loc("hotkeys/msg/unbind_axis_question", {
      button=curBtnText, action=actionText
    })
    this.msgBox("controls_wizard_bind_existing_axis", msg, [
      ["add", function() { bindAxis() }],
      ["replace", (@(curBinding) function() {
        repeatItemsList.extend(curBinding)
        bindAxis()
      })(curBinding)],
      ["cancel", function() { askAxis() }],
      ["skip", function() { onCancelButtonInput(null) }],
    ], "add")
  }

  function findAxis(curAxisId)
  {
    let res = []
    for(local i = 0; i<=curIdx; i++)
    {
      let item = controls_wizard_config[i]
      if (item.type!= CONTROL_TYPE.AXIS || item==curItem)
        continue

      let axis = curJoyParams.getAxis(item.axisIndex[0])
      if (curAxisId == axis.axisId && !isInArray(item, repeatItemsList) && !isInArray(item, res))
        res.append(item)
    }
    return res
  }

  function updateAxisName()
  {
    let obj = scene.findObject("bind-axis-name")
    if (!::checkObj(obj))
      return

    obj.show(isAxisListenInCurBox)

    let device = ::joystick_get_default()
    let curPreset = ::g_controls_manager.getCurPreset()
    let axisName = device ? ::remapAxisName(curPreset, bindAxisNum) : ""
    obj.setValue(axisName)

    let changeColor = (selectedAxisNum>=0 && selectedAxisNum==bindAxisNum)? "fixedAxis" : ""
    obj.changeColor = changeColor
  }

  function getCurAxisNum(dt, checkLastTryAxis = true)
  {
    let device = ::joystick_get_default()
    local foundAxis = -1
    let curPreset = ::g_controls_manager.getCurPreset()
    let numAxes = curPreset.getNumAxes()
    if (numAxes > presetupAxisRawValues.len())
      initAxisPresetup(false) //add new founded axes

    local deviation = 12000 //foundedAxis deviation, cant be lower than a initial value
    for (local i = 0; i < numAxes; i++)
    {
      let rawPos = device.getAxisPosRaw(i)
      if (rawPos!=0 && !presetupAxisRawValues[i].inited)
      {
        //Some joysticks return zero at first and only then init the current value
        presetupAxisRawValues[i].inited = true
        presetupAxisRawValues[i].def=rawPos
        presetupAxisRawValues[i].min=rawPos
        presetupAxisRawValues[i].max=rawPos
      } else
      {
        if (rawPos>presetupAxisRawValues[i].max)
          presetupAxisRawValues[i].max = rawPos
        if (rawPos<presetupAxisRawValues[i].min)
          presetupAxisRawValues[i].min = rawPos
      }

      let dPos = fabs(rawPos - presetupAxisRawValues[i].def)
      if (dPos > deviation)
      {
        foundAxis = i
        deviation = dPos

        if (fabs(rawPos-presetupAxisRawValues[i].last) < 1000)  //check stucked axes
        {
          presetupAxisRawValues[i].stuckTime += dt
          if (presetupAxisRawValues[i].stuckTime > 3.0)
            presetupAxisRawValues[i].def = rawPos //change cur value to def becoase of stucked
        } else
        {
          presetupAxisRawValues[i].last = rawPos
          presetupAxisRawValues[i].stuckTime = 0.0
        }
      }
    }

    if (checkLastTryAxis)
      if (foundAxis>=0)
      {
        if (lastTryAxisNum != foundAxis)
        {
          lastTryAxisNum = foundAxis
          lastTryTime+=dt
        }
      } else
        if (lastTryAxisNum >=0)
          if (lastTryTime>1.0 ||
              (presetupAxisRawValues[lastTryAxisNum].max-presetupAxisRawValues[lastTryAxisNum].min) >= 16000)
            foundAxis = lastTryAxisNum

    return foundAxis
  }

  function onAxisInputTimer(obj, dt)
  {
    if (!isListenAxis || !is_app_active() || steam_is_overlay_active())
      return

    let device = ::joystick_get_default()
    if (device == null)
      return

    let foundAxis = getCurAxisNum(dt)
    if (selectedAxisNum<0)
    {
      if (foundAxis != bindAxisNum)
      {
        bindAxisNum = foundAxis
//        if (selectedAxisNum>=0 && bindAxisNum<0)
//          bindAxisNum = selectedAxisNum
//        else
          axisCurTime = 0.0
      }
    }

    if (lastBindAxisNum != bindAxisNum)
    {
      lastBindAxisNum = bindAxisNum
      updateAxisName()
      if (::is_axis_digital(bindAxisNum))
        setAxisType(false)
    }

    if (bindAxisNum < 0)
    {
      bindAxisCurVal=0
      moveTestItem(0)
      return
    }

    axisCurTime+=dt

    let val = device.getAxisPosRaw(bindAxisNum)
    local checkTime = true
    if (val != bindAxisCurVal)
    {
      bindAxisCurVal = val
      moveTestItem(bindAxisCurVal)
      axisCurTime = 0.0
      if (fabs(val-bindAxisCurVal)>1000)
        checkTime = false
    }

    if (checkTime)
      if ((axisCurTime>=axisFixTime && fabs(val)>3000) || axisCurTime>=2.0*axisFixTime)  //double wait time near zero
        if (selectedAxisNum!=bindAxisNum)
        {
          selectedAxisNum = bindAxisNum
          bindAxisFixVal = bindAxisCurVal
          setAxisType(false)
          scene.findObject("input-listener").select()

          updateAxisPressKey()
          updateAxisName()
          updateButtons()
        }
        else if (fabs(val-bindAxisFixVal)>12000)
          onAxisSelected()
  }

  function onResetAxisInput()
  {
    if (curItem.type != CONTROL_TYPE.AXIS)
      return
    selectedAxisNum=-1
    axisMaxChoosen = false
    this.showSceneBtn("btn-reset-axis-input", false)
    initAxisPresetup()
    askAxis()
  }

  function moveTestItem(value, obj=null)
  {
    if (!obj)
      obj = scene.findObject(isAxisVertical? "test-real-box-vert" : "test-real-box")
    if ("showInverted" in curItem && curItem.showInverted())
      value = -value

    if (isAxisVertical)
      obj.pos = "0.5pw-0.5w, " + format("%.3f(ph - h)", ((32000 - value).tofloat() / 64000))
    else
      obj.pos = format("%.3f(pw - w)", ((value + 32000).tofloat() / 64000)) + ", 0.5ph- 0.5h"
  }

  function initAxisPresetup(fullInit=true)
  {
    if (fullInit)
    {
      presetupAxisRawValues = []
      lastTryAxisNum = -1
    }
    let device = ::joystick_get_default()
    if (device == null)
      return

    let curPreset = ::g_controls_manager.getCurPreset()
    let start = presetupAxisRawValues.len()
    for (local i = start; i < curPreset.getNumAxes(); i++)
    {
      let rawPos = device.getAxisPosRaw(i)
      presetupAxisRawValues.append({
                                     def=rawPos,
                                     min=rawPos,
                                     max=rawPos,
                                     last=rawPos,
                                     stuckTime=0.0,
                                     inited = ::is_axis_digital(i) || rawPos!=0
                                  })
    }
  }

  function showMsgBox(isListbox=false)
  {
    let msgText = getItemText(curItem)
    local defValue = 0
    msgButtons = []

    if ("optionType" in curItem)
    {
      let config = ::get_option(curItem.optionType)
      msgButtons = config.items
      defValue = config.value
    } else if ("options" in curItem)
    {
      msgButtons = curItem.options
      defValue = ("defValue" in curItem)? curItem.defValue : 0
    }

    if (msgButtons.len()==0)
      msgButtons.append("msgbox/btn_ok")

    if (!isListbox)
    {
      scene.findObject("msgBox_text").setValue(::loc(msgText))
      local data = ""
      foreach(idx, btn in msgButtons)
      {
        let text = (btn.len()>0 && btn.slice(0, 1)!="#") ? "#"+btn : btn
        data += format("Button_text { id:t='%d'; text:t='%s'; on_click:t='onMsgButton'; }",
                  idx, text)
      }
      let btnsHolder = scene.findObject("msgBox_buttons")
      guiScene.replaceContentFromText(btnsHolder, data, data.len(), this)
      ::move_mouse_on_obj(btnsHolder.findObject(defValue.tostring()))
    }
    else
    {
      scene.findObject("listbox_text").setValue(::loc(msgText))

      let view = { items = [] }
      foreach(idx, btn in msgButtons)
      {
        local text = ::getTblValue("text", btn, "")
        if (::u.isString(btn))
          text = btn

        if (getStrSymbol(text, 0) != "#")
          text = "#" + text

        view.items.append({
          id = idx.tostring()
          text = text
          tooltip = text+"/tooltip"
        })
      }

      let data = ::handyman.renderCached("%gui/commonParts/shopFilter", view)
      let listObj = scene.findObject("listbox")
      guiScene.replaceContentFromText(listObj, data, data.len(), this)
      if (defValue in msgButtons)
        listObj.setValue(defValue)
      ::move_mouse_on_child(listObj, listObj.getValue())
      onListboxSelect(null)
    }

    waitMsgButton = true
  }

  function getStrSymbol(str, i)
  {
    if (i < str.len())
      return str.slice(i, i+1)
    return null
  }

  function onMsgButton(obj)
  {
    let value = obj.id.tointeger()
    if (value==null || !(value in msgButtons) || !waitMsgButton)
      return

    waitMsgButton = false
    guiScene.performDelayed(this, (@(value) function() {
      if ("optionType" in curItem)
      {
        optionsToSave.append({type = curItem.optionType, value = value})
        if ("isFilterObj" in curItem && curItem.isFilterObj)
        {
          let config = ::get_option(curItem.optionType)
          filter = config.values[value]
        }
      }
      if (("skipAllBefore" in curItem) && (value in curItem.skipAllBefore))
        skipAllBefore = curItem.skipAllBefore[value]
      if (("skip" in curItem) && (value in curItem.skip) && curItem.skip[value])
        if (typeof(curItem.skip[value]) == "array")
          skipList.extend(curItem.skip[value])
        else
          skipList.append(curItem.skip[value])
      if ("onButton" in curItem)
        curItem.onButton.call(this, value)
      nextItem()
    })(value))
  }

  function getCurListboxObj()
  {
    let listObj = scene.findObject("listbox")
    let value = listObj.getValue()
    if (value>=0 && value<listObj.childrenCount())
      return listObj.getChild(value)
    return null
  }

  function onListboxDblClick(obj)
  {
    let curObj = getCurListboxObj()
    if (curObj)
      onMsgButton(curObj)
  }

  function onListboxSelect(obj)
  {
    let curObj = getCurListboxObj()
    if (!curObj) return
    scene.findObject("listbox-hint").setValue("" + curObj.tooltip, true)
  }

  function askPresetsWnd()
  {
    curIdx = -1

    switchToDiv("options-wnd")
    let optObj = scene.findObject("optionlist")
    if (!::checkObj(optObj))
      return

    this.showSceneBtn("btn_prevItem", false)

    let optionItems = [
      [::USEROPT_CONTROLS_PRESET, "spinner"],
    ]
    let container = ::create_options_container("preset_options", optionItems, false)
    guiScene.replaceContentFromText(optObj, container.tbl, container.tbl.len(), this)
    processPresetValue(getOptionPresetValue())
    ::move_mouse_on_obj(scene.findObject("controls_preset"))
  }

  function getOptionPresetValue()
  {
    return ::get_option(::USEROPT_CONTROLS_PRESET).value
  }

  function onSelectPreset(obj)
  {
    processPresetValue(obj.getValue())
  }

  function processPresetValue(presetValue)
  {
    let opdata = ::get_option(::USEROPT_CONTROLS_PRESET)
    if (presetValue in opdata.values)
    {
      presetSelected = opdata.values[presetValue]
      this.showSceneBtn("btn_controlsWizard", presetSelected == "custom")
      this.showSceneBtn("btn_selectPreset", presetSelected != "custom")
    }
  }

  function onPresetDone(obj)
  {
    applyPreset(::applySelectedPreset(presetSelected))
  }

  function applyPreset(preset)
  {
    ::apply_joy_preset_xchange(preset)
    isPresetAlreadyApplied = true
    goBack()
  }

  function startManualSetup()
  {
    ::scene_msg_box("ask_unit_type", null, ::loc("mainmenu/askWizardForUnitType"),
      [
        [ "aviation", (@() startManualSetupForUnitType(::ES_UNIT_TYPE_AIRCRAFT)).bindenv(this) ],
        [ "army", (@() startManualSetupForUnitType(::ES_UNIT_TYPE_TANK)).bindenv(this) ]
      ], "aviation")
  }

  function startManualSetupForUnitType(esUnitType)
  {
    if (esUnitType == ::ES_UNIT_TYPE_TANK)
      controls_wizard_config = ::tank_controls_wizard_config
    else if (esUnitType == ::ES_UNIT_TYPE_AIRCRAFT)
      controls_wizard_config = ::aircraft_controls_wizard_config
    else
      ::script_net_assert_once("unsupported unit type", "Given unit type has not wizard config")

    ::initControlsWizardConfig(controls_wizard_config)
    initShortcutsNames()
    shortcuts = ::get_shortcuts(shortcutNames)

    curIdx = -1
    nextItem()
  }

  function onContinue(obj)
  {
    if (curIdx == -1 || !controls_wizard_config) {
      startManualSetup()
    } else {
      nextItem()
    }
  }

  function doApply()
  {
    ::set_controls_preset("")
    ::set_shortcuts(shortcuts, shortcutNames)
    foreach(option in optionsToSave)
      ::set_option(option.type, option.value)

    let device = ::joystick_get_default()
    curJoyParams.applyParams(device)
    ::joystick_set_cur_settings(curJoyParams)
    save(false)
  }

  function goBack()
  {
    if (curIdx>0 && !isPresetAlreadyApplied)
      this.msgBox("ask_save", ::loc("hotkeys/msg/wizardSaveUnfinished"),
        [
          ["yes", function() { doApply() } ],
          ["no", function() { ::gui_handlers.BaseGuiHandlerWT.goBack.bindenv(this)() }],
          ["cancel", @() null ],
        ], "yes", { cancel_fn = function() {}})
    else
      ::gui_handlers.BaseGuiHandlerWT.goBack.bindenv(this)()
  }

  function afterSave()
  {
    ::gui_handlers.BaseGuiHandlerWT.goBack.bindenv(this)()
  }

  function onEventActiveHandlersChanged(p)
  {
    enableListenerObj(curDivName == "shortcut-wnd" && isSceneActiveNoModals())
  }

  function afterModalDestroy()
  {
    guiScene.sleepKeyRepeat(false)
    ::set_bind_mode(false)
    ::preset_changed = true
    ::broadcastEvent("ControlsPresetChanged")
  }

  function showMsg(msg=null, config=null, time = 1.0)
  {
    switchToDiv("msg-wnd")
    if (msg==null)
      msg = ::loc("mainmenu/btnOk")
    scene.findObject("msg_text").setValue(msg)
    msgTimer = time + waitAxisAddTime

    local showAxis = false
    if (config && ("min" in config) && ("max" in config))
    {
      let name = isAxisVertical? "msg-real-box-vert" : "msg-real-box"
      moveTestItem(config.min, scene.findObject(name+"1"))
      moveTestItem(config.max, scene.findObject(name+"2"))
      showAxis = true
    }
    scene.findObject("msg-axis").show(showAxis && !isAxisVertical)
    scene.findObject("msg-axis-vert").show(showAxis && isAxisVertical)
  }

  function onUpdate(obj, dt)
  {
    if (msgTimer>0)
    {
      msgTimer -= dt
      if (msgTimer<=0)
        afterMsg()
      else
      if (msgTimer<=waitAxisAddTime)
        if (getCurAxisNum(dt, false) < 0)
        {
          msgTimer=0
          afterMsg()
        }
    }
  }

  function afterMsg()
  {
    if (axisApplyParams)
      onAxisApply()
    else
      nextItem()
  }
}
