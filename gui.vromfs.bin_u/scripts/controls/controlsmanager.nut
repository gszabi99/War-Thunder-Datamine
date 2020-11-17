::g_script_reloader.loadOnce("scripts/controls/controlsPreset.nut")
::g_script_reloader.loadOnce("scripts/controls/controlsGlobals.nut")
::g_script_reloader.loadOnce("scripts/controls/controlsCompatibility.nut")

local shortcutsAxisListModule = require("scripts/controls/shortcutsList/shortcutsAxis.nut")
local { isPlatformSony } = require("scripts/clientState/platform.nut")

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
      condition = function() { return ::is_platform_pc }
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
    return curPreset
  }

  function setCurPreset(otherPreset)
  {
    ::dagor.debug("ControlsManager: curPreset updated")
    curPreset = otherPreset
    fixDeviceMapping()
    ::broadcastEvent("ControlsReloaded")
    commitControls()
  }

  function notifyPresetModified()
  {
    commitControls()
  }

  function fixDeviceMapping()
  {
    local realMapping = []

    local blkDeviceMapping = ::DataBlock()
    ::fill_joysticks_desc(blkDeviceMapping)

    foreach (blkJoy in blkDeviceMapping)
      realMapping.append({
        name          = blkJoy["name"]
        devId         = blkJoy["devId"]
        buttonsOffset = blkJoy["btnOfs"]
        buttonsCount  = blkJoy["btnCnt"]
        axesOffset    = blkJoy["axesOfs"]
        axesCount     = blkJoy["axesCnt"]
        connected     = !::getTblValue("disconnected", blkJoy, false)
      })

    if (getCurPreset().updateDeviceMapping(realMapping))
      ::broadcastEvent("ControlsPresetChanged")
  }

  cachedShortcutGroupMap = null
  function getShortcutGroupMap()
  {
    if (!cachedShortcutGroupMap)
    {
      if (!("shortcutsList" in ::getroottable()))
        return {}

      local axisShortcutSuffixesList = []
      foreach (axisShortcut in shortcutsAxisListModule.types)
        if (axisShortcut.type == CONTROL_TYPE.AXIS_SHORTCUT)
          axisShortcutSuffixesList.append(axisShortcut.id)

      cachedShortcutGroupMap = {}
      foreach (shortcut in ::shortcutsList)
      {
        if (shortcut.type == CONTROL_TYPE.SHORTCUT || shortcut.type == CONTROL_TYPE.AXIS)
          cachedShortcutGroupMap[shortcut.id] <- shortcut.checkGroup
        if (shortcut.type == CONTROL_TYPE.AXIS)
          foreach (suffix in axisShortcutSuffixesList)
            cachedShortcutGroupMap[shortcut.id + "_" + suffix] <- shortcut.checkGroup
      }
    }
    return cachedShortcutGroupMap
  }

  /* Commit controls to game client */
  function commitControls(fixMappingIfRequired = true)
  {
    if (isControlsCommitPerformed)
      return
    isControlsCommitPerformed = true

    if (fixMappingIfRequired && isPlatformSony)
      fixDeviceMapping()
    fixControls()

    commitGuiOptions()

    // Check helpers options and fix if nessesary
    ::broadcastEvent("BeforeControlsCommit")

    // Send controls to C++ client
    ::set_current_controls(curPreset, ::g_controls_manager.getShortcutGroupMap())

    isControlsCommitPerformed = false
  }

  function setDefaultRelativeAxes()
  {
    if (!("shortcutsList" in ::getroottable()))
      return

    foreach (shortcut in ::shortcutsList)
      if (shortcut.type == CONTROL_TYPE.AXIS && (shortcut?.isAbsOnlyWhenRealAxis ?? false))
      {
        local axis = curPreset.getAxis(shortcut.id)
        if (axis.axisId == -1)
          axis.relative = true
      }
  }

  function fixControls()
  {
    foreach (fixData in fixesList)
    {
      local value = "valueFunction" in fixData ?
        fixData.valueFunction() : fixData.value
      if (::getTblValue("isAppend", fixData))
      {
        if (curPreset.isHotkeyShortcutBinded(fixData.source, value) ||
          (fixData.shouldAppendIfEmptyOnXInput && ::is_xinput_device() &&
            curPreset.getHotkey(fixData.target).len() == 0))
          curPreset.addHotkeyShortcut(fixData.target, value)
      }
      else
        curPreset.setHotkey(fixData.target, value)
    }
    foreach (shortcutsGroup in hardcodedShortcuts)
      if (!("condition" in shortcutsGroup) || shortcutsGroup.condition())
        foreach (shortcut in shortcutsGroup.list)
          curPreset.removeHotkeyShortcut(shortcut.name, shortcut.combo)
    setDefaultRelativeAxes()
  }

  function restoreHardcodedKeys(maxShortcutCombinations)
  {
    foreach (shortcutsGroup in hardcodedShortcuts)
      if (!("condition" in shortcutsGroup) || shortcutsGroup.condition())
        foreach (shortcut in shortcutsGroup.list)
          if (curPreset.getHotkey(shortcut.name).len() < maxShortcutCombinations)
            curPreset.addHotkeyShortcut(shortcut.name, shortcut.combo)
  }

  function clearGuiOptions()
  {
    local prefix = "USEROPT_"
    foreach (oType, value in curPreset.params)
      if (::g_string.startsWith(oType, prefix))
        delete curPreset.params[oType]
  }

  function commitGuiOptions()
  {
    if (!::g_login.isProfileReceived())
      return

    local mainOptionsMode = ::get_gui_options_mode()
    ::set_gui_options_mode(::OPTIONS_MODE_GAMEPLAY)
    local prefix = "USEROPT_"
    foreach (oType, value in curPreset.params)
      if (::g_string.startsWith(oType, prefix))
        if (oType in ::getroottable())
          ::set_option(::getroottable()[oType], value)
    ::set_gui_options_mode(mainOptionsMode)
    clearGuiOptions()
  }

  // While controls reloaded on PS4 from uncrorrect blk when mission started
  // it is required to commit controls when mission start.
  function onEventMissionStarted(params)
  {
    if (isPlatformSony)
      commitControls()
  }
}

::subscribe_handler(::g_controls_manager)

::g_script_reloader.registerPersistentDataFromRoot("g_controls_manager")
