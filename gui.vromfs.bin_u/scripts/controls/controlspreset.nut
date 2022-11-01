from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

::g_script_reloader.loadOnce("%scripts/controls/controlsPresets.nut")
let { blkFromPath } = require("%sqStdLibs/helpers/datablockUtils.nut")
let { copyParamsToTable, eachBlock, eachParam } = require("%sqstd/datablock.nut")
let controlsPresetConfigPath = require("%scripts/controls/controlsPresetConfigPath.nut")

const PRESET_ACTUAL_VERSION  = 5
const PRESET_DEFAULT_VERSION = 4

const BACKUP_OLD_CONTROLS_DEFAULT = 0 // false


let function getJoystickBlockV4(blk)
{
  if (::u.isDataBlock(blk?["joysticks"]))
    return blk["joysticks"]?["joystickSettings"]
  return null
}

let dataArranging = {
  function comparator(lhs, rhs)
  {
    return (this.sortList.indexof(lhs) ?? -1) <=> (this.sortList.indexof(rhs) ?? -1) || lhs <=> rhs
  }

  axisAttrOrder = [
    "axisId"
    "mouseAxisId"
    "innerDeadzone"
    "rangeMin"
    "rangeMax"
    "inverse"
    "nonlinearity"
    "kAdd"
    "kMul"
    "relSens"
    "relStep"
    "relative"
    "keepDisabledValue"
  ]

  paramsOrder = [
    "isXInput"
    "trackIrZoom"
    "trackIrAsHeadInTPS"
    "isExchangeSticksAvailable"
    "holdThrottleForWEP"
    "holdThrottleForFlankSpeed"
    "useMouseAim"
    "useJoystickMouseForVoiceMessage"
    "useMouseForVoiceMessage"
    "mouseJoystick"
  ]
}

let deviceIdByType = {
  mouseButton = STD_MOUSE_DEVICE_ID
  keyboardKey = STD_KEYBOARD_DEVICE_ID
  joyButton   = JOYSTICK_DEVICE_0_ID
  gesture     = STD_GESTURE_DEVICE_ID
}


let function getDefaultParams() {
  return {
    isXInput                          = false
    trackIrZoom                       = true
    trackIrForLateralMovement         = false
    trackIrAsHeadInTPS                = false
    isExchangeSticksAvailable         = false
    holdThrottleForWEP                = true
    holdThrottleForFlankSpeed         = false
    useMouseAim                       = false
    useJoystickMouseForVoiceMessage   = false
    useMouseForVoiceMessage           = false
    mouseJoystick                     = false
    useTouchpadAiming                 = false
  }
}


let function isSameMapping(lhs, rhs) {
  let noValue = {}
  let deviceMapAttr = [
    "name",
    "devId",
    "buttonsOffset",
    "buttonsCount",
    "axesOffset",
    "axesCount",
    "connected"
  ]

  if (lhs.len() != rhs.len())
    return false

  for (local j = 0; j < lhs.len(); j++)
    foreach (attr in deviceMapAttr)
      if (getTblValue(attr, lhs[j], noValue) != getTblValue(attr, rhs[j], noValue))
       return false

  return true
}


::ControlsPreset <- class {
  basePresetPaths = null
  hotkeys         = null
  axes            = null
  params          = null
  deviceMapping   = null
  controlsV4Blk   = null
  isLoaded        = false

  getDefaultParams = getDefaultParams // for compatibility with older code


  /****************************************************************/
  /**************************** PUBLIC ****************************/
  /****************************************************************/

  constructor(data = null, presetChain = [])
  {
    this.basePresetPaths = {}
    this.hotkeys         = {}
    this.axes            = {}
    this.params          = getDefaultParams()
    this.deviceMapping   = []

    if (::u.isString(data))
      this.loadFromPreset(data, presetChain)
    else if (::u.isDataBlock(data))
      this.loadFromBlk(data, presetChain)
    else if ((typeof data == "instance") && (data instanceof ::ControlsPreset))
    {
      this.basePresetPaths = ::u.copy(data.basePresetPaths)
      this.hotkeys         = ::u.copy(data.hotkeys)
      this.axes            = ::u.copy(data.axes)
      this.params          = ::u.copy(data.params)
      this.deviceMapping   = ::u.copy(data.deviceMapping)
      this.controlsV4Blk   = ::u.copy(data.controlsV4Blk)
      this.isLoaded        = true
    }
  }


  /****************************************************************/
  /*********************** PUBLIC FUNCTIONS ***********************/
  /****************************************************************/

  function resetHotkey(name)
  {
    this.hotkeys[name] <- []
  }

  function resetAxis(name)
  {
    this.axes[name] <- this.getDefaultAxis(name)
  }

  function getHotkey(name)
  {
    if (!(name in this.hotkeys))
      this.resetHotkey(name)
    return this.hotkeys[name]
  }

  function getAxis(name)
  {
    if (!::u.isString(name)) // Workaround to fix SQ critical asserts
    {
      let message = "Error: ControlsPreset.getAxis(name), name must be string"
      ::script_net_assert_once("ControlsPreset.getAxis() failed", message)
      return this.getDefaultAxis("")
    }
    if (!(name in this.axes))
      this.resetAxis(name)
    return this.axes[name]
  }

  function setHotkey(name, data)
  {
    this.hotkeys[name] <- ::u.copy(data)
  }

  function setAxis(name, data)
  {
    this.resetAxis(name)
    ::u.extend(this.axes[name], data)
  }

  function isHotkeyShortcutBinded(name, data)
  {
    if (!(name in this.hotkeys))
      return false

    foreach (shortcut in this.hotkeys[name])
      if (::u.isEqual(shortcut, data))
        return true

    return false
  }

  function addHotkeyShortcut(name, data)
  {
    if (!(name in this.hotkeys))
      this.hotkeys[name] <- [clone data]
    else if (!this.isHotkeyShortcutBinded(name, data))
      this.hotkeys[name].append(clone data)
  }

  function removeHotkeyShortcut(name, data)
  {
    if (!(name in this.hotkeys))
      return false

    foreach (idx, shortcut in this.hotkeys[name])
      if (::u.isEqual(shortcut, data))
      {
        this.hotkeys[name].remove(idx)
        return true
      }

    return false
  }

  static function getDefaultAxis(name = "")
  {
    let axis = {
      axisId              = -1
      mouseAxisId         = -1
      innerDeadzone       = 0.05
      rangeMin            = -1.0
      rangeMax            = 1.0
      inverse             = false
      nonlinearity        = 0.0
      kAdd                = 0.0
      kMul                = 1.0
      relSens             = 1.0
      relStep             = 0.0
      relative            = false
      keepDisabledValue   = false
    }
    let axisWithZeroRangeMin = [
      "throttle",
      "helicopter_collective",
      "gm_sight_distance"
    ]
    if (axisWithZeroRangeMin.indexof(name) != null)
      axis.rangeMin = 0.0
    return axis
  }


  /*
    Controls format sample for version 5:

    controls{     // Controls block start
      version:i=5   // Last controls version

      basePresetPaths{    // Base preset paths
        // default used for controls unspecified by other groups
        default:t="config/hotkeys/hotkey.keyboard_ver1.blk"

        // controls from hotkey.saitek_X52.blk used only for planes
        plane:t="config/hotkeys/hotkey.saitek_X52.blk"
      }

      hotkeys{            // Hotkeys block
        ID_FIRE_CANNONS{    // Shortcut for ID_FIRE_CANNONS
          mouseButton:i=1
        }

        // Hotkey block names non-unique.
        // Hotkey block with same name is alternative shortcut combination

        ID_LOCK_TARGET{     // First shortcut for ID_LOCK_TARGET
          mouseButton:i=2
        }

        ID_LOCK_TARGET{     // Second (alternative) shortcut for ID_LOCK_TARGET
          keyboardKey:i=45    // This variant consist of two keys
          joyButton:i=4       // keyboard key 45 and joystick button 4
        }

        ID_LOCK_TARGET{     // Third (alternative) shortcut for ID_LOCK_TARGET
          keyboardKey:i=25    // This variant consist of three keys
          keyboardKey:i=26    // two keyboard keys and ont mouse button
          mouseButton:i=3
        }

        ...

        // If block don't contain some shortcuts
        // their values used from base presets
      }

      axes{             // Axes block
        throttle{         // Throttle axes preferences
          axisId:i=2        // It use second axis considering device mapping
          // Other unspecified attributes use default values
        }

        zoom{             // Zoom axes preferences
          mouseAxisId:i=2   // This axis use mouse scroll
          relative:b=yes    // And it is relative
          // Other unspecified attributes use default values
        }

        ...

        // Axes not specified in block loaded from base presets
      }

      params{           // Params other when defined in base presets
        useMouseAim:b=no
        holdThrottleForWEP:b=yes
        ...
      }

      deviceMapping{    // Device mapping
        joystick{         // Each device defined in joystick block
          devId:t="044F:B67B"
          name:t="T.Flight Hotas"
          buttonsOffset:i=0
          axesOffset:i=0
          buttonsCount:i=18
          axesCount:i=8
          connected:b=yes
        }
      }
    }
  */


  /******** Load and save funtions ********/

  function loadFromPreset(presetPath, presetChain = [])
  {
    presetPath = this.compatibility.getActualPresetName(presetPath)

    // Check preset load recursion
    if (presetChain.indexof(presetPath) != null)
    {
      assert(false, "Controls preset require itself. " +
        "Preset chain: " + toString(presetChain) + " > " + presetPath)
      return
    }

    presetChain.append(presetPath)
    let blk = blkFromPath(presetPath)
    this.loadFromBlk(blk, presetChain)
    presetChain.pop()
  }


  function loadFromBlk(blk, presetChain = [])
  {
    local controlsBlk = blk?.controls
    let version = controlsBlk != null ?
      getTblValue("version", controlsBlk, PRESET_DEFAULT_VERSION) :
      getTblValue("controlsVer", blk, PRESET_DEFAULT_VERSION)

    let shouldBackupOldControls =
      getTblValue("shouldBackupOldControls", blk, BACKUP_OLD_CONTROLS_DEFAULT)

    let shouldForgetBasePresets =
      getTblValue("shouldForgetBasePresets", blk, false)

    if (version < PRESET_ACTUAL_VERSION && ::u.isString(blk?.hotkeysPreset) && blk?.hotkeysPreset != "")
    {
      this.loadFromPreset(blk?.hotkeysPreset, presetChain)
      return
    }

    let shouldLoadOldControls = (version < PRESET_ACTUAL_VERSION) || shouldBackupOldControls;
    if (shouldLoadOldControls)
    {
      log("ControlsPreset: BackupOldControls")
      this.controlsV4Blk = ::DataBlock()
      foreach (backupBlock in
        ["hotkeys", "joysticks", "controlsVer", "hotkeysPreset"])
        if (backupBlock in blk)
        {
          if (::u.isDataBlock(blk[backupBlock]))
          {
            this.controlsV4Blk[backupBlock] <- ::DataBlock()
            this.controlsV4Blk[backupBlock].setFrom(blk[backupBlock])
          }
          else
            this.controlsV4Blk[backupBlock] <- blk[backupBlock]
        }
      if (version < PRESET_ACTUAL_VERSION)
        controlsBlk = this.controlsV4Blk
      if (!shouldBackupOldControls)
        this.controlsV4Blk = null
    }

    this.loadBasePresetsFromBlk(controlsBlk, version, presetChain)

    log("ControlsPreset: LoadControls v" + version.tostring())

    this.loadHotkeysFromBlk    (controlsBlk, version)
    this.loadAxesFromBlk       (controlsBlk, version)
    this.loadParamsFromBlk     (controlsBlk, version)
    this.loadJoyMappingFromBlk (controlsBlk, version)
    this.isLoaded = true

    if (shouldForgetBasePresets)
      this.basePresetPaths = {}

    this.debugPresetStats()
  }


  function saveToBlk(blk)
  {
    let controlsBlk = ::DataBlock()
    controlsBlk["version"] = PRESET_ACTUAL_VERSION

    this.saveBasePresetPathsToBlk(controlsBlk)
    let controlsDiff = ::ControlsPreset(this)
    controlsDiff.diffBasePresets()

    log("ControlsPreset: SaveControls")

    controlsDiff.saveHotkeysToBlk    (controlsBlk)
    controlsDiff.saveAxesToBlk       (controlsBlk)
    controlsDiff.saveParamsToBlk     (controlsBlk)
    controlsDiff.saveJoyMappingToBlk (controlsBlk)
    blk["controls"] <- controlsBlk

    // Save controls settings used before 1.63
    if (this.controlsV4Blk != null)
      ::u.extend(blk, this.controlsV4Blk)

    this.debugPresetStats()
  }


  function debugPresetStats()
  {
    log("ControlsPreset: Stats:"
      + " hotkeys=" + this.hotkeys.len()
      + " axes=" + this.axes.len()
      + " params=" + this.params.len()
      + " joyticks=" + this.deviceMapping.len()
    )
  }


  /******** Partitial preset apply functions ********/

  function applyControls(appliedPreset)
  {
    appliedPreset.updateDeviceMapping(this.deviceMapping)

    foreach (hotkeyName, otherHotkey in appliedPreset.hotkeys)
      this.setHotkey(hotkeyName, otherHotkey)

    let usedAxesIds = []
    foreach (axesName, otherAxis in appliedPreset.axes)
    {
      this.setAxis(axesName, otherAxis)
      if (getTblValue("axisId", otherAxis, -1) >= 0)
        usedAxesIds.append(otherAxis["axisId"])
    }

    foreach (paramName, otherParam in appliedPreset.params)
      this.params[paramName] <- otherParam

    this.deviceMapping = appliedPreset.deviceMapping
  }


  function diffControls(basePreset)
  {
    let hotkeyNames = ::u.keys(basePreset.hotkeys)
    foreach (hotkeyName, _value in this.hotkeys)
      if (!(hotkeyName in basePreset.hotkeys))
        hotkeyNames.append(hotkeyName)

    foreach (hotkeyName in hotkeyNames)
    {
      let hotkey = this.getHotkey(hotkeyName)
      let otherHotkey = basePreset.getHotkey(hotkeyName)
      if (::u.isEqual(hotkey, otherHotkey))
        delete this.hotkeys[hotkeyName]
    }

    let axesNames = ::u.keys(basePreset.axes)
    foreach (axisName, _value in this.axes)
      if (!(axisName in basePreset.axes))
        axesNames.append(axisName)

    let usedAxesIds = []
    foreach (axisName in axesNames)
    {
      let axis = this.getAxis(axisName)
      let otherAxis = basePreset.getAxis(axisName)
      let axisAttributeNames = ::u.keys(axis)
      foreach (attr in axisAttributeNames)
        if (attr in otherAxis && axis[attr] == otherAxis[attr])
          delete axis[attr]
      if (axis.len() == 0)
        delete this.axes[axisName]
      if ("axisId" in otherAxis && otherAxis["axisId"] >= 0)
        usedAxesIds.append(otherAxis["axisId"])
    }

    foreach (paramName, otherParam in basePreset.params)
      if (paramName in this.params && ::u.isEqual(this.params[paramName], otherParam))
        delete this.params[paramName]
  }


  function applyBasePreset(presetPath, presetGroup, presetChain = [])
  {
    // TODO: fix filter for different presetGroups
    if (presetGroup != "default")
      return

    let preset = ::ControlsPreset(presetPath, presetChain)
    this.applyControls(preset)

    this.basePresetPaths[presetGroup] <- presetPath
  }


  function diffBasePresets()
  {
    foreach (presetGroup, presetPath in this.basePresetPaths)
    {
      // TODO: fix filter for different presetGroups
      if (presetGroup != "default")
        return

      let subPreset = ::ControlsPreset(presetPath)
      this.diffControls(subPreset)
    }

    if (this.basePresetPaths.len() == 0)
      this.diffControls(::ControlsPreset())

    this.basePresetPaths = {}
  }


  /******** Load controls from blk ********/

  function loadBasePresetsFromBlk(blk, version, presetChain = [])
  {
    if (version >= PRESET_ACTUAL_VERSION)
    {
      if (!("basePresetPaths" in blk))
        blk["basePresetPaths"] = ::DataBlock()
      let blkBasePresetPaths = blk["basePresetPaths"]

      if (presetChain.len() == 0 && blkBasePresetPaths.paramCount() == 0)
      {
        blkBasePresetPaths["default"] <- ::g_controls_presets.getControlsPresetFilename("keyboard_updates")
        log("ControlsPreset: Compatibility preset added to base presets")
      }

      eachParam(blkBasePresetPaths, function(presetPath, presetGroup) {
        let actualPresetPath = this.compatibility.getActualBasePresetPaths(presetPath)
        if (actualPresetPath != presetPath) {
          presetPath = actualPresetPath
          blkBasePresetPaths[presetGroup] = presetPath
        }
        log("ControlsPreset: BasePreset." + presetGroup + " = " + presetPath)
        this.applyBasePreset(presetPath, presetGroup, presetChain)
      }, this)
    }

    if (presetChain.len() == 1)
    {
      this.basePresetPaths["default"] <- presetChain[0]
      log("ControlsPreset: InitialPreset = " + presetChain[0])
    }
  }

  function loadHotkeysFromBlk(blk, version)
  {
    if (!::u.isDataBlock(blk?["hotkeys"]))
      return
    let blkHotkeys = blk["hotkeys"]

    if (version >= PRESET_ACTUAL_VERSION)
    {
      // Load hotkeys saved after 1.63
      let usedHotkeys = []
      for (local j = 0; j < blkHotkeys.blockCount(); j++)
      {
        let blkHotkey = blkHotkeys.getBlock(j)
        let hotkeyName = blkHotkey.getBlockName()
        let shortcut = []

        for (local k = 0; k < blkHotkey.paramCount(); k++)
        {
          let deviceType = blkHotkey.getParamName(k)
          let deviceId = getTblValue(deviceType, deviceIdByType, null)
          let buttonId = blkHotkey.getParamValue(k)

          if (deviceId == null || !::u.isInteger(buttonId) || buttonId == -1)
            continue

          shortcut.append({
            deviceId = deviceId
            buttonId = buttonId
          })
        }

        if (usedHotkeys.indexof(hotkeyName) == null)
        {
          usedHotkeys.append(hotkeyName)
          this.resetHotkey(hotkeyName)
        }
        this.getHotkey(hotkeyName).append(shortcut)
      }
    }
    else
    {
      // Load hotkeys saved before 1.63
      foreach (blkEvent in blkHotkeys % "event")
      {
        if (!::u.isString(blkEvent?["name"]))
          continue

        let hotkeyName = blkEvent["name"]
        this.resetHotkey(hotkeyName)

        let event = []
        foreach (blkShortcut in blkEvent % "shortcut")
        {
          if (!::u.isDataBlock(blkShortcut))
            continue

          let shortcut = []
          foreach (blkButton in blkShortcut % "button")
          {
            if (!::u.isInteger(blkButton?["deviceId"]) || !::u.isInteger(blkButton?["buttonId"]))
              continue

            shortcut.append({
              deviceId = blkButton["deviceId"]
              buttonId = blkButton["buttonId"]
            })
          }
          event.append(shortcut)
        }
        this.setHotkey(hotkeyName, event)
      }
    }
  }


  function loadAxesFromBlk(blk, version)
  {
    local blkAxes
    if (version >= PRESET_ACTUAL_VERSION)
      blkAxes = blk?["axes"]
    else
      blkAxes = getJoystickBlockV4(blk)

    if (!::u.isDataBlock(blkAxes))
      return

    eachBlock(blkAxes, function(blkAxis, name) {
      if (::g_string.startsWith(name, "square") || name == "mouse" || name == "devices" || name == "hangar")
        return
      if (version < PRESET_ACTUAL_VERSION)
        this.resetAxis(name)

      copyParamsToTable(blkAxis, this.getAxis(name))
    }, this)

    // Load mouse axes saved before 1.63
    if (version < PRESET_ACTUAL_VERSION)
    {
      let blkMouseAxes = blkAxes?["mouse"]
      let mouseAxes = ::u.copy(this.compatibility.mouseAxesDefaults)

      if (::u.isDataBlock(blkMouseAxes))
        foreach (idx, axisId in blkMouseAxes % "axis")
          mouseAxes[idx] = ::u.isInteger(axisId) ? ::get_axis_name(axisId) : ""

      foreach (idx, axisName in mouseAxes)
        if (::u.isString(axisName) && axisName.len() > 0)
          this.getAxis(axisName).mouseAxisId <- idx
    }
  }


  function loadParamsFromBlk(blk, version)
  {
    local blkParams
    if (version >= PRESET_ACTUAL_VERSION)
      blkParams = blk?["params"]
    else
      blkParams = getJoystickBlockV4(blk)

    if (blkParams == null)
      return

    this.params.__update(copyParamsToTable(blkParams))
  }


  function loadJoyMappingFromBlk(blk, _version)
  {
    let blkJoyMapping = blk?.deviceMapping
    if (blkJoyMapping == null)
      return

    this.deviceMapping = []
    foreach (blkJoystick in blkJoyMapping % "joystick")
      if (::u.isDataBlock(blkJoystick) &&
          ::u.isString(blkJoystick?["name"]) &&
          ::u.isString(blkJoystick?["devId"]) &&
          ::u.isInteger(blkJoystick?["buttonsOffset"]) &&
          ::u.isInteger(blkJoystick?["buttonsCount"]) &&
          ::u.isInteger(blkJoystick?["axesOffset"]) &&
          ::u.isInteger(blkJoystick?["axesCount"]))
        this.deviceMapping.append({
          name = blkJoystick["name"]
          devId = blkJoystick["devId"]
          buttonsOffset = blkJoystick["buttonsOffset"]
          buttonsCount = blkJoystick["buttonsCount"]
          axesOffset = blkJoystick["axesOffset"]
          axesCount = blkJoystick["axesCount"]
        })
  }


  /******** Save controls to blk ********/

  function saveBasePresetPathsToBlk(blk)
  {
    if (!("basePresetPaths" in blk))
      blk["basePresetPaths"] = ::DataBlock()
    let blkBasePresetPaths = blk["basePresetPaths"]

    foreach (presetGroup, presetPath in this.basePresetPaths)
      blkBasePresetPaths[presetGroup] <- presetPath
  }

  function saveHotkeysToBlk(blk)
  {
    if (!("hotkeys" in blk))
      blk["hotkeys"] = ::DataBlock()
    let blkHotkeys = blk["hotkeys"]

    let deviceTypeById = ::u.invert(deviceIdByType)

    let hotkeyNames = ::u.keys(this.hotkeys)
    hotkeyNames.sort()
    foreach (eventName in hotkeyNames)
    {
      let hotkeyData = this.hotkeys[eventName]

      foreach (shortcut in hotkeyData)
      {
        let blkShortcut = ::DataBlock()
        foreach (button in shortcut)
        {
          let deviceName = getTblValue(button.deviceId, deviceTypeById, null)
          if (deviceName != null)
            blkShortcut[deviceName] <- button.buttonId
        }
        blkHotkeys[eventName] <- blkShortcut
      }

      if (hotkeyData.len() == 0)
        blkHotkeys[eventName] <- ::DataBlock()
    }
  }


  function saveAxesToBlk(blk)
  {
    if (!("axes" in blk))
      blk["axes"] = ::DataBlock()
    let blkAxes = blk["axes"]

    let compEnv = {sortList = dataArranging.axisAttrOrder}
    let axisAttrComporator = dataArranging.comparator.bindenv(compEnv)

    let axisNames = ::u.keys(this.axes)
    axisNames.sort()
    foreach (axisName in axisNames)
    {
      let axisData = this.axes[axisName]
      let blkAxis = ::DataBlock()

      let attrNames = ::u.keys(axisData)
      attrNames.sort(axisAttrComporator)
      foreach (attr in attrNames)
        blkAxis[attr] = axisData[attr]

      blkAxes[axisName] = blkAxis
    }
  }


  function saveParamsToBlk(blk)
  {
    if (!("params" in blk))
      blk["params"] = ::DataBlock()
    let blkParams = blk["params"]

    let compEnv = {sortList = dataArranging.paramsOrder}
    let comparator = dataArranging.comparator.bindenv(compEnv)
    let paramNames = ::u.keys(this.params)
    paramNames.sort(comparator)
    foreach (name in paramNames)
      blkParams[name] <- this.params[name]
  }


  function saveJoyMappingToBlk(blk)
  {
    if (!("deviceMapping" in blk))
      blk["deviceMapping"] <- ::DataBlock()
    let blkJoyMapping = blk["deviceMapping"]

    foreach (joystick in this.deviceMapping)
    {
      let blkJoystick = ::DataBlock()
      foreach (attr, value in joystick)
        blkJoystick[attr] = value
      blkJoyMapping["joystick"] <- blkJoystick
    }
  }


  /******** Other functions ********/

  function getBasePresetNames()
  {
    if (!::g_login.isLoggedIn())
      return {} // Because g_controls_presets loads after login.

    return ::u.map(this.basePresetPaths, function(path) {
      return ::g_controls_presets.parsePresetFileName(path).name
    })
  }

  getBasePresetInfo = @(groupName = "default")
    ::g_controls_presets.parsePresetFileName(this.basePresetPaths?[groupName] ?? "")

  function getNumButtons()
  {
    local count = 0
    foreach (joy in this.deviceMapping)
      count = max(count, joy.buttonsOffset + joy.buttonsCount)
    return count
  }


  function getNumAxes()
  {
    local count = 0
    foreach (joy in this.deviceMapping)
      count = max(count, joy.axesOffset + joy.axesCount)
    return count
  }


  function getButtonName(deviceId, buttonId)
  {
    if (deviceId != JOYSTICK_DEVICE_0_ID)
      return loc(::get_button_name(deviceId, buttonId)) // C++ function

    let buttonLocalized = loc("composite/button")

    local name = null
    local connected = false
    name = ::get_button_name(deviceId, buttonId) // C++ function

    foreach (idx, joy in this.deviceMapping)
    {
      if (buttonId < joy.buttonsOffset || buttonId >= joy.buttonsOffset + joy.buttonsCount)
        continue

      if (!("connected" in joy) || joy.connected == true)
        connected = true

      if (name == null || !connected)
        name = ("C" + (idx + 1).tostring() + ":" +
          buttonLocalized + (buttonId - joy.buttonsOffset + 1).tostring())

      break
    }

    if (name == null)
      name = "?:" + buttonLocalized + (buttonId + 1).tostring()
    if (!connected)
      name += " (" + loc("composite/device_is_offline_short") + ")"
    return name
  }


  function getAxisName(axisId)
  {
    let axisLocalized = loc("composite/axis")

    local name = null
    local connected = false
    let defaultJoystick = ::joystick_get_default() // C++ function
    if (defaultJoystick)
      name = defaultJoystick.getAxisName(axisId)

    foreach (idx, joy in this.deviceMapping)
    {
      if (axisId < joy.axesOffset || axisId >= joy.axesOffset + joy.axesCount)
        continue

      if (!("connected" in joy) || joy.connected == true)
        connected = true

      if (name == null || !connected)
        name = ("C" + (idx + 1).tostring() + ":" + joy.name + ":" +
          axisLocalized + (axisId - joy.axesOffset + 1).tostring())

      break
    }

    if (name == null)
      name = "?:" + axisLocalized + (axisId + 1).tostring()
    if (!connected)
      name += " (" + loc("composite/device_is_offline") + ")"
    return name
  }


  function updateDeviceMapping(newDevices) {
    let oldDevices = this.deviceMapping
    log($"[CTRL] updating from {oldDevices.len()} to {newDevices.len()} devices")
    debugTableData(oldDevices)
    debugTableData(newDevices)

    if (isSameMapping(oldDevices, newDevices))
      return false // nothing to do

    let totalBindings = { axes = 0, buttons = 0 }
    let ranges = []
    let lostDevicesIndexes = []
    foreach (oid, old in oldDevices) {
      local found = false
      foreach (idx, new in newDevices) {
        if (old.devId == new.devId) {
          found = true
          if (new.connected) {
            ranges.append({
                axes = { from = old.axesOffset, to = new.axesOffset, count = new.axesCount }
                buttons = { from = old.buttonsOffset, to = new.buttonsOffset, count = new.buttonsCount }
              })
            totalBindings.axes = max(totalBindings.axes, new.axesOffset + new.axesCount)
            totalBindings.buttons = max(totalBindings.buttons, new.buttonsOffset + new.buttonsCount)
          } else {
            lostDevicesIndexes.append({old = oid, new = idx})
          }
        }
      }

      if (!found) {
        old["connected"] <- false
        newDevices.append(old)
        lostDevicesIndexes.append({old = oid, new = newDevices.len() - 1})
      }
    }

    log($"[CTRL] lost {lostDevicesIndexes.len()} devices")

    foreach (i in lostDevicesIndexes) {
      let old = oldDevices[i.old]
      ranges.append({
          axes = { from = old.axesOffset, to = totalBindings.axes, count = old.axesCount }
          buttons = { from = old.buttonsOffset, to = totalBindings.buttons, count = old.buttonsCount }
        })
      newDevices[i.new].axesOffset = totalBindings.axes
      newDevices[i.new].buttonsOffset = totalBindings.buttons

      totalBindings.axes += old.axesCount
      totalBindings.buttons += old.buttonsCount
    }

    log($"[CTRL] updated devices list ({newDevices.len()} devices)")
    log($"[CTRL] remapping {ranges.len()} ranges")

    let shouldRemap = @(id, m) id >= m.from && id < (m.from + m.count)
    foreach (axis in this.axes) {
      foreach (remap in ranges) {
        if (shouldRemap(axis.axisId, remap.axes)) {
          axis.axisId = axis.axisId - remap.axes.from + remap.axes.to
          break
        }
      }
    }

    foreach (event in this.hotkeys) {
      foreach (shortcut in event) {
        foreach (btn in shortcut) {
          if (btn.deviceId == JOYSTICK_DEVICE_0_ID) {
            foreach (remap in ranges) {
              if (shouldRemap(btn.buttonId, remap.buttons)) {
                btn.buttonId = btn.buttonId - remap.buttons.from + remap.buttons.to
                break
              }
            }
          }
        }
      }
    }

    this.deviceMapping = ::u.copy(newDevices)
    log($"[CTRL] final map for {this.deviceMapping.len()} devices:")
    debugTableData(this.deviceMapping)
    return true
  }


  /****************************************************************/
  /*************************** PRIVATES ***************************/
  /****************************************************************/


  /* Compatibility data for blk loading */

  static compatibility = {
    function getActualPresetName(presetPath)
    {
      if (presetPath == "hotkey.gamepad.blk")
        return "wt/config/hotkeys/hotkey.default.blk"
      return presetPath
    }

    function getActualBasePresetPaths(presetPath)
    {
      let indexConfigFolder = presetPath.indexof("config/hotkeys/hotkey")
      if (indexConfigFolder == 0)
        presetPath = $"{controlsPresetConfigPath.value}{presetPath}"

      return presetPath
    }

    mouseAxesDefaults = [
      "ailerons"
      "elevator"
      "throttle"
      "gm_zoom"
      "ship_zoom"
      "submarine_zoom"
      "helicopter_collective"
    ]
  }



}
