from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
::g_script_reloader.loadOnce("%scripts/controls/controlsPreset.nut")
::g_script_reloader.loadOnce("%scripts/controls/controlsGlobals.nut")
::g_script_reloader.loadOnce("%scripts/controls/controlsCompatibility.nut")

let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { eachBlock } = require("%sqstd/datablock.nut")
local { setGuiOptionsMode, getGuiOptionsMode } = require_native("guiOptions")

::g_controls_manager <- {
  [PERSISTENT_DATA_PARAMS] = ["curPreset"]

  // PRIVATE VARIABLES
  curPreset = ::ControlsPreset()
  isControlsCommitPerformed = false

  fixesList = [
    {
      isAppend = true
      source = "ID_FLIGHTMENU"
      target = "ID_FLIGHTMENU_SETUP"
      value = [{
        deviceId = ::SHORTCUT.GAMEPAD_START.dev[0]
        buttonId = ::SHORTCUT.GAMEPAD_START.btn[0]
      }]
      shouldAppendIfEmptyOnXInput = true
    }
    {
      isAppend = true
      source = "ID_CONTINUE",
      target = "ID_CONTINUE_SETUP"
      value = [{
        deviceId = ::GAMEPAD_ENTER_SHORTCUT.dev[0]
        buttonId = ::GAMEPAD_ENTER_SHORTCUT.btn[0]
      }]
      shouldAppendIfEmptyOnXInput = true
    }
    {
      target = "ID_FLIGHTMENU"
      value = [[{
        deviceId = ::SHORTCUT.KEY_ESC.dev[0]
        buttonId = ::SHORTCUT.KEY_ESC.btn[0]
      }]]
    }
    {
      target = "ID_CONTINUE"
      valueFunction = function()
      {
        return [[::is_xinput_device() ? {
          deviceId = ::GAMEPAD_ENTER_SHORTCUT.dev[0]
          buttonId = ::GAMEPAD_ENTER_SHORTCUT.btn[0] // used in mission hints
        } :
        {
          deviceId = ::SHORTCUT.KEY_SPACE.dev[0]
          buttonId = ::SHORTCUT.KEY_SPACE.btn[0]
        }]]
      }
    }
  ]

  hardcodedShortcuts = [
    {
      condition = function() { return is_platform_pc }
      list = [
        {
          name = "ID_SCREENSHOT",
          combo = [{
            deviceId = ::SHORTCUT.KEY_PRNT_SCRN.dev[0]
            buttonId = ::SHORTCUT.KEY_PRNT_SCRN.btn[0]
          }]
        }
      ]
    }
  ]

  /****************************************************************/
  /*********************** PUBLIC FUNCTIONS ***********************/
  /****************************************************************/

  function getCurPreset()
  {
    return this.curPreset
  }

  function setCurPreset(otherPreset)
  {
    log("ControlsManager: curPreset updated")
    this.curPreset = otherPreset
    this.fixDeviceMapping()
    ::broadcastEvent("ControlsReloaded")
    this.commitControls()
  }

  function notifyPresetModified()
  {
    this.commitControls()
  }

  function fixDeviceMapping()
  {
    let realMapping = []

    let blkDeviceMapping = ::DataBlock()
    ::fill_joysticks_desc(blkDeviceMapping)

    eachBlock(blkDeviceMapping, @(blkJoy)
      realMapping.append({
        name          = blkJoy["name"]
        devId         = blkJoy["devId"]
        buttonsOffset = blkJoy["btnOfs"]
        buttonsCount  = blkJoy["btnCnt"]
        axesOffset    = blkJoy["axesOfs"]
        axesCount     = blkJoy["axesCnt"]
        connected     = !getTblValue("disconnected", blkJoy, false)
      }))

    if (this.getCurPreset().updateDeviceMapping(realMapping))
      ::broadcastEvent("ControlsPresetChanged")
  }


  /* Commit controls to game client */
  function commitControls(fixMappingIfRequired = true)
  {
    if (this.isControlsCommitPerformed)
      return
    this.isControlsCommitPerformed = true

    if (fixMappingIfRequired && isPlatformSony)
      this.fixDeviceMapping()
    this.fixControls()

    this.commitGuiOptions()

    // Check helpers options and fix if nessesary
    ::broadcastEvent("BeforeControlsCommit")

    // Send controls to C++ client
    ::set_current_controls(this.curPreset)

    this.clearGuiOptions()

    this.isControlsCommitPerformed = false
  }

  function setDefaultRelativeAxes()
  {
    if (!("shortcutsList" in getroottable()))
      return

    foreach (shortcut in ::shortcutsList)
      if (shortcut.type == CONTROL_TYPE.AXIS && (shortcut?.isAbsOnlyWhenRealAxis ?? false))
      {
        let axis = this.curPreset.getAxis(shortcut.id)
        if (axis.axisId == -1)
          axis.relative = true
      }
  }

  function fixControls()
  {
    foreach (fixData in this.fixesList)
    {
      let value = "valueFunction" in fixData ?
        fixData.valueFunction() : fixData.value
      if (getTblValue("isAppend", fixData))
      {
        let isGamepadExpected =  ::is_xinput_device() || ::have_xinput_device()
        if (this.curPreset.isHotkeyShortcutBinded(fixData.source, value)
            || (fixData.shouldAppendIfEmptyOnXInput
                && isGamepadExpected
                && this.curPreset.getHotkey(fixData.target).len() == 0))
          this.curPreset.addHotkeyShortcut(fixData.target, value)
      }
      else
        this.curPreset.setHotkey(fixData.target, value)
    }
    foreach (shortcutsGroup in this.hardcodedShortcuts)
      if (!("condition" in shortcutsGroup) || shortcutsGroup.condition())
        foreach (shortcut in shortcutsGroup.list)
          this.curPreset.removeHotkeyShortcut(shortcut.name, shortcut.combo)
    this.setDefaultRelativeAxes()
  }

  function restoreHardcodedKeys(maxShortcutCombinations)
  {
    foreach (shortcutsGroup in this.hardcodedShortcuts)
      if (!("condition" in shortcutsGroup) || shortcutsGroup.condition())
        foreach (shortcut in shortcutsGroup.list)
          if (this.curPreset.getHotkey(shortcut.name).len() < maxShortcutCombinations)
            this.curPreset.addHotkeyShortcut(shortcut.name, shortcut.combo)
  }

  function clearGuiOptions()
  {
    let prefix = "USEROPT_"
    let userOptTypes = []
    foreach (oType, _value in this.curPreset.params)
      if (::g_string.startsWith(oType, prefix))
        userOptTypes.append(oType)
    foreach (oType in userOptTypes)
      delete this.curPreset.params[oType]
  }

  function commitGuiOptions()
  {
    if (!::g_login.isProfileReceived())
      return

    let mainOptionsMode = getGuiOptionsMode()
    setGuiOptionsMode(::OPTIONS_MODE_GAMEPLAY)
    let prefix = "USEROPT_"
    foreach (oType, value in this.curPreset.params)
      if (::g_string.startsWith(oType, prefix))
        if (oType in getroottable())
          ::set_option(getroottable()[oType], value)
    setGuiOptionsMode(mainOptionsMode)
  }

  // While controls reloaded on PS4 from uncrorrect blk when mission started
  // it is required to commit controls when mission start.
  function onEventMissionStarted(_params)
  {
    if (isPlatformSony)
      this.commitControls()
  }
}

::subscribe_handler(::g_controls_manager)

::g_script_reloader.registerPersistentDataFromRoot("g_controls_manager")
