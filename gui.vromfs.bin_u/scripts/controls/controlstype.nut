from "%scripts/dagui_natives.nut" import save_profile, set_control_helpers_mode
from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import SEEN

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { hasXInputDevice } = require("controls")
let globalEnv = require("globalEnv")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let avatars = require("%scripts/user/avatars.nut")
let { isPlatformSony, isPlatformXboxOne, isPlatformSteamDeck, isPlatformShieldTv
} = require("%scripts/clientState/platform.nut")
let { setGuiOptionsMode, getGuiOptionsMode } = require("guiOptions")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { set_option } = require("%scripts/options/optionsExt.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_PILOT, USEROPT_HELPERS_MODE, USEROPT_CONTROLS_PRESET
} = require("%scripts/options/optionsExtNames.nut")
let { getProfileInfo } = require("%scripts/user/userInfoStats.nut")

gui_handlers.ControlType <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/controlTypeChoice.blk"

  controlsOptionsMode = 0
  onlyDevicesChoice = true
  startControlsWizard = false

  function initScreen() {
    this.mainOptionsMode = getGuiOptionsMode()
    setGuiOptionsMode(OPTIONS_MODE_GAMEPLAY)

    let txt = this.scene.findObject("txt_icon")
    txt.show(!this.onlyDevicesChoice)
    showObjById("btn_pref_img", !this.onlyDevicesChoice)
    showObjById("btn_back", this.onlyDevicesChoice)
    showObjById("btn_cancel", this.onlyDevicesChoice)

    if (!this.onlyDevicesChoice)
      this.updateProfileIcon(true)

    showObjById("ct_xinput", hasXInputDevice(), this.scene)
  }

  function onChangePilotIcon() {
    avatars.openChangePilotIconWnd(this.onIconChoosen, this)
  }

  function onIconChoosen(option) {
    set_option(USEROPT_PILOT, option.idx)
    save_profile(false)
    this.updateProfileIcon()
  }

  function updateProfileIcon(isOnInit = false) {
    if (!checkObj(this.scene))
      return

    let obj = this.scene.findObject("prefIcon")
    if (checkObj(obj)) {
      obj.setValue(getProfileInfo().icon)
      if (isOnInit)
        this.scene.findObject("unseen_avatar").setValue(SEEN.AVATARS)
    }
  }

  function afterModalDestroy() {
    this.restoreMainOptions()
    if (this.startControlsWizard)
      ::gui_modal_controlsWizard()
    ::preset_changed = true
    broadcastEvent("ControlsPresetChanged")
  }

  function onControlTypeApply() {
    local ct_id = "ct_mouse"
    let obj = this.scene.findObject("controlType")
    if (checkObj(obj)) {
      let value = obj.getValue()
      if (value >= 0 && value < obj.childrenCount())
        ct_id = obj.getChild(value).id
    }

    if (ct_id == "ct_own" || !this.onlyDevicesChoice) {
      this.doControlTypeApply(ct_id)
      return
    }

    let text = loc("msgbox/controlPresetApply")
    let onOk = Callback(@() this.doControlTypeApply(ct_id), this)
    this.msgBox("controlPresetApply", text, [["yes", onOk], ["no"]], "yes")
  }

  function doControlTypeApply(ctId) {
    ::setControlTypeByID(ctId)
    this.startControlsWizard = ctId == "ct_own"
    this.goBack()
  }

  function onControlTypeDblClick() {
    this.onControlTypeApply()
  }
}

::set_helpers_mode_and_option <- function set_helpers_mode_and_option(mode) { //setGuiOptionsMode required
  set_option(USEROPT_HELPERS_MODE, mode) //for next loadDifficulty()
  set_control_helpers_mode(mode); //instant
}

::setControlTypeByID <- function setControlTypeByID(ct_id) {
  let mainOptionsMode = getGuiOptionsMode()
  setGuiOptionsMode(OPTIONS_MODE_GAMEPLAY)

  local ct_preset = ""
  if (ct_id == "ct_own") {
    // This case is only for gui_handlers.ControlType, it starts ControlsWizard scene after that.
    ct_preset = "keyboard"
    ::set_helpers_mode_and_option(globalEnv.EM_INSTRUCTOR)
    save_profile(false)
    return
  }
  else if (ct_id == "ct_xinput") {
    ct_preset = "pc_xinput_ma"
    if (is_platform_android || isPlatformShieldTv())
      ct_preset = "tegra4_gamepad"
    ::set_helpers_mode_and_option(globalEnv.EM_INSTRUCTOR)
  }
  else if (ct_id == "ct_mouse") {
    ct_preset = ""
    if (is_platform_android)
      ct_preset = "tegra4_gamepad";
    ::set_helpers_mode_and_option(globalEnv.EM_MOUSE_AIM)
  }

  local preset = null

  if (ct_preset != "")
    preset = ::g_controls_presets.parsePresetName(ct_preset)
  else if (ct_id == "ct_mouse") {
    if (isPlatformSony)
      preset = ::g_controls_presets.parsePresetName("dualshock4")
    else if (is_platform_xbox)
      preset = ::g_controls_presets.parsePresetName("xboxone_ma")
    else if (isPlatformSteamDeck)
      preset = ::g_controls_presets.parsePresetName("steamdeck_ma")
    else
      preset = ::g_controls_presets.parsePresetName("keyboard_shooter")
  }
  preset = ::g_controls_presets.getHighestVersionPreset(preset)
  ::apply_joy_preset_xchange(preset.fileName)

  if (isPlatformSony || isPlatformXboxOne || isPlatformSteamDeck) {
    let presetMode = ::get_option(USEROPT_CONTROLS_PRESET)
    ct_preset = ::g_controls_presets.parsePresetName(presetMode.values[presetMode.value])
    //TODO: is it obsolete?
    local realisticPresetNames = ["default", "xboxone_simulator", "stimdeck_simulator"]
    local mouseAimPresetNames = ["dualshock4", "xboxone_ma", "stimdeck_ma"]
    if (ct_preset.name in realisticPresetNames)
      ::set_helpers_mode_and_option(globalEnv.EM_REALISTIC)
    else if (ct_preset.name in mouseAimPresetNames)
      ::set_helpers_mode_and_option(globalEnv.EM_MOUSE_AIM)
  }

  save_profile(false)

  setGuiOptionsMode(mainOptionsMode)
}
