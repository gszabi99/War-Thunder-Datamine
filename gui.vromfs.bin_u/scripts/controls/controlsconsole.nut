::gui_start_controls_console <- function gui_start_controls_console()
{
  ::gui_start_modal_wnd(::gui_handlers.ControlsConsole)
}

class ::gui_handlers.ControlsConsole extends ::gui_handlers.GenericOptionsModal
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/controlsConsole.blk"
  sceneNavBlkName = null

  changeControlsMode = false
  options = null
  lastHeadtrackActive = false

  function initScreen()
  {
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

    local guiScene = ::get_gui_scene()
    local container = create_options_container("controls", options, true, true)
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
    local option = get_option_by_id(obj?.id)
    if (!option) return

    ::set_option(option.type, obj.getValue(), option)
    checkHeadtrackRows()
  }

  function checkHeadtrackRows()
  {
    local show = ::ps4_headtrack_is_attached() && ::ps4_headtrack_get_enable()
    foreach(o in [::USEROPT_HEADTRACK_SCALE_X, ::USEROPT_HEADTRACK_SCALE_Y])
      showOptionRow(get_option(o), show)
    showSceneBtn("btn_calibrate", show)
  }

  function onSwitchModeButton()
  {
    changeControlsMode = true
    ::switchControlsMode(false)
    goBack()
  }

  function updateButtons()
  {
    showSceneBtn("btn_switchMode", true)
    showSceneBtn("btn_controlsWizard", ::get_game_mode() != ::GM_TRAINING && !::is_platform_xboxone)
    showSceneBtn("btn_controlsHelp", ::has_feature("ControlsHelp"))
    local btnObj = scene.findObject("btn_calibrate")
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
      msgBox("not_available", ::loc("options/headtrack_camera_not_work"), [["ok", function() {} ]], "ok", { cancel_fn = function() {}})
      return
    }

    msgBox("calibrate", ::loc("msg/headtrack_calibrate"),
      [["ok", function() { ::ps4_headtrack_calibrate() } ]],
      "ok", { cancel_fn = function() {}})
  }

  function afterModalDestroy()
  {
    if (changeControlsMode)
      ::gui_start_advanced_controls()
  }
}