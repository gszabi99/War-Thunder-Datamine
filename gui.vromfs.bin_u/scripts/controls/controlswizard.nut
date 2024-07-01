//-file:plus-string
from "%scripts/dagui_natives.nut" import joystick_get_default, set_bind_mode, is_axis_digital, get_axis_index, is_app_active
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { move_mouse_on_child, move_mouse_on_obj, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")

let { MAX_SHORTCUTS, CONTROL_TYPE } = require("%scripts/controls/controlsConsts.nut")
let { format } = require("string")
let { abs, ceil, fabs, floor } = require("math")
let globalEnv = require("globalEnv")
let { setDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let controlsPresetConfigPath = require("%scripts/controls/controlsPresetConfigPath.nut")
let { getHelpPreviewHandler } = require("%scripts/help/helpPreview.nut")
let { recomendedControlPresets, getControlsPresetBySelectedType
} = require("%scripts/controls/controlsUtils.nut")
let { joystickSetCurSettings, setShortcutsAndSaveControls
} = require("%scripts/controls/controlsCompatibility.nut")
let { set_option, create_options_container } = require("%scripts/options/optionsExt.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { USEROPT_HELPERS_MODE, USEROPT_VIEWTYPE, USEROPT_HELPERS_MODE_GM,
  USEROPT_CONTROLS_PRESET } = require("%scripts/options/optionsExtNames.nut")
let { getLocalizedControlName } = require("%scripts/controls/controlsVisual.nut")
let { steam_is_overlay_active } = require("steam")

::aircraft_controls_wizard_config <- [
  { id = "helpers_mode"
    type = CONTROL_TYPE.LISTBOX
    optionType = USEROPT_HELPERS_MODE
    isFilterObj = true
    skipAllBefore = [null, "msg/use_mouse_for_control", "msg/use_mouse_for_control", "msg/use_mouse_for_control"]
  }
    { id = "msg_defaults",
      text = loc("msg/mouseAimDefaults"),
      type = CONTROL_TYPE.MSG_BOX,
      options = ["#options/resetToDefaults", "#options/no"],
      defValue = 1,
      skipAllBefore = [null, "ID_BASIC_CONTROL_HEADER"]
    }
    { id = "msg_wasd_type",
      text = loc("controls/askKeyboardWasdType"),
      type = CONTROL_TYPE.MSG_BOX
      options = recomendedControlPresets.map(@(name) $"#msgbox/btn_{name}")
      defValue = 1,
      onButton = function(value) {
        let cType = recomendedControlPresets[value]
        let preset = getControlsPresetBySelectedType(cType)
        this.applyPreset(preset.fileName)
      }
    }
  { id = "msg/use_mouse_for_control", type = CONTROL_TYPE.MSG_BOX
    filterHide = [globalEnv.EM_MOUSE_AIM]
    needSkip = @() (isPlatformSony || isPlatformXboxOne)
    options = ["controls/useMouseControl", "controls/useMouseView", "controls/UseMouseNone"],
    skip = [null, null, ["msg/mouseWheelAction", "ID_CAMERA_NEUTRAL"]]
    onButton = function(value) {
      this.curJoyParams.setMouseAxis(0, ["ailerons", "camx", ""][value])
      this.curJoyParams.setMouseAxis(1, ["elevator", "camy", ""][value])
      this.curJoyParams.mouseJoystick = value == 0;
    }
  }


  { id = "ID_BASIC_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
    { id = "elevator", type = CONTROL_TYPE.AXIS, isVertical = true, showInverted = function() { return true }, msgType = "_elevator"
      images = ["wizard_elevator_up", "wizard_elevator_down"] }
    { id = "ailerons", type = CONTROL_TYPE.AXIS, msgType = "_horizontal"
      images = ["wizard_ailerons_right", "wizard_ailerons_left"] }
    { id = "rudder", type = CONTROL_TYPE.AXIS, msgType = "_horizontal"
      images = ["wizard_rudder_right", "wizard_rudder_left"] }
    { id = "throttle", type = CONTROL_TYPE.AXIS, isVertical = true,
      images = ["wizard_throttle_up", "wizard_throttle_down"]
      isSlider = true
      onAxisDone = function(isAxis, isSkipped) {
          if (isSkipped) {
            this.skipList.append("msg/holdThrottleForWEP")
            return
          }
          if (isAxis) {
            this.curJoyParams.holdThrottleForWEP = false
            this.skipList.append("msg/holdThrottleForWEP")
          }
          let axis = this.curJoyParams.getAxis(get_axis_index("throttle"))
          axis.relative = !isAxis
          ::g_controls_manager.commitControls()
        }
      skip = ["msg/holdThrottleForWEP"] //dont work in axis, but need to correct prevItem work, when skipList used in onAxisDone
    }
    { id = "msg/holdThrottleForWEP", type = CONTROL_TYPE.MSG_BOX
      options = ["#options/yes", "#options/no", "options/skip"],
      onButton = function(value) { if (value < 2) this.curJoyParams.holdThrottleForWEP = value == 0 }
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
    "ID_COUNTERMEASURES_FLARES"
    "ID_COUNTERMEASURES_CHAFF"
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
    { id = "weapon_aim_heading", type = CONTROL_TYPE.AXIS, msgType = "_horizontal", buttonRelative = true }
    { id = "weapon_aim_pitch",   type = CONTROL_TYPE.AXIS, isVertical = true,       buttonRelative = true }
    "ID_RELOAD_GUNS"
    "ID_GEAR"
    { id = "ID_AIR_BRAKE", filterShow = [globalEnv.EM_REALISTIC, globalEnv.EM_FULL_REAL] }
    "ID_FLAPS"
    "ID_LOCK_TARGET"
    "ID_TOGGLE_LASER_DESIGNATOR"
    "ID_NEXT_TARGET"
    "ID_PREV_TARGET"
    "ID_TACTICAL_MAP"
    "ID_MPSTATSCREEN"
    "ID_TOGGLE_CHAT_TEAM"
    "ID_TOGGLE_CHAT"


  { id = "ID_VIEW_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
    { id = "msg/viewControl", type = CONTROL_TYPE.MSG_BOX
      options = ["#options/yes", "#options/no"], //defValue = 0
      skipAllBefore = [null, "ID_FULL_AERODYNAMICS_HEADER"]
    }

    { id = "viewtype", type = CONTROL_TYPE.MSG_BOX
      optionType = USEROPT_VIEWTYPE
    }
    "ID_CAMERA_DEFAULT"
    { id = "camx", type = CONTROL_TYPE.AXIS, msgType = "_horizontal", relSens = 0.75
      images = ["wizard_camx_right", "wizard_camx_left"]
      axesList = ["camx", "turret_x"]
      filterHide = [globalEnv.EM_MOUSE_AIM] }
    { id = "camy", type = CONTROL_TYPE.AXIS, isVertical = true, relSens = 0.75
      images = ["wizard_camy_up", "wizard_camy_down"]
      axesList = ["camy", "turret_y"]
      filterHide = [globalEnv.EM_MOUSE_AIM] }
    { id = "msg/relative_camera_axis", type = CONTROL_TYPE.MSG_BOX
      options = ["#options/yes", "#options/no"],
      skip = ["neutral_cam_pos", null]
      onButton = function(value) {
        foreach (a in ["camx", "camy", "turret_x", "turret_y"]) {
          let axis = this.curJoyParams.getAxis(get_axis_index(a))
          axis.relative = value != 0
          axis.innerDeadzone = (value != 0) ? 0.25 : 0.05
        }
        ::g_controls_manager.commitControls()
      }
    }
      { id = "neutral_cam_pos", type = CONTROL_TYPE.SHORTCUT_GROUP
        shortcuts = ["camx_rangeSet", "camy_rangeSet", "turret_x_rangeSet", "turret_y_rangeSet"]
      }
    "ID_TOGGLE_VIEW"
    "ID_TARGET_CAMERA"

      //hidden when no use mouse
      { id = "msg/mouseWheelAction", type = CONTROL_TYPE.MSG_BOX
        options = ["controls/none", "controls/zoom", "controls/throttle"], defValue = 1
        onButton = function(value) {
          this.curJoyParams.setMouseAxis(2, ["", "zoom", "throttle"][value])
        }
      }
      "ID_CAMERA_NEUTRAL" //mouse look

    "ID_ZOOM_TOGGLE"
    { id = "zoom", type = CONTROL_TYPE.AXIS, filterHide = [globalEnv.EM_MOUSE_AIM]
      isSlider = true }
    { id = "msg/trackIR", type = CONTROL_TYPE.MSG_BOX
      filterHide = [globalEnv.EM_MOUSE_AIM]
      options = ["#options/yes", "#options/no", "options/skip"], defValue = 1
      skip = [null, "trackIrZoom", "trackIrZoom"]
    }
      { id = "trackIrZoom", type = CONTROL_TYPE.MSG_BOX
        filterHide = [globalEnv.EM_MOUSE_AIM]
        options = ["#options/yes", "#options/no"]
        onButton = function(value) { if (value < 2) this.curJoyParams.trackIrZoom = value == 0 }
      }


  { id = "ID_FULL_AERODYNAMICS_HEADER", type = CONTROL_TYPE.HEADER
    filterShow = [globalEnv.EM_FULL_REAL]
  }
    { id = "ID_TRIM", filterShow = [globalEnv.EM_FULL_REAL] }
    { id = "ID_TRIM_RESET", filterShow = [globalEnv.EM_FULL_REAL] }
    { id = "ID_TRIM_SAVE", filterShow = [globalEnv.EM_FULL_REAL] }
    { id = "helicopter_trim_elevator", type = CONTROL_TYPE.AXIS, isVertical = true, buttonRelative = true
      images = ["wizard_elevator_up", "wizard_elevator_down"]
      filterShow = [globalEnv.EM_FULL_REAL] }
    { id = "helicopter_trim_ailerons", type = CONTROL_TYPE.AXIS, msgType = "_horizontal", buttonRelative = true
      images = ["wizard_ailerons_right", "wizard_ailerons_left"]
      filterShow = [globalEnv.EM_FULL_REAL] }
    { id = "helicopter_trim_rudder", type = CONTROL_TYPE.AXIS, msgType = "_horizontal", buttonRelative = true
      images = ["wizard_rudder_right", "wizard_rudder_left"]
      filterShow = [globalEnv.EM_FULL_REAL] }
    { id = "trim_elevator", type = CONTROL_TYPE.AXIS, isVertical = true, buttonRelative = true
      images = ["wizard_elevator_up", "wizard_elevator_down"]
      filterShow = [globalEnv.EM_FULL_REAL] }
    { id = "trim_ailerons", type = CONTROL_TYPE.AXIS, msgType = "_horizontal", buttonRelative = true
      images = ["wizard_ailerons_right", "wizard_ailerons_left"]
      filterShow = [globalEnv.EM_FULL_REAL] }
    { id = "trim_rudder", type = CONTROL_TYPE.AXIS, msgType = "_horizontal", buttonRelative = true
      images = ["wizard_rudder_right", "wizard_rudder_left"]
      filterShow = [globalEnv.EM_FULL_REAL] }
    { id = "ID_FLAPS_DOWN", filterShow = [globalEnv.EM_FULL_REAL] }
    { id = "ID_FLAPS_UP", filterShow = [globalEnv.EM_FULL_REAL] }
    { id = "brake_right",  type = CONTROL_TYPE.AXIS, filterHide = [globalEnv.EM_MOUSE_AIM]
      images = ["wizard_brake_right_stop", "wizard_brake_right_go"]
      isSlider = true }
    { id = "brake_left",   type = CONTROL_TYPE.AXIS, filterHide = [globalEnv.EM_MOUSE_AIM]
      images = ["wizard_brake_left_stop", "wizard_brake_left_go"]
      isSlider = true }


  { id = "ID_ENGINE_CONTROL_HEADER", type = CONTROL_TYPE.HEADER
    filterShow = [globalEnv.EM_FULL_REAL]
  }
    { id = "ID_COMPLEX_ENGINE", filterShow = [globalEnv.EM_FULL_REAL] }
    { id = "ID_TOGGLE_ENGINE", filterShow = [globalEnv.EM_FULL_REAL] }
    { id = "prop_pitch", type = CONTROL_TYPE.AXIS, isSlider = true, buttonRelative = true
      filterShow = [globalEnv.EM_FULL_REAL] }
    { id = "ID_PROP_PITCH_AUTO", filterShow = [globalEnv.EM_FULL_REAL] }
    { id = "mixture", type = CONTROL_TYPE.AXIS, isSlider = true, buttonRelative = true
      filterShow = [globalEnv.EM_FULL_REAL] }
    { id = "radiator", type = CONTROL_TYPE.AXIS, isSlider = true, buttonRelative = true
      filterShow = [globalEnv.EM_FULL_REAL] }
    { id = "oil_radiator", type = CONTROL_TYPE.AXIS, isSlider = true, buttonRelative = true,
      filterShow = [globalEnv.EM_FULL_REAL]  }
    { id = "ID_RADIATOR_AUTO", filterShow = [globalEnv.EM_FULL_REAL] }
    { id = "turbo_charger", type = CONTROL_TYPE.AXIS, isSlider = true, buttonRelative = true
      filterShow = [globalEnv.EM_FULL_REAL] }
    { id = "ID_TOGGLE_AUTO_TURBO_CHARGER", filterShow = [globalEnv.EM_FULL_REAL] }
    { id = "ID_SUPERCHARGER", filterShow = [globalEnv.EM_FULL_REAL] }


  { id = "msg/wizard_done_msg", type = CONTROL_TYPE.MSG_BOX }
]

::tank_controls_wizard_config <- [
  { id = "helpers_mode"
    type = CONTROL_TYPE.LISTBOX
    optionType = USEROPT_HELPERS_MODE_GM
    isFilterObj = true
  }
  { id = "ID_ENGINE_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
    { id = "gm_throttle", type = CONTROL_TYPE.AXIS, isVertical = true }
    { id = "gm_steering", type = CONTROL_TYPE.AXIS, msgType = "_horizontal", showInverted = function() { return true } }
    { id = "gm_clutch", type = CONTROL_TYPE.AXIS, isVertical = true, filterHide = [globalEnv.EM_MOUSE_AIM] }

  { id = "ID_BASIC_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
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

  { id = "ID_VIEW_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
    { id = "gm_mouse_aim_x", type = CONTROL_TYPE.AXIS, filterHide = [globalEnv.EM_MOUSE_AIM], msgType = "_horizontal" }
    { id = "gm_mouse_aim_y", type = CONTROL_TYPE.AXIS, filterHide = [globalEnv.EM_MOUSE_AIM], isVertical = true }
    "ID_TOGGLE_VIEW_GM"
    "ID_ZOOM_TOGGLE"

  { id = "ID_MISC_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
    "ID_TACTICAL_MAP"  //common for everyone
    "ID_MPSTATSCREEN"  //common for everyone
    "ID_TOGGLE_CHAT_TEAM" //common for everyone
    "ID_TOGGLE_CHAT" //common for everyone

  { id = "msg/wizard_done_msg", type = CONTROL_TYPE.MSG_BOX }
]

::initControlsWizardConfig <- function initControlsWizardConfig(arr) {
  for (local i = 0; i < arr.len(); i++) {
    if (type(arr[i]) == "string")
      arr[i] = { id = arr[i] }
    if (!("type" in arr[i]))
      arr[i].type <- CONTROL_TYPE.SHORTCUT
    if (arr[i].type == CONTROL_TYPE.AXIS) {
      if (!("axesList" in arr[i]) || arr[i].axesList.len() < 1)
        arr[i].axesList <- [arr[i].id]
      arr[i].axisIndex <- []
      foreach (a in arr[i].axesList)
        arr[i].axisIndex.append(get_axis_index(a))
      arr[i].modifiersId <- {}
    }
    arr[i].shortcutId <- -1
  }
}

::gui_modal_controlsWizard <- function gui_modal_controlsWizard() {
  if (!hasFeature("ControlsPresets"))
    return
  loadHandler(gui_handlers.controlsWizardModalHandler)
}

function isInArrayRecursive(v, arr) {
  foreach (i in arr) {
    if (v == i)
      return true
    else if (type(i) == "array" && isInArrayRecursive(v, i))
        return true
  }
  return false
}

gui_handlers.controlsWizardModalHandler <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/controlsWizard.blk"
  sceneNavBlkName = null

  unitType = ES_UNIT_TYPE_AIRCRAFT
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
  previewHandler = null


  function initScreen() {
    this.scene.findObject("input-listener").setUserData(this)
    this.scene.findObject("update-timer").setUserData(this)

    this.skipList = []
    this.optionsToSave = []
    this.repeatItemsList = []
    this.prevItems = []
    this.shortcutNames = []
    this.shortcutItems = []

    this.curJoyParams = ::joystick_get_cur_settings()
    this.deviceMapping = u.copy(::g_controls_manager.getCurPreset().deviceMapping)

    this.initAxisPresetup()

    this.loadPreview()
    this.askPresetsWnd()
  }

  function loadPreview() {
    let container = this.scene.findObject("preview-wnd")
    this.previewHandler = getHelpPreviewHandler({ scene = container })
  }

  function initShortcutsNames() {
    this.shortcutNames = []
    this.shortcutItems = []

    for (local i = 0; i < this.controls_wizard_config.len(); i++) {
      let item = this.controls_wizard_config[i]

      if (item.type == CONTROL_TYPE.SHORTCUT) {
        item.shortcutId = this.shortcutNames.len()
        this.shortcutNames.append(item.id)
        this.shortcutItems.append(item)
      }
      else if (item.type == CONTROL_TYPE.SHORTCUT_GROUP) {
        item.shortcutId = []
        foreach (_idx, name in item.shortcuts) {
          item.shortcutId.append(this.shortcutNames.len())
          this.shortcutNames.append(name)
          this.shortcutItems.append(item)
        }
      }
      else if (item.type == CONTROL_TYPE.AXIS) {
        item.modifiersId = {}
        foreach (name in ["rangeMax", "rangeMin"]) { //order is important
          item.modifiersId[name] <- []
          foreach (a in item.axesList) {
            item.modifiersId[name].append(this.shortcutNames.len())
            this.shortcutNames.append(a + "_" + name)
            this.shortcutItems.append(item)
          }
        }
      }
    }
  }

  function getItemText(item) {
    if ("text" in item)
      return item.text
    if (item.type == CONTROL_TYPE.AXIS)
      return "controls/" + item.id
    else if ("optionType" in item)
      return "options/" + ::get_option(item.optionType).id

    return "hotkeys/" + item.id
  }

  function getItemName(item) {
    if ("name" in item)
      return item.name
    else if (item.type == CONTROL_TYPE.AXIS)
      return "controls/" + item.id
    return "hotkeys/" + item.id
  }

  function nextItem() {
    if (!checkObj(this.scene))
      return

    this.isButtonsListenInCurBox = false
    this.isAxisListenInCurBox = false

    local isItemOk = true
    this.isRepeat = false
    if (this.repeatItemsList.len() > 0) {
      this.curItem = this.repeatItemsList[0]
      this.repeatItemsList.remove(0)
      isItemOk = false
      this.isRepeat = true
    }
    else {
      this.curIdx++
      if (!(this.curIdx in this.controls_wizard_config)) {
        this.doApply()
        return
      }

      this.curItem = this.controls_wizard_config[this.curIdx]

      this.switchListenAxis(false)
      this.switchListenButton(false)

      if (this.skipAllBefore != null)
        if (this.skipAllBefore == this.curItem.id)
          this.skipAllBefore = null
        else
          return this.nextItem()
      if (isInArray(this.curItem.id, this.skipList))
        return this.nextItem()
      if (("isFilterObj" in this.curItem) && this.curItem.isFilterObj && !::can_change_helpers_mode()) {
        if ("optionType" in this.curItem) {
          let config = ::get_option(this.curItem.optionType)
          this.filter = config.values[config.value]
        }
        else
          assert(false, "Error: not found optionType in wizard filterObj.")
        return this.nextItem()
      }
      if (this.filter != null &&
           ((("filterShow" in this.curItem) && !isInArray(this.filter, this.curItem.filterShow))
             || (("filterHide" in this.curItem) && isInArray(this.filter, this.curItem.filterHide))))
        return this.nextItem()

      if ("needSkip" in this.curItem && this.curItem.needSkip && this.curItem.needSkip())
        return this.nextItem()
    }

    if (this.curItem.type == CONTROL_TYPE.HEADER) {
      this.scene.findObject("wizard-title").setValue(loc(this.getItemText(this.curItem)))
      isItemOk = false
      this.nextItem()
    }
    else if (this.curItem.type == CONTROL_TYPE.SHORTCUT || this.curItem.type == CONTROL_TYPE.SHORTCUT_GROUP) {
      this.switchToDiv("shortcut-wnd")
      this.askShortcut()
    }
    else if (this.curItem.type == CONTROL_TYPE.AXIS) {
      this.axisMaxChoosen = false
      this.askAxis()
    }
    else if (this.curItem.type == CONTROL_TYPE.MSG_BOX) {
      this.switchToDiv("msgBox-wnd")
      this.showMsgBox()
    }
    else if (this.curItem.type == CONTROL_TYPE.LISTBOX) {
      this.switchToDiv("listbox-wnd")
      this.showMsgBox(true)
    }
    else {
      isItemOk = false
      this.nextItem()
    }

    if (isItemOk)
      this.prevItems.append(this.curIdx)

    this.updateButtons()
    showObjById("btn_prevItem", this.prevItems.len() > 0, this.scene)
    showObjById("btn_controlsWizard", this.prevItems.len() == 0, this.scene)
  }

  function onPrevItem() {
    this.isButtonsListenInCurBox = false
    this.isAxisListenInCurBox = false

    if (this.curIdx == 0) {
      this.askPresetsWnd()
      return
    }

    if (this.prevItems.len() == 0)
      return

    if (this.msgTimer > 0) { //after axis bind message
      this.msgTimer = 0
      this.isRepeat = true
    }

    this.repeatItemsList = []

    local lastIdx = this.prevItems[this.prevItems.len() - 1]
    if (this.isRepeat) {
      this.curIdx = lastIdx - 1
      this.prevItems.remove(this.prevItems.len() - 1)
      this.nextItem()
    }
    else if (this.curItem.type == CONTROL_TYPE.AXIS && this.axisMaxChoosen) {
      this.axisMaxChoosen = false
      this.axisFixed = false
      this.selectedAxisNum = -1
      this.askAxis()
    }
    else {
      this.prevItems.remove(this.prevItems.len() - 1)
      if (this.prevItems.len() == 0)
        return

      lastIdx = this.prevItems[this.prevItems.len() - 1]
      this.prevItems.remove(this.prevItems.len() - 1)
      this.curIdx = lastIdx - 1

      let lastItem = this.controls_wizard_config[lastIdx]
      if ("skip" in lastItem)
        for (local i = this.skipList.len() - 1; i >= 0; i--)
          if (isInArrayRecursive(this.skipList[i], lastItem.skip))
            this.skipList.remove(i)

      this.nextItem()
    }

    this.updateButtons()
  }

  function switchToDiv(divName) {
    if (!checkObj(this.scene))
      return

    foreach (name in ["msgBox-wnd", "shortcut-wnd", "listbox-wnd", "options-wnd", "msg-wnd", "preview-wnd"]) {
      let divObj = this.scene.findObject(name)
      if (!checkObj(divObj))
        continue

      divObj.show(divName == name)
    }

    if (divName != "msg-wnd")
      this.curDivName = divName

    if (divName == "options-wnd")
      this.scene.findObject("preview-wnd").show(true)

    this.enableListenerObj(this.curDivName == "shortcut-wnd")
  }

  function enableListenerObj(isEnable) {
    let obj = showObjById("input-listener", isEnable, this.scene)
    if (isEnable)
      obj.select()
  }

  function askShortcut() {
    if (!checkObj(this.scene))
      return

    this.axisMaxChoosen = false
    this.scene.findObject("shortcut_text").setValue(loc(this.getItemText(this.curItem)))
    let textObj = this.scene.findObject("hold_axis")
    if (checkObj(textObj)) {
      textObj.setValue(loc("hotkeys/msg/press_a_key"))
      textObj.show(true)
    }
    this.scene.findObject("shortcut_image")["background-image"] = ""
    showObjById("btn-reset-axis-input", false, this.scene)
    this.clearShortcutInfo()

    this.isButtonsListenInCurBox = true
    this.switchListenButton(true)
    this.setCurAssignedButtonsText()
  }

  function askAxis() {
    this.switchToDiv("shortcut-wnd")
    this.axisApplyParams = null
    this.scene.findObject("shortcut_text").setValue(loc(this.getItemText(this.curItem)))

    this.isButtonsListenInCurBox = !this.axisMaxChoosen || this.axisTypeButtons
    this.scene.findObject("shortcut_current_button").setValue(this.isButtonsListenInCurBox ? "?" : "")
    this.clearShortcutInfo()
    this.switchListenButton(this.isButtonsListenInCurBox)

    this.isAxisListenInCurBox = !this.axisMaxChoosen || !this.axisTypeButtons
    this.switchListenAxis(this.isAxisListenInCurBox, !this.axisMaxChoosen)
    if (!this.axisMaxChoosen) {
      this.bindAxisNum = -1
      this.selectedAxisNum = -1
    }
    this.updateAxisPressKey()
    this.updateAxisName()
    this.setCurAssignedButtonsText()
    this.updateButtons()
  }

  function setCurAssignedButtonsText() {
    local axisAssignText = ""
    local buttonAssignText = ""

    if (this.curItem.type == CONTROL_TYPE.AXIS) {
      let axis = this.curJoyParams.getAxis(this.curItem.axisIndex[0])
      let curPreset = ::g_controls_manager.getCurPreset()
      if (axis.axisId >= 0)
        axisAssignText = ::addHotkeyTxt(::remapAxisName(curPreset, axis.axisId))
      if (this.isButtonsListenInCurBox)
        buttonAssignText = ::get_shortcut_text({
          shortcuts = this.shortcuts,
          shortcutId = this.curItem.modifiersId[this.axisMaxChoosen ? "rangeMin" : "rangeMax"][0],
          cantBeEmpty = false
        })
    }
    else if (this.curItem.type == CONTROL_TYPE.SHORTCUT)
      buttonAssignText = ::get_shortcut_text({
        shortcuts = this.shortcuts,
        shortcutId = this.curItem.shortcutId,
        cantBeEmpty = false
      })

    local assignText = axisAssignText + ((buttonAssignText == "" || axisAssignText == "") ? "" : loc("ui/semicolon")) + buttonAssignText
    if (assignText == "")
      assignText = "---"

    this.scene.findObject("curAssign_text").setValue(loc("controls/currentAssign") + loc("ui/colon") + assignText)
  }

  function updateAxisPressKey() {
    local imgId = 0
    local msgLocId = "hotkeys/msg/choose_maxValue"
    if (this.axisTypeButtons && this.axisMaxChoosen) {
      msgLocId = "hotkeys/msg/choose_minValue_button"
      imgId = 1
    }
    if (!this.axisTypeButtons)
      if (this.selectedAxisNum >= 0) {
        msgLocId = "hotkeys/msg/choose_minValue_axis"
        imgId = 1
      }
    if ("msgType" in this.curItem)
      msgLocId += this.curItem.msgType

    let textObj = this.scene.findObject("hold_axis")
    if (checkObj(textObj)) {
      textObj.setValue(loc(msgLocId))
      textObj.show(true)
    }

    local image = ""
    if (("images" in this.curItem) && (imgId in this.curItem.images))
      image = $"#ui/images/wizard/{this.curItem.images[imgId]}"
    this.scene.findObject("shortcut_image")["background-image"] = image
  }

  function setAxisType(isButtons) {
    this.axisTypeButtons = isButtons
    if (this.axisTypeButtons)
      this.switchListenAxis(false)
    else {
      this.clearShortcutInfo()
      this.switchListenButton(false)
    }

    showObjById("btn-reset-axis-input", this.selectedAxisNum >= 0 || this.axisMaxChoosen, this.scene)
  }

  function switchListenButton(value) {
    this.isListenButton = value
    let obj = this.scene.findObject("shortcut_current_button")
    if (checkObj(obj)) {
      obj.show(value)
      obj.setValue("?")
    }

    this.guiScene.sleepKeyRepeat(value)
    set_bind_mode(value)
  }

  function switchListenAxis(value, reinitPresetup = false) {
    this.isListenAxis = value

    this.isAxisVertical = ("isVertical" in this.curItem) ? this.curItem.isVertical : false
    this.scene.findObject("test-axis").show(value && !this.isAxisVertical)
    this.scene.findObject("test-axis-vert").show(value && this.isAxisVertical)
    this.scene.findObject("bind-axis-name").show(value)

    if (value) {
      this.axisFixed = false
      if (reinitPresetup)
        this.initAxisPresetup()
    }
    showObjById("btn-reset-axis-input", this.axisMaxChoosen, this.scene)
  }

  function updateSwitchModesButton() {
    let isShow = this.curDivName == "shortcut-wnd" && this.selectedAxisNum < 0 && !this.axisMaxChoosen
    showObjById("btn_switchAllModes", isShow, this.scene)

    if (!isShow)
      return

    let isEnabled = this.isListenAxis || this.isListenButton
    let sampleText = loc("mainmenu/shortcuts") + " (%s" + loc("options/" + (isEnabled ? "enabled" : "disabled")) + "%s)"
    let coloredText = format(sampleText, "<color=@" + (isEnabled ? "goodTextColor" : "warningTextColor") + ">", "</color>")
    let NotColoredText = format(sampleText, "", "")

    setDoubleTextToButton(this.scene, "btn_switchAllModes", NotColoredText, coloredText)
  }

  function switchAllListenModes(_obj) {
    this.axisCurTime = 0.0
    let btnObj = this.scene.findObject("btn_switchAllModes")
    if (!btnObj.isEnabled())
      this.onResetAxisInput()
    else {
      this.clearShortcutInfo()
      this.switchButtonMode()
    }
    this.updateButtons()
  }

  function switchButtonMode() {
    if (this.curDivName != "shortcut-wnd")
      return
    let enable = !(this.isListenAxis || this.isListenButton)
    this.enableListenerObj(enable)
    this.scene.findObject("hold_axis").show(enable)
    if (this.isAxisListenInCurBox)
      this.switchListenAxis(enable, true)
    if (this.isButtonsListenInCurBox)
      this.switchListenButton(enable)
  }

  function updateButtons() {
    let isInListenWnd = this.curDivName == "shortcut-wnd"
    let isListening   = isInListenWnd && (this.isListenAxis || this.isListenButton)

    if (showConsoleButtons.value) {
      foreach (name in ["keep_assign_btn", "btn_prevItem", "btn_controlsWizard", "btn_selectPreset"]) {
        let btnObj = this.scene.findObject(name)
        if (checkObj(btnObj)) {
          btnObj.hideConsoleImage = isListening ? "yes" : "no"
          btnObj.inactiveColor = isListening ? "yes" : "no"
        }
      }
    }

    this.updateSwitchModesButton()
    showObjById("keep_assign_btn", isInListenWnd, this.scene)
    showObjById("btn-reset-axis-input", isInListenWnd && (this.axisMaxChoosen || this.selectedAxisNum >= 0), this.scene)
    showObjById("btn_back", !isListening, this.scene)
  }

  function onButtonDone() {
    if (this.curItem.type == CONTROL_TYPE.AXIS)
      if (!this.axisMaxChoosen) {
        this.axisMaxChoosen = true
        this.setAxisType(true)
        this.askAxis()
        return
      }
      else {
        let axis = this.curJoyParams.getAxis(this.curItem.axisIndex[0])
        axis.relative = ("buttonRelative" in this.curItem) ? this.curItem.buttonRelative : false
        axis.relSens = ("relSens" in this.curItem) ? this.curItem.relSens : 1.0
        axis.relStep = ("relStep" in this.curItem) ? this.curItem.relStep : 0
        ::g_controls_manager.commitControls()
      }

    if (this.curItem.type == CONTROL_TYPE.AXIS && ("onAxisDone" in this.curItem))
      this.curItem.onAxisDone.call(this, !this.axisTypeButtons, false)
    this.nextItem()
  }

  function onButtonEntered(obj) {
    if (this.isButtonsListenInCurBox && !this.isListenButton)
      return

    this.switchListenButton(false)
    let sc = this.readShortcutInfo(obj)
    if (sc.dev.len() > 0 && sc.dev.len() == sc.btn.len())
      if (this.bindShortcut(sc.dev, sc.btn))
        return

    this.onButtonDone()
  }

  function isKbdOrMouse(devs) { // warning disable: -named-like-return-bool
    local isKbd = null
    foreach (d in devs)
      if (d > 0)
        if (isKbd == null)
          isKbd = d < JOYSTICK_DEVICE_0_ID
        else if (isKbd != (d < JOYSTICK_DEVICE_0_ID))
            return null
    return isKbd
  }

  function doBind(devs, btns, shortcutId) {
    if (type(shortcutId) == "array") {
      foreach (id in shortcutId)
        this.doBind(devs, btns, id)
    }
    else if (type(shortcutId) == "integer" && devs.len() > 0) {
      let isKbd = this.isKbdOrMouse(devs)
      if (isKbd == null)
        this.shortcuts[shortcutId] = [{ dev = devs, btn = btns }]
      else {
        for (local i = this.shortcuts[shortcutId].len() - 1; i >= 0; i--)
          if (isKbd == this.isKbdOrMouse(this.shortcuts[shortcutId][i].dev))
            this.shortcuts[shortcutId].remove(i)   //remove shortcuts by same device type
        this.shortcuts[shortcutId].append({ dev = devs, btn = btns })
        if (this.shortcuts[shortcutId].len() > MAX_SHORTCUTS)
          this.shortcuts[shortcutId].remove(0)
      }
    }
  }

  function bindShortcut(devs, btns) {
    local shortcutId = this.curItem.shortcutId
    if (this.curItem.type == CONTROL_TYPE.AXIS)
      shortcutId = this.curItem.modifiersId[this.axisMaxChoosen ? "rangeMin" : "rangeMax"]

    let curBinding = this.findButtons(devs, btns, shortcutId)
    if (!curBinding || curBinding.len() == 0) {
      this.doBind(devs, btns, shortcutId)
      return false
    }

    local actionText = ""
    foreach (binding in curBinding)
      actionText += ((actionText == "") ? "" : ", ") + loc("hotkeys/" + this.shortcutNames[binding[0]])
    let msg = loc("hotkeys/msg/unbind_question", { action = actionText })
    this.msgBox("controls_wizard_bind_existing_shortcut", msg, [
      ["add", function() {
        this.doBind(devs, btns, shortcutId)
        this.onButtonDone()
      }],
      ["replace", function() {
        foreach (binding in curBinding) {
          this.shortcuts[binding[0]].remove(binding[1])
          let item = this.shortcutItems[binding[0]]
          if (!isInArray(item, this.repeatItemsList))
            this.repeatItemsList.append(item)
        }
        this.doBind(devs, btns, shortcutId)
        this.onButtonDone()
      }],
      ["cancel", function() { this.askShortcut() }],
      ["skip", function() { this.onButtonDone() }],
    ], "add")
    return true
  }

  function findButtons(devs, btns, shortcutId) {
    let firstSc = (type(shortcutId) == "integer") ? shortcutId : shortcutId[0]
    let scItem = this.shortcutItems[firstSc]
    if (firstSc > this.maxCheckSc)
      this.maxCheckSc = firstSc
    let res = []
    let foundedItems = []

    for (local i = 0; i < this.maxCheckSc; i++) {
      if (firstSc == i || ((type(shortcutId) == "array") && isInArray(i, shortcutId)))
        continue
      let item = this.shortcutItems[i]
      if (item == scItem && (item.type != CONTROL_TYPE.AXIS || i == scItem.modifiersId[this.axisMaxChoosen ? "rangeMin" : "rangeMax"]))
        continue
      if (isInArray(item, this.repeatItemsList) || isInArray(item, foundedItems))
        continue

      let event = this.shortcuts[i]
      foreach (btnIdx, button in event) {
        if (!button || button.dev.len() != devs.len())
          continue
        local numEqual = 0
        for (local j = 0; j < button.dev.len(); j++)
          for (local k = 0; k < devs.len(); k++)
            if ((button.dev[j] == devs[k]) && (button.btn[j] == btns[k]))
              numEqual++

        if (numEqual == btns.len()) {
          res.append([i, btnIdx])
          foundedItems.append(item)
        }
      }
    }
    return res
  }

  function onCancelButtonInput(_obj) {
    if (this.isButtonsListenInCurBox || (this.curItem.type == CONTROL_TYPE.AXIS && !this.axisTypeButtons)) {
      this.switchListenButton(false)
      this.switchListenAxis(false)
      this.selectedAxisNum = -1
      this.axisApplyParams = null
      if ("onAxisDone" in this.curItem)
        this.curItem.onAxisDone.call(this, !this.axisTypeButtons, true)
      this.nextItem()
    }
  }

  function onButtonAdded(obj) {
    if (!this.isButtonsListenInCurBox && !this.isListenButton)
      return

    let sc = this.readShortcutInfo(obj)
    this.curBtnText = this.getShortcutText(sc) + ((this.lastNumButtons >= 3) ? "" : (this.lastNumButtons > 0) ? " + ?" : "?")
    this.scene.findObject("shortcut_current_button").setValue(this.curBtnText)
  }

  function getShortcutText(sc) {
    local text = ""
    let curPreset = ::g_controls_manager.getCurPreset()
    for (local i = 0; i < sc.dev.len(); i++)
      text += ((i != 0) ? " + " : "") + getLocalizedControlName(curPreset, sc.dev[i], sc.btn[i])
    return text
  }

  function readShortcutInfo(obj) {
    let res = { dev = [], btn = [] }
    this.lastNumButtons = 0

    for (local i = 0; i < 3; i++) {
      if (obj["device" + i] != "" && obj["button" + i] != "") {
        let devId = obj["device" + i].tointeger()
        let btnId = obj["button" + i].tointeger()
        res.dev.append(devId)
        res.btn.append(btnId)
        this.lastNumButtons++
      }
    }

    return res
  }

  function clearShortcutInfo() {
    let obj = this.scene.findObject("input-listener")
    for (local i = 0; i < 3; i++) {
      obj["device" + i] = ""
      obj["button" + i] = ""
    }
  }

  function onAxisSelected() {
    this.switchListenAxis(false)
    this.onAxisDone()
  }

  function onAxisDone() {
    this.switchListenAxis(false)
    foreach (name in ["keep_assign_btn", "btn_prevItem", "btn_controlsWizard", "btn_selectPreset", "btn-reset-axis-input"])
      showObjById(name, false, this.scene)

    let config = this.presetupAxisRawValues[this.selectedAxisNum]

    this.axisApplyParams = {}
    this.axisApplyParams.invert <- false
    if (fabs(config.min - this.bindAxisFixVal) < fabs(config.max - this.bindAxisFixVal))
      this.axisApplyParams.invert = true
    this.axisApplyParams.relSens <- ("relSens" in this.curItem) ? this.curItem.relSens : 1.0
    this.axisApplyParams.relStep <- ("relStep" in this.curItem) ? this.curItem.relStep : 0

    this.axisApplyParams.isSlider <- ("isSlider" in this.curItem) ? this.curItem.isSlider : false
    this.axisApplyParams.kAdd <- 0
    this.axisApplyParams.kMul <- 1.0

    if (!this.axisApplyParams.isSlider) {
      let minDev = min(abs(config.max), abs(config.min))
      if (minDev >= 3200) //10%
        this.axisApplyParams.kMul = 0.1 * floor(320000.0 / minDev)
      else
        this.axisApplyParams.isSlider = true  //count this axis as slider
    }
    if (this.axisApplyParams.isSlider) {
      this.axisApplyParams.kMul = 2.0 * 32000 / (config.max - config.min) * 1.05 //accuracy 5%
      this.axisApplyParams.kMul = 0.1 * ceil(10.0 * this.axisApplyParams.kMul)
      this.axisApplyParams.kAdd = -0.5 * (config.min + config.max) / 32000 * this.axisApplyParams.kMul
    }

    let curPreset = ::g_controls_manager.getCurPreset()
    this.curBtnText = ::remapAxisName(curPreset, this.selectedAxisNum)
    this.showMsg(loc("hotkeys/msg/axis_choosen") + "\n" + this.curBtnText, config)
  }

  function bindAxis() {
    if (!this.axisApplyParams)
      return

    foreach (idx, _aName in this.curItem.axesList) {
      let axisIndex = this.curItem.axisIndex[idx]
      this.curJoyParams.bindAxis(axisIndex, this.selectedAxisNum)
      let axis = this.curJoyParams.getAxis(axisIndex)
      axis.inverse = this.axisApplyParams.invert
      axis.innerDeadzone = this.axisApplyParams.isSlider ? 0 : 0.02
      axis.nonlinearity = this.axisApplyParams.isSlider ? 0 : 1
      axis.relative = false
      axis.relSens = this.axisApplyParams.relSens
      axis.relStep = this.axisApplyParams.relStep
      axis.kAdd = this.axisApplyParams.kAdd
      axis.kMul = this.axisApplyParams.kMul
    }

    ::g_controls_manager.commitControls()

    //clear hotkey min|max when use axis
    foreach (arr in this.curItem.modifiersId)
      foreach (id in arr)
        this.shortcuts[id] = []

    if ("onAxisDone" in this.curItem)
      this.curItem.onAxisDone.call(this, !this.axisTypeButtons, false)

    this.axisApplyParams = null
    this.selectedAxisNum = -1
    this.nextItem()
  }

  function onAxisApply() {
    let curBinding = this.findAxis(this.selectedAxisNum)
    if (curBinding.len() == 0) {
      this.bindAxis()
      return false
    }

    local actionText = ""
    foreach (binding in curBinding)
      actionText += ((actionText == "") ? "" : ", ") + loc(this.getItemName(binding))
    let msg = loc("hotkeys/msg/unbind_axis_question", {
      button = this.curBtnText, action = actionText
    })
    this.msgBox("controls_wizard_bind_existing_axis", msg, [
      ["add", function() { this.bindAxis() }],
      ["replace", function() {
        this.repeatItemsList.extend(curBinding)
        this.bindAxis()
      }],
      ["cancel", function() { this.askAxis() }],
      ["skip", function() { this.onCancelButtonInput(null) }],
    ], "add")
  }

  function findAxis(curAxisId) {
    let res = []
    for (local i = 0; i <= this.curIdx; i++) {
      let item = this.controls_wizard_config[i]
      if (item.type != CONTROL_TYPE.AXIS || item == this.curItem)
        continue

      let axis = this.curJoyParams.getAxis(item.axisIndex[0])
      if (curAxisId == axis.axisId && !isInArray(item, this.repeatItemsList) && !isInArray(item, res))
        res.append(item)
    }
    return res
  }

  function updateAxisName() {
    let obj = this.scene.findObject("bind-axis-name")
    if (!checkObj(obj))
      return

    obj.show(this.isAxisListenInCurBox)

    let device = joystick_get_default()
    let curPreset = ::g_controls_manager.getCurPreset()
    let axisName = device ? ::remapAxisName(curPreset, this.bindAxisNum) : ""
    obj.setValue(axisName)

    let changeColor = (this.selectedAxisNum >= 0 && this.selectedAxisNum == this.bindAxisNum) ? "fixedAxis" : ""
    obj.changeColor = changeColor
  }

  function getCurAxisNum(dt, checkLastTryAxis = true) {
    let device = joystick_get_default()
    local foundAxis = -1
    let curPreset = ::g_controls_manager.getCurPreset()
    let numAxes = curPreset.getNumAxes()
    if (numAxes > this.presetupAxisRawValues.len())
      this.initAxisPresetup(false) //add new founded axes

    local deviation = 12000 //foundedAxis deviation, cant be lower than a initial value
    for (local i = 0; i < numAxes; i++) {
      let rawPos = device.getAxisPosRaw(i)
      if (rawPos != 0 && !this.presetupAxisRawValues[i].inited) {
        //Some joysticks return zero at first and only then init the current value
        this.presetupAxisRawValues[i].inited = true
        this.presetupAxisRawValues[i].def = rawPos
        this.presetupAxisRawValues[i].min = rawPos
        this.presetupAxisRawValues[i].max = rawPos
      }
      else {
        if (rawPos > this.presetupAxisRawValues[i].max)
          this.presetupAxisRawValues[i].max = rawPos
        if (rawPos < this.presetupAxisRawValues[i].min)
          this.presetupAxisRawValues[i].min = rawPos
      }

      let dPos = fabs(rawPos - this.presetupAxisRawValues[i].def)
      if (dPos > deviation) {
        foundAxis = i
        deviation = dPos

        if (fabs(rawPos - this.presetupAxisRawValues[i].last) < 1000) {  //check stucked axes
          this.presetupAxisRawValues[i].stuckTime += dt
          if (this.presetupAxisRawValues[i].stuckTime > 3.0)
            this.presetupAxisRawValues[i].def = rawPos //change cur value to def becoase of stucked
        }
        else {
          this.presetupAxisRawValues[i].last = rawPos
          this.presetupAxisRawValues[i].stuckTime = 0.0
        }
      }
    }

    if (checkLastTryAxis)
      if (foundAxis >= 0) {
        if (this.lastTryAxisNum != foundAxis) {
          this.lastTryAxisNum = foundAxis
          this.lastTryTime += dt
        }
      }
      else if (this.lastTryAxisNum >= 0)
          if (this.lastTryTime > 1.0 ||
              (this.presetupAxisRawValues[this.lastTryAxisNum].max - this.presetupAxisRawValues[this.lastTryAxisNum].min) >= 16000)
            foundAxis = this.lastTryAxisNum

    return foundAxis
  }

  function onAxisInputTimer(_obj, dt) {
    if (!this.isListenAxis || !::is_app_active() || steam_is_overlay_active())
      return

    let device = joystick_get_default()
    if (device == null)
      return

    let foundAxis = this.getCurAxisNum(dt)
    if (this.selectedAxisNum < 0) {
      if (foundAxis != this.bindAxisNum) {
        this.bindAxisNum = foundAxis
//        if (selectedAxisNum>=0 && bindAxisNum<0)
//          bindAxisNum = selectedAxisNum
//        else
          this.axisCurTime = 0.0
      }
    }

    if (this.lastBindAxisNum != this.bindAxisNum) {
      this.lastBindAxisNum = this.bindAxisNum
      this.updateAxisName()
      if (is_axis_digital(this.bindAxisNum))
        this.setAxisType(false)
    }

    if (this.bindAxisNum < 0) {
      this.bindAxisCurVal = 0
      this.moveTestItem(0)
      return
    }

    this.axisCurTime += dt

    let val = device.getAxisPosRaw(this.bindAxisNum)
    local checkTime = true
    if (val != this.bindAxisCurVal) {
      this.bindAxisCurVal = val
      this.moveTestItem(this.bindAxisCurVal)
      this.axisCurTime = 0.0
      if (fabs(val - this.bindAxisCurVal) > 1000)
        checkTime = false
    }

    if (checkTime)
      if ((this.axisCurTime >= this.axisFixTime && fabs(val) > 3000) || this.axisCurTime >= 2.0 * this.axisFixTime)  //double wait time near zero
        if (this.selectedAxisNum != this.bindAxisNum) {
          this.selectedAxisNum = this.bindAxisNum
          this.bindAxisFixVal = this.bindAxisCurVal
          this.setAxisType(false)
          this.scene.findObject("input-listener").select()

          this.updateAxisPressKey()
          this.updateAxisName()
          this.updateButtons()
        }
        else if (fabs(val - this.bindAxisFixVal) > 12000)
          this.onAxisSelected()
  }

  function onResetAxisInput() {
    if (this.curItem.type != CONTROL_TYPE.AXIS)
      return
    this.selectedAxisNum = -1
    this.axisMaxChoosen = false
    showObjById("btn-reset-axis-input", false, this.scene)
    this.initAxisPresetup()
    this.askAxis()
  }

  function moveTestItem(value, obj = null) {
    if (!obj)
      obj = this.scene.findObject(this.isAxisVertical ? "test-real-box-vert" : "test-real-box")
    if ("showInverted" in this.curItem && this.curItem.showInverted())
      value = -value

    if (this.isAxisVertical)
      obj.pos = "0.5pw-0.5w, " + format("%.3f(ph - h)", ((32000 - value).tofloat() / 64000))
    else
      obj.pos = format("%.3f(pw - w)", ((value + 32000).tofloat() / 64000)) + ", 0.5ph- 0.5h"
  }

  function initAxisPresetup(fullInit = true) {
    if (fullInit) {
      this.presetupAxisRawValues = []
      this.lastTryAxisNum = -1
    }
    let device = joystick_get_default()
    if (device == null)
      return

    let curPreset = ::g_controls_manager.getCurPreset()
    let start = this.presetupAxisRawValues.len()
    for (local i = start; i < curPreset.getNumAxes(); i++) {
      let rawPos = device.getAxisPosRaw(i)
      this.presetupAxisRawValues.append({
                                     def = rawPos,
                                     min = rawPos,
                                     max = rawPos,
                                     last = rawPos,
                                     stuckTime = 0.0,
                                     inited = is_axis_digital(i) || rawPos != 0
                                  })
    }
  }

  function showMsgBox(isListbox = false) {
    let msgText = this.getItemText(this.curItem)
    local defValue = 0
    this.msgButtons = []

    if ("optionType" in this.curItem) {
      let config = ::get_option(this.curItem.optionType)
      this.msgButtons = config.items
      defValue = config.value
    }
    else if ("options" in this.curItem) {
      this.msgButtons = this.curItem.options
      defValue = ("defValue" in this.curItem) ? this.curItem.defValue : 0
    }

    if (this.msgButtons.len() == 0)
      this.msgButtons.append("msgbox/btn_ok")

    if (!isListbox) {
      this.scene.findObject("msgBox_text").setValue(loc(msgText))
      local data = ""
      foreach (idx, btn in this.msgButtons) {
        let text = (btn.len() > 0 && btn.slice(0, 1) != "#") ? "#" + btn : btn
        data += format("Button_text { id:t='%d'; text:t='%s'; on_click:t='onMsgButton'; }",
                  idx, text)
      }
      let btnsHolder = this.scene.findObject("msgBox_buttons")
      this.guiScene.replaceContentFromText(btnsHolder, data, data.len(), this)
      move_mouse_on_obj(btnsHolder.findObject(defValue.tostring()))
    }
    else {
      this.scene.findObject("listbox_text").setValue(loc(msgText))

      let view = { items = [] }
      foreach (idx, btn in this.msgButtons) {
        local text = getTblValue("text", btn, "")
        if (u.isString(btn))
          text = btn

        if (this.getStrSymbol(text, 0) != "#")
          text = "#" + text

        view.items.append({
          id = idx.tostring()
          text = text
          tooltip = text + "/tooltip"
        })
      }

      let data = handyman.renderCached("%gui/commonParts/shopFilter.tpl", view)
      let listObj = this.scene.findObject("listbox")
      this.guiScene.replaceContentFromText(listObj, data, data.len(), this)
      if (defValue in this.msgButtons)
        listObj.setValue(defValue)
      move_mouse_on_child(listObj, listObj.getValue())
      this.onListboxSelect(null)
    }

    this.waitMsgButton = true
  }

  function getStrSymbol(str, i) {
    if (i < str.len())
      return str.slice(i, i + 1)
    return null
  }

  function onMsgButton(obj) {
    let value = obj.id.tointeger()
    if (value == null || !(value in this.msgButtons) || !this.waitMsgButton)
      return

    this.waitMsgButton = false
    this.guiScene.performDelayed(this, function() {
      if ("optionType" in this.curItem) {
        this.optionsToSave.append({ type = this.curItem.optionType, value = value })
        if ("isFilterObj" in this.curItem && this.curItem.isFilterObj) {
          let config = ::get_option(this.curItem.optionType)
          this.filter = config.values[value]
        }
      }
      if (("skipAllBefore" in this.curItem) && (value in this.curItem.skipAllBefore))
        this.skipAllBefore = this.curItem.skipAllBefore[value]
      if (("skip" in this.curItem) && (value in this.curItem.skip) && this.curItem.skip[value])
        if (type(this.curItem.skip[value]) == "array")
          this.skipList.extend(this.curItem.skip[value])
        else
          this.skipList.append(this.curItem.skip[value])
      if ("onButton" in this.curItem)
        this.curItem.onButton.call(this, value)
      this.nextItem()
    })
  }

  function getCurListboxObj() {
    let listObj = this.scene.findObject("listbox")
    let value = listObj.getValue()
    if (value >= 0 && value < listObj.childrenCount())
      return listObj.getChild(value)
    return null
  }

  function onListboxDblClick(_obj) {
    let curObj = this.getCurListboxObj()
    if (curObj)
      this.onMsgButton(curObj)
  }

  function onListboxSelect(_obj) {
    let curObj = this.getCurListboxObj()
    if (!curObj)
      return
    this.scene.findObject("listbox-hint").setValue(curObj.tooltip)
  }

  function askPresetsWnd() {
    this.curIdx = -1
    showObjById("nav-help", false, this.scene)
    this.switchToDiv("options-wnd")
    let optObj = this.scene.findObject("optionlist")
    if (!checkObj(optObj))
      return

    showObjById("btn_prevItem", false, this.scene)

    let optionItems = [
      [USEROPT_CONTROLS_PRESET, "spinner"],
    ]
    let container = create_options_container("preset_options", optionItems, false, 0.5, true, null, false)
    this.guiScene.replaceContentFromText(optObj, container.tbl, container.tbl.len(), this)
    this.processPresetValue(this.getOptionPresetValue())
    move_mouse_on_obj(this.scene.findObject("controls_preset"))
  }

  function getOptionPresetValue() {
    return ::get_option(USEROPT_CONTROLS_PRESET).value
  }

  function onSelectPreset(obj) {
    this.processPresetValue(obj.getValue())
  }

  function processPresetValue(presetValue) {
    let opdata = ::get_option(USEROPT_CONTROLS_PRESET)
    if (presetValue in opdata.values) {
      this.presetSelected = opdata.values[presetValue]
      showObjById("btn_controlsWizard", this.presetSelected == "", this.scene)
      showObjById("btn_selectPreset", this.presetSelected != "", this.scene)

      if (this.presetSelected == "") {
        ::g_controls_manager.clearPreviewPreset()
        this.previewHandler.showPreview()
        return
      }

      let presetPath = ($"{controlsPresetConfigPath.value}config/hotkeys/hotkey.{this.presetSelected}.blk")
      let previewPreset = ::ControlsPreset(presetPath)
      let currentPreset = ::g_controls_manager.getCurPreset()

      if (previewPreset.basePresetPaths?["default"] == currentPreset.basePresetPaths?["default"])
        ::g_controls_manager.setPreviewPreset(currentPreset)
      else
        ::g_controls_manager.setPreviewPreset(previewPreset)

      this.previewHandler.showPreview()
    }
  }

  function onPresetDone(_obj) {
    this.applyPreset(::applySelectedPreset(this.presetSelected))
  }

  function applyPreset(preset) {
    ::apply_joy_preset_xchange(preset)
    this.isPresetAlreadyApplied = true
    this.goBack()
  }

  function startManualSetup() {
    showObjById("nav-help", true, this.scene)
    scene_msg_box("ask_unit_type", null, loc("mainmenu/askWizardForUnitType"),
      [
        [ "aviation", (@() this.startManualSetupForUnitType(ES_UNIT_TYPE_AIRCRAFT)).bindenv(this) ],
        [ "army", (@() this.startManualSetupForUnitType(ES_UNIT_TYPE_TANK)).bindenv(this) ]
      ], "aviation")
  }

  function startManualSetupForUnitType(esUnitType) {
    if (esUnitType == ES_UNIT_TYPE_TANK)
      this.controls_wizard_config = ::tank_controls_wizard_config
    else if (esUnitType == ES_UNIT_TYPE_AIRCRAFT)
      this.controls_wizard_config = ::aircraft_controls_wizard_config
    else
      script_net_assert_once("unsupported unit type", "Given unit type has not wizard config")

    ::initControlsWizardConfig(this.controls_wizard_config)
    this.initShortcutsNames()
    this.shortcuts = ::get_shortcuts(this.shortcutNames)

    this.curIdx = -1
    this.nextItem()
  }

  function onContinue(_obj) {
    if (this.curIdx == -1 || !this.controls_wizard_config) {
      this.startManualSetup()
    }
    else {
      this.nextItem()
    }
  }

  function doApply() {
    foreach (option in this.optionsToSave)
      set_option(option.type, option.value)
    joystickSetCurSettings(this.curJoyParams)
    setShortcutsAndSaveControls(this.shortcuts, this.shortcutNames)
    this.save(false)
  }

  function goBack() {
    if (this.curIdx > 0 && !this.isPresetAlreadyApplied)
      this.msgBox("ask_save", loc("hotkeys/msg/wizardSaveUnfinished"),
        [
          ["yes", function() { this.doApply() } ],
          ["no", function() { gui_handlers.BaseGuiHandlerWT.goBack.bindenv(this)() }],
          ["cancel", @() null ],
        ], "yes", { cancel_fn = function() {} })
    else
      gui_handlers.BaseGuiHandlerWT.goBack.bindenv(this)()
  }

  function afterSave() {
    gui_handlers.BaseGuiHandlerWT.goBack.bindenv(this)()
  }

  function onEventActiveHandlersChanged(_p) {
    this.enableListenerObj(this.curDivName == "shortcut-wnd" && this.isSceneActiveNoModals())
  }

  function afterModalDestroy() {
    this.guiScene.sleepKeyRepeat(false)
    set_bind_mode(false)
    ::preset_changed = true
    ::g_controls_manager.clearPreviewPreset()
    broadcastEvent("ControlsPresetChanged")
  }

  function showMsg(msg = null, config = null, time = 1.0) {
    this.switchToDiv("msg-wnd")
    if (msg == null)
      msg = loc("mainmenu/btnOk")
    this.scene.findObject("msg_text").setValue(msg)
    this.msgTimer = time + this.waitAxisAddTime

    local showAxis = false
    if (config && ("min" in config) && ("max" in config)) {
      let name = this.isAxisVertical ? "msg-real-box-vert" : "msg-real-box"
      this.moveTestItem(config.min, this.scene.findObject(name + "1"))
      this.moveTestItem(config.max, this.scene.findObject(name + "2"))
      showAxis = true
    }
    this.scene.findObject("msg-axis").show(showAxis && !this.isAxisVertical)
    this.scene.findObject("msg-axis-vert").show(showAxis && this.isAxisVertical)
  }

  function onUpdate(_obj, dt) {
    if (this.msgTimer > 0) {
      this.msgTimer -= dt
      if (this.msgTimer <= 0)
        this.afterMsg()
      else if (this.msgTimer <= this.waitAxisAddTime)
        if (this.getCurAxisNum(dt, false) < 0) {
          this.msgTimer = 0
          this.afterMsg()
        }
    }
  }

  function afterMsg() {
    if (this.axisApplyParams)
      this.onAxisApply()
    else
      this.nextItem()
  }
}
