from "%scripts/dagui_natives.nut" import ps4_headtrack_get_enable, ps4_headtrack_calibrate, ps4_headtrack_is_attached, ps4_headtrack_is_active
from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import HELP_CONTENT_SET

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { setBreadcrumbGoBackParams } = require("%scripts/breadcrumb.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { get_game_mode } = require("mission")
let { set_option, create_options_container, get_option } = require("%scripts/options/optionsExt.nut")
let { USEROPT_INVERTY, USEROPT_INVERTY_TANK, USEROPT_INVERTCAMERAY,
  USEROPT_MOUSE_AIM_SENSE, USEROPT_ZOOM_SENSE, USEROPT_GUNNER_INVERTY,
  USEROPT_GUNNER_VIEW_SENSE, USEROPT_HEADTRACK_ENABLE, USEROPT_HEADTRACK_SCALE_X,
  USEROPT_HEADTRACK_SCALE_Y
} = require("%scripts/options/optionsExtNames.nut")
let { switchControlsMode } = require("%scripts/controls/startControls.nut")
let { gui_modal_help } = require("%scripts/help/helpWnd.nut")
let { gui_modal_controlsWizard } = require("%scripts/controls/controlsWizard.nut")

gui_handlers.ControlsConsole <- class (gui_handlers.GenericOptionsModal) {
  wndType = handlerType.BASE
  sceneBlkName = "%gui/controlsConsole.blk"
  sceneNavBlkName = null

  changeControlsMode = false
  options = null
  lastHeadtrackActive = false

  function initScreen() {
    setBreadcrumbGoBackParams(this)
    this.options = [
      [USEROPT_INVERTY, "spinner"],
      [USEROPT_INVERTY_TANK, "spinner"],
      [USEROPT_INVERTCAMERAY, "spinner"],
      [USEROPT_MOUSE_AIM_SENSE, "slider"],
      [USEROPT_ZOOM_SENSE, "slider"],
      [USEROPT_GUNNER_INVERTY, "spinner"],
      [USEROPT_GUNNER_VIEW_SENSE, "slider"],
      [USEROPT_HEADTRACK_ENABLE, "spinner", ps4_headtrack_is_attached()],
      [USEROPT_HEADTRACK_SCALE_X, "slider", ps4_headtrack_is_attached()],
      [USEROPT_HEADTRACK_SCALE_Y, "slider", ps4_headtrack_is_attached()]
    ]

    let guiScene = get_gui_scene()
    let container = create_options_container("controls", this.options, true)
    guiScene.replaceContentFromText(this.scene.findObject("optionslist"), container.tbl, container.tbl.len(), this)
    this.optionsContainers = [container.descr]

    this.checkHeadtrackRows()
    this.updateButtons()

    this.lastHeadtrackActive = ps4_headtrack_is_active()
    this.scene.findObject("controls_update").setUserData(this)
  }

  function onControlsWizard() {
    gui_modal_controlsWizard()
  }

  function onControlsHelp() {
    this.applyFunc = function() {
      gui_modal_help(false, HELP_CONTENT_SET.CONTROLS)
      this.applyFunc = null
    }
    this.applyOptions()
  }

  function onHeadtrackEnableChange(obj) {
    let option = this.get_option_by_id(obj?.id)
    if (!option)
      return

    set_option(option.type, obj.getValue(), option)
    this.checkHeadtrackRows()
  }

  function checkHeadtrackRows() {
    let show = ps4_headtrack_is_attached() && ps4_headtrack_get_enable()
    foreach (o in [USEROPT_HEADTRACK_SCALE_X, USEROPT_HEADTRACK_SCALE_Y])
      this.showOptionRow(get_option(o), show)
    showObjById("btn_calibrate", show, this.scene)
  }

  function onSwitchModeButton() {
    this.changeControlsMode = true
    this.backSceneParams = { eventbusName = "gui_start_advanced_controls" }
    switchControlsMode(false)
    this.goBack()
  }

  function updateButtons() {
    showObjById("btn_switchMode", true, this.scene)
    showObjById("btn_controlsWizard", hasFeature("ControlsPresets") && get_game_mode() != GM_TRAINING && !is_platform_xbox, this.scene)
    showObjById("btn_controlsHelp", hasFeature("ControlsHelp"), this.scene)
    let btnObj = this.scene.findObject("btn_calibrate")
    if (checkObj(btnObj))
      btnObj.inactiveColor = ps4_headtrack_is_active() ? "no" : "yes"
  }

  function onUpdate(_obj, _dt) {
    if (this.lastHeadtrackActive == ps4_headtrack_is_active())
      return

    this.lastHeadtrackActive = ps4_headtrack_is_active()
    this.updateButtons()
  }

  function onCalibrate() {
    if (!ps4_headtrack_is_attached())
      return

    if (!ps4_headtrack_is_active()) {
      this.msgBox("not_available", loc("options/headtrack_camera_not_work"), [["ok", function() {} ]], "ok", { cancel_fn = function() {} })
      return
    }

    this.msgBox("calibrate", loc("msg/headtrack_calibrate"),
      [["ok", function() { ps4_headtrack_calibrate() } ]],
      "ok", { cancel_fn = function() {} })
  }
}
