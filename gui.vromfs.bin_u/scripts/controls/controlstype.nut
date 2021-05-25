local globalEnv = require("globalEnv")
local avatars = require("scripts/user/avatars.nut")
local { isPlatformSony, isPlatformXboxOne } = require("scripts/clientState/platform.nut")

::gui_start_controls_type_choice <- function gui_start_controls_type_choice(onlyDevicesChoice = true)
{
  ::gui_start_modal_wnd(::gui_handlers.ControlType, {onlyDevicesChoice = onlyDevicesChoice})
}

class ::gui_handlers.ControlType extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/controlTypeChoice.blk"

  controlsOptionsMode = 0
  onlyDevicesChoice = true
  startControlsWizard = false

  function initScreen()
  {
    mainOptionsMode = ::get_gui_options_mode()
    ::set_gui_options_mode(::OPTIONS_MODE_GAMEPLAY)

    local txt = scene.findObject("txt_icon")
    txt.show(!onlyDevicesChoice)
    showBtn("btn_pref_img", !onlyDevicesChoice)
    showBtn("btn_back", onlyDevicesChoice)

    if (!onlyDevicesChoice)
      updateProfileIcon(true)

    showSceneBtn("ct_xinput", ::have_xinput_device())
  }

  function onChangePilotIcon()
  {
    avatars.openChangePilotIconWnd(onIconChoosen, this)
  }

  function onIconChoosen(option)
  {
    ::set_option(::USEROPT_PILOT, option.idx)
    ::save_profile(false)
    updateProfileIcon()
  }

  function updateProfileIcon(isOnInit = false)
  {
    if (!::check_obj(scene))
      return

    local obj = scene.findObject("prefIcon")
    if (::check_obj(obj))
    {
      obj.setValue(::get_profile_info().icon)
      if (isOnInit)
        scene.findObject("unseen_avatar").setValue(SEEN.AVATARS)
    }
  }

  function onBack()
  {
    goBack()
  }

  function afterModalDestroy()
  {
    restoreMainOptions()
    if (startControlsWizard)
      ::gui_modal_controlsWizard()
    ::preset_changed = true
    ::broadcastEvent("ControlsPresetChanged")
  }

  function onControlTypeApply()
  {
    local ct_id = "ct_mouse"
    local obj = scene.findObject("controlType")
    if (::check_obj(obj))
    {
      local value = obj.getValue()
      if (value>=0 && value<obj.childrenCount())
        ct_id = obj.getChild(value).id
    }

    setControlTypeByID(ct_id)
    goBack()
  }
}

::set_helpers_mode_and_option <- function set_helpers_mode_and_option(mode) //set_gui_options_mode required
{
  ::set_option(::USEROPT_HELPERS_MODE, mode) //for next loadDifficulty()
  ::set_control_helpers_mode(mode); //instant
}

::setControlTypeByID <- function setControlTypeByID(ct_id)
{
  local mainOptionsMode = ::get_gui_options_mode()
  ::set_gui_options_mode(::OPTIONS_MODE_GAMEPLAY)

  local ct_preset = ""
  if (ct_id == "ct_own")
  {
    ct_preset = "keyboard"
    startControlsWizard = true
    set_helpers_mode_and_option(globalEnv.EM_INSTRUCTOR)
    ::save_profile(false)
    return
  }
  else if (ct_id == "ct_xinput")
  {
    ct_preset = "pc_xinput_ma"
    if (::is_platform_android || ::is_platform_shield_tv())
      ct_preset = "tegra4_gamepad"
    set_helpers_mode_and_option(globalEnv.EM_INSTRUCTOR)
  }
  else if (ct_id == "ct_mouse")
  {
    ct_preset = ""
    if (::is_platform_android)
      ct_preset = "tegra4_gamepad";
    set_helpers_mode_and_option(globalEnv.EM_MOUSE_AIM)
  }

  local preset = null

  if (ct_preset != "")
    preset = ::g_controls_presets.parsePresetName(ct_preset)
  else if (ct_id == "ct_mouse")
  {
    if (isPlatformSony)
      preset = ::g_controls_presets.parsePresetName("dualshock4")
    else if (::is_platform_xbox)
      preset = ::g_controls_presets.parsePresetName("xboxone_ma")
    else
      preset = ::g_controls_presets.parsePresetName("keyboard_shooter")
  }
  preset = ::g_controls_presets.getHighestVersionPreset(preset)
  ::apply_joy_preset_xchange(preset.fileName)

  if (isPlatformSony || isPlatformXboxOne)
  {
    local presetMode = ::get_option(::USEROPT_CONTROLS_PRESET)
    ct_preset = ::g_controls_presets.parsePresetName(presetMode.values[presetMode.value])
    //TODO: is it obsolete?
    if (ct_preset.name == "default" || ct_preset.name == "xboxone_simulator")
      set_helpers_mode_and_option(globalEnv.EM_REALISTIC)
    else if (ct_preset.name == "dualshock4" || ct_preset.name == "xboxone_ma")
      set_helpers_mode_and_option(globalEnv.EM_MOUSE_AIM)
  }

  ::save_profile(false)

  ::set_gui_options_mode(mainOptionsMode)
}
