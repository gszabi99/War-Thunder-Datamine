let { setBreadcrumbGoBackParams } = require("%scripts/breadcrumb.nut")

::gui_start_controls_console <- function gui_start_controls_console()
{
  if (!::has_feature("ControlsAdvancedSettings"))
    return

  ::gui_start_modal_wnd(::gui_handlers.ControlsConsole)
}

::gui_handlers.ControlsConsole <- class extends ::gui_handlers.GenericOptionsModal
{
  wndType = handlerType.BASE
  sceneBlkName = "%gui/controlsConsole.blk"
  sceneNavBlkName = null

  changeControlsMode = false
  options = null
  lastHeadtrackActive = false

  function initScreen()
  {
    setBreadcrumbGoBackParams(this)
    options = [
      [::USEROPT_INVERTY, "spinner"],
      [::USEROPT_INVERTY_TANK, "spinner", ::has_feature("Tanks")],
      [::USEROPT_INVERTCAMERAY, "spinner"],
      [::USEROPT_MOUSE_AIM_SENSE, "slider"],
      [::USEROPT_ZOOM_SENSE,"slider"],
      [::USEROPT_GUNNER_INVERTY, "spinner"],
      [::USEROPT_GUNNER_VIEW_SENSE, "slider"],
      [::USEROPT_HEADTRACK_ENABLE, "spinner", ::ps4_headtrack_is_attached()],
      [::USEROPT_HEADTRACK_SCALE_X, "slider", ::ps4_headtrack_is_attached()],
      [::USEROPT_HEADTRACK_SCALE_Y, "slider", ::ps4_headtrack_is_attached()]
    ]

    let guiScene = ::get_gui_scene()
    let container = create_options_container("controls", options, true)
    guiScene.replaceContentFromText("optionslist", container.tbl, container.tbl.len(), this)
    optionsContainers = [container.descr]

    checkHeadtrackRows()
    updateButtons()

    lastHeadtrackActive = ::ps4_headtrack_is_active()
    scene.findObject("controls_update").setUserData(this)
  }

  function onControlsWizard()
  {
    ::gui_modal_controlsWizard()
  }

  function onControlsHelp()
  {
    applyFunc = function() {
      ::gui_modal_help(false, HELP_CONTENT_SET.CONTROLS)
      applyFunc = null
    }
    applyOptions()
  }

  function onHeadtrackEnableChange(obj)
  {
    let option = get_option_by_id(obj?.id)
    if (!option) return

    ::set_option(option.type, obj.getValue(), option)
    checkHeadtrackRows()
  }

  function checkHeadtrackRows()
  {
    let show = ::ps4_headtrack_is_attached() && ::ps4_headtrack_get_enable()
    foreach(o in [::USEROPT_HEADTRACK_SCALE_X, ::USEROPT_HEADTRACK_SCALE_Y])
      showOptionRow(get_option(o), show)
    this.showSceneBtn("btn_calibrate", show)
  }

  function onSwitchModeButton()
  {
    changeControlsMode = true
    backSceneFunc = ::gui_start_advanced_controls
    ::switchControlsMode(false)
    goBack()
  }

  function updateButtons()
  {
    this.showSceneBtn("btn_switchMode", true)
    this.showSceneBtn("btn_controlsWizard", ::has_feature("ControlsPresets") && ::get_game_mode() != ::GM_TRAINING && !::is_platform_xbox)
    this.showSceneBtn("btn_controlsHelp", ::has_feature("ControlsHelp"))
    let btnObj = scene.findObject("btn_calibrate")
    if (::checkObj(btnObj))
      btnObj.inactiveColor = ::ps4_headtrack_is_active()? "no" : "yes"
  }

  function onUpdate(obj, dt)
  {
    if (lastHeadtrackActive == ::ps4_headtrack_is_active())
      return

    lastHeadtrackActive = ::ps4_headtrack_is_active()
    updateButtons()
  }

  function onCalibrate()
  {
    if (!::ps4_headtrack_is_attached())
      return

    if (!::ps4_headtrack_is_active())
    {
      this.msgBox("not_available", ::loc("options/headtrack_camera_not_work"), [["ok", function() {} ]], "ok", { cancel_fn = function() {}})
      return
    }

    this.msgBox("calibrate", ::loc("msg/headtrack_calibrate"),
      [["ok", function() { ::ps4_headtrack_calibrate() } ]],
      "ok", { cancel_fn = function() {}})
  }
}
