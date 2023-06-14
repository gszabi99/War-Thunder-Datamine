//checked for plus_string
from "%scripts/dagui_library.nut" import *


let { setBreadcrumbGoBackParams } = require("%scripts/breadcrumb.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { get_game_mode } = require("mission")

::gui_start_controls_console <- function gui_start_controls_console() {
  if (!hasFeature("ControlsAdvancedSettings"))
    return

  ::gui_start_modal_wnd(::gui_handlers.ControlsConsole)
}

::gui_handlers.ControlsConsole <- class extends ::gui_handlers.GenericOptionsModal {
  wndType = handlerType.BASE
  sceneBlkName = "%gui/controlsConsole.blk"
  sceneNavBlkName = null

  changeControlsMode = false
  options = null
  lastHeadtrackActive = false

  function initScreen() {
    setBreadcrumbGoBackParams(this)
    this.options = [
      [::USEROPT_INVERTY, "spinner"],
      [::USEROPT_INVERTY_TANK, "spinner"],
      [::USEROPT_INVERTCAMERAY, "spinner"],
      [::USEROPT_MOUSE_AIM_SENSE, "slider"],
      [::USEROPT_ZOOM_SENSE, "slider"],
      [::USEROPT_GUNNER_INVERTY, "spinner"],
      [::USEROPT_GUNNER_VIEW_SENSE, "slider"],
      [::USEROPT_HEADTRACK_ENABLE, "spinner", ::ps4_headtrack_is_attached()],
      [::USEROPT_HEADTRACK_SCALE_X, "slider", ::ps4_headtrack_is_attached()],
      [::USEROPT_HEADTRACK_SCALE_Y, "slider", ::ps4_headtrack_is_attached()]
    ]

    let guiScene = ::get_gui_scene()
    let container = ::create_options_container("controls", this.options, true)
    guiScene.replaceContentFromText(this.scene.findObject("optionslist"), container.tbl, container.tbl.len(), this)
    this.optionsContainers = [container.descr]

    this.checkHeadtrackRows()
    this.updateButtons()

    this.lastHeadtrackActive = ::ps4_headtrack_is_active()
    this.scene.findObject("controls_update").setUserData(this)
  }

  function onControlsWizard() {
    ::gui_modal_controlsWizard()
  }

  function onControlsHelp() {
    this.applyFunc = function() {
      ::gui_modal_help(false, HELP_CONTENT_SET.CONTROLS)
      this.applyFunc = null
    }
    this.applyOptions()
  }

  function onHeadtrackEnableChange(obj) {
    let option = this.get_option_by_id(obj?.id)
    if (!option)
      return

    ::set_option(option.type, obj.getValue(), option)
    this.checkHeadtrackRows()
  }

  function checkHeadtrackRows() {
    let show = ::ps4_headtrack_is_attached() && ::ps4_headtrack_get_enable()
    foreach (o in [::USEROPT_HEADTRACK_SCALE_X, ::USEROPT_HEADTRACK_SCALE_Y])
      this.showOptionRow(::get_option(o), show)
    this.showSceneBtn("btn_calibrate", show)
  }

  function onSwitchModeButton() {
    this.changeControlsMode = true
    this.backSceneFunc = ::gui_start_advanced_controls
    ::switchControlsMode(false)
    this.goBack()
  }

  function updateButtons() {
    this.showSceneBtn("btn_switchMode", true)
    this.showSceneBtn("btn_controlsWizard", hasFeature("ControlsPresets") && get_game_mode() != GM_TRAINING && !is_platform_xbox)
    this.showSceneBtn("btn_controlsHelp", hasFeature("ControlsHelp"))
    let btnObj = this.scene.findObject("btn_calibrate")
    if (checkObj(btnObj))
      btnObj.inactiveColor = ::ps4_headtrack_is_active() ? "no" : "yes"
  }

  function onUpdate(_obj, _dt) {
    if (this.lastHeadtrackActive == ::ps4_headtrack_is_active())
      return

    this.lastHeadtrackActive = ::ps4_headtrack_is_active()
    this.updateButtons()
  }

  function onCalibrate() {
    if (!::ps4_headtrack_is_attached())
      return

    if (!::ps4_headtrack_is_active()) {
      this.msgBox("not_available", loc("options/headtrack_camera_not_work"), [["ok", function() {} ]], "ok", { cancel_fn = function() {} })
      return
    }

    this.msgBox("calibrate", loc("msg/headtrack_calibrate"),
      [["ok", function() { ::ps4_headtrack_calibrate() } ]],
      "ok", { cancel_fn = function() {} })
  }
}
