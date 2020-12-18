local { set_blk_value_by_path, get_blk_value_by_path } = require("sqStdLibs/helpers/datablockUtils.nut")
local { get_primary_screen_info } = ::require_native("dagor.system")
//------------------------------------------------------------------------------
local mSettings = {}
local mShared = {}
local mSkipUI = false
local mBlk = null
local mHandler = null
local mContainerObj = null
local mCfgStartup = {}
local mCfgApplied = {}
local mCfgInitial = {}
local mCfgCurrent = {}
local mScriptValid = true
local mValidationError = ""
local mMaintainDone = false
const mRowHeightScale = 1.0
const mMaxSliderSteps = 50
//-------------------------------------------------------------------------------
local mQualityPresets = ::DataBlock()
mQualityPresets.load("config/graphicsPresets.blk")

/*
compMode - When TRUE, option is enabled in GUI when Compatibility Mode is ON.
           Defaults to FALSE for qualityPresetsOptions, and TRUE for standaloneOptions.
fullMode - When TRUE, Оption is enabled in GUI when Compatibility Mode is OFF.
           Defaults to TRUE for both qualityPresetsOptions and standaloneOptions.
*/
local compModeGraphicsOptions = {
  qualityPresetsOptions = {
    texQuality        = { compMode = true }
    anisotropy        = { compMode = true }
    dirtSubDiv        = { compMode = true }
    tireTracksQuality = { compMode = true }
    msaa              = { compMode = true, fullMode = false }
    lastClipSize      = { compMode = true }
    compatibilityMode = { compMode = true }
    riGpuObjects      = { fullMode = false }
  }
  standaloneOptions = {
    dlss              = { compMode = false }
  }
}
//------------------------------------------------------------------------------
local mUiStruct = [
  {
    container = "sysopt_top_left"
    items = [
      "resolution"
    ]
  }
  {
    container = "sysopt_top_middle"
    items = [
      "mode"
    ]
  }
  {
    container = "sysopt_top_right"
    items = [
      "vsync"
      ]
  }
  {
    container = "sysopt_graphicsQuality"
    id = "graphicsQuality"
  }
  {
    container = "sysopt_bottom_left"
    items = [
      "dlss"
      "anisotropy"
      "msaa"
      "antialiasing"
      "ssaa"
      "texQuality"
      "shadowQuality"
      "backgroundScale"
      "cloudsQuality"
      "panoramaResolution"
      "landquality"
      "rendinstDistMul"
      "fxDensityMul"
      "grassRadiusMul"
      "ssaoQuality"
      "contactShadowsQuality"
      "ssrQuality"
      "waterQuality"
      "giQuality"
      "physicsQuality"
      "displacementQuality"
      "dirtSubDiv"
      "tireTracksQuality"
    ]
  }
  {
    container = "sysopt_bottom_right"
    items = [
      "shadows"
      "rendinstGlobalShadows"
      "staticShadowsOnEffects"
      "advancedShore"
      "haze"
      "softFx"
      "lastClipSize"
      "lenseFlares"
      "enableSuspensionAnimation"
      "alpha_to_coverage"
      "jpegShots"
      "compatibilityMode"
      "enableHdr"
    ]
  }
]
//------------------------------------------------------------------------------
local getGuiValue = @(id, defVal=null) (id in mCfgCurrent) ? mCfgCurrent[id] : defVal

local function logError(from="", msg="") {
  local fullMsg = $"[sysopt] ERROR {from}: {msg}"
  ::dagor.debug(fullMsg)
  return fullMsg
}

local function getOptionDesc(id) {
  if (!(id in mSettings)) {
    logError("sysopt.getOptionDesc()", $"Option '{id}' is UNKNOWN. It must be added to sysopt.settings table.")
    return null
  }
  return mSettings[id]
}

local function validateGuiValue(id, value) {
  if (!::is_platform_pc)
    return value

  local desc = getOptionDesc(id)
  if (type(value) != desc.uiType) {
    logError("sysopt.validateGuiValue()", $"Can't set '{id}'='{value}', value type is invalid.")
    return desc.def
  }
  switch (desc.widgetType) {
    case "checkbox":
      return value ? true : false
      break
    case "slider":
      if (value < desc.min || value > desc.max) {
        logError("sysopt.validateGuiValue()", $"Can't set '{id}'='{value}', value is out of range.")
        return (value < desc.min) ? desc.min : desc.max
      }
      break
    case "list":
    case "tabs":
      if (desc.values.indexof(value) == null) {
        logError("sysopt.validateGuiValue()", $"Can't set '{id}'='{value}', value is not in the allowed values list.")
        return desc.def
      }
      break
    case "editbox":
      if (value.tostring().len() > desc.maxlength) {
        logError("sysopt.validateGuiValue()", $"Can't set '{id}'='{value}', value is too long.")
        return value
      }
      break
  }
  return value
}

local function getGuiWidget(id) {
  if (!(id in mSettings)) {
    logError("sysopt.getGuiWidget()", $"Option '{id}' is UNKNOWN. It must be added to sysopt.settings table.")
    return null
  }

  local widgetId = getOptionDesc(id)?.widgetId
  local obj = (widgetId && ::check_obj(mContainerObj)) ? mContainerObj.findObject(widgetId) : null
  return ::check_obj(obj) ? obj : null
}

local function setGuiValue(id, value, skipUI=false) {
  value = validateGuiValue(id, value)
  mCfgCurrent[id] = value

  local obj = (skipUI || mSkipUI) ? null : getGuiWidget(id)
  if (obj) {
    local desc = getOptionDesc(id)
    local raw = null
    switch (desc.widgetType)
    {
      case "checkbox":
      case "slider":
        raw = value
        break
      case "list":
      case "tabs":
        raw = desc.values.indexof(value) ?? -1
        break
      case "editbox":
        raw = value.tostring()
        break
    }
    if (raw != null && obj.getValue() != raw) {
      desc.ignoreNextUiCallback = desc.widgetType != "checkbox"
      obj.setValue(raw)
    }
  }
}

local function enableGuiOption(id, state) {
  if (mSkipUI)
    return
  local rowObj = ::check_obj(mContainerObj) ? mContainerObj.findObject(id + "_tr") : null
  if (::check_obj(rowObj))
    rowObj.enable(state)
}

local function checkChanges(config1, config2) {
  local changes = {
    needSave = false
    needClientRestart = false
    needEngineReload = false
  }

  foreach (id, desc in mSettings)
  {
    local value1 = config1[id]
    local value2 = config2[id]
    if (value1 != value2)
    {
      changes.needSave = true

      local needApply = id != "graphicsQuality"
      if (needApply)
      {
        local requiresRestart = ::getTblValue("restart", desc)
        if (requiresRestart)
          changes.needClientRestart = true
        else
          changes.needEngineReload = true
      }
    }
  }

  return changes
}

local isClientRestartable = @() !::is_vendor_tencent()

local canRestartClient = @() isClientRestartable()
  && !(::is_in_loading_screen() || ::SessionLobby.isInRoom())

local isRestartPending = @() checkChanges(mCfgStartup, mCfgCurrent).needClientRestart

local isHotReloadPending = @() checkChanges(mCfgApplied, mCfgCurrent).needEngineReload

local function updateGuiNavbar(show=true) {
  local scene = mHandler?.scene
  if (!::check_obj(scene))
    return

  local showText = show && isRestartPending()
  local showRestartButton = showText && canRestartClient()
  local applyText = ::loc((show && !showRestartButton && isHotReloadPending()) ? "mainmenu/btnApply" : "mainmenu/btnOk")

  local objNavbarRestartText = scene.findObject("restart_suggestion")
  if (::check_obj(objNavbarRestartText))
    objNavbarRestartText.show(showText)
  local objNavbarRestartButton = scene.findObject("btn_restart")
  if (::check_obj(objNavbarRestartButton))
    objNavbarRestartButton.show(showRestartButton)
  local objNavbarApplyButton = scene.findObject("btn_apply")
  if (::check_obj(objNavbarApplyButton))
    objNavbarApplyButton.setValue(applyText)
}

local function pickQualityPreset() {
  local preset = "custom"
  mSkipUI = true
  local _cfgCurrent = mCfgCurrent
  local graphicsQualityDesc = getOptionDesc("graphicsQuality")
  foreach (presetId in graphicsQualityDesc.values) {
    if (presetId == "custom")
      continue
    mCfgCurrent = {}
    foreach (id, value in _cfgCurrent)
      mCfgCurrent[id] <- value
    mCfgCurrent["graphicsQuality"] = presetId
    mShared.graphicsQualityClick(true)
    local changes = checkChanges(mCfgCurrent, _cfgCurrent)
    if (!changes.needClientRestart && !changes.needEngineReload) {
      preset = presetId
      break
    }
  }
  mCfgCurrent = _cfgCurrent
  mSkipUI = false

  return preset
}

local function localize(optionId, valueId) {
  switch (optionId) {
    case "resolution":
    {
      if (valueId == "auto")
        return ::loc("options/auto")
      else
        return valueId
    }
    case "anisotropy":
    case "ssaa":
    case "msaa":
      return ::loc("options/" + valueId)
    case "graphicsQuality":
    case "texQuality":
    case "shadowQuality":
    case "tireTracksQuality":
    case "waterQuality":
    case "giQuality":
    case "dirtSubDiv":
      if (valueId == "none")
        return ::loc("options/none")
      local txt = (valueId=="ultralow" || valueId=="min")? "ultra_low" : (valueId=="ultrahigh")? "ultra_high" : valueId
      return ::loc("options/quality_" + txt)
  }
  return ::loc(format("options/%s_%s", optionId, valueId), valueId)
}

local function parseResolution(resolution) {
  local sides = resolution == "auto"
    ? [ 0, 0 ] // To be sorted first.
    : resolution.split("x").apply(@(v) ::to_integer_safe(::strip(v), 0, false))
  return {
    resolution = resolution
    w = sides?[0] ?? 0
    h = sides?[1] ?? 0
  }
}

local function getAvailableDlssModes()
{
  local values = ["off"]
  local selectedResolution = parseResolution(getGuiValue("resolution", "auto"))
  if (::is_dlss_quality_available_at_resolution(0, selectedResolution.w, selectedResolution.h))
    values.append("performance")
  if (::is_dlss_quality_available_at_resolution(1, selectedResolution.w, selectedResolution.h))
    values.append("balanced")
  if (::is_dlss_quality_available_at_resolution(2, selectedResolution.w, selectedResolution.h))
    values.append("quality")

  return values;
}

local function getListOption(id, desc, cb, needCreateList = true) {
  local raw = desc.values.indexof(mCfgCurrent[id]) ?? -1
  local customItems = ("items" in desc) ? desc.items : null
  local items = []
  foreach (index, valueId in desc.values)
    items.append(customItems ? customItems[index] : localize(id, valueId))
  return ::create_option_combobox(desc.widgetId, items, raw, cb, needCreateList)
}

//------------------------------------------------------------------------------
mShared = {
  setQualityPreset = function(preset) {
    foreach (k, v in mQualityPresets) {
      local value = v?[preset] ?? v?["medium"]
      if (value != null)
        setGuiValue(k, value)
    }
  }

  setGraphicsQuality = function() {
    local quality = getGuiValue("graphicsQuality", "high")
    if (mQualityPresets?.texQuality[quality] == null && quality!="custom") {
      quality = getGuiValue("compatibilityMode", false) ? "ultralow" : "high"
      setGuiValue("graphicsQuality", quality)
    }
    if (quality=="custom") {
      return
    } else
      mShared.setQualityPreset(quality)
  }

  enableByCompMode = function(id, enable) {
    local desc = getOptionDesc(id)
    local enabled = enable && (desc?.enabled() ?? true)
    enableGuiOption(id, enabled)
  }

  setCompatibilityMode = function() {
    if (getGuiValue("compatibilityMode")) {
      setGuiValue("backgroundScale",2)
      foreach (k, v in mQualityPresets) {
        local enabled = compModeGraphicsOptions.qualityPresetsOptions?[k].compMode ?? false
        mShared.enableByCompMode(k, enabled)
      }
      foreach (id, v in compModeGraphicsOptions.standaloneOptions)
        mShared.enableByCompMode(id, v?.compMode ?? true)
    }
    else {
      foreach (k, v in mQualityPresets) {
        local enabled = compModeGraphicsOptions.qualityPresetsOptions?[k].fullMode ?? true
        mShared.enableByCompMode(k, enabled)
      }
      foreach (id, v in compModeGraphicsOptions.standaloneOptions)
        mShared.enableByCompMode(id, v?.fullMode ?? true)
      setGuiValue("compatibilityMode", false)
    }
  }

  setLandquality = function() {
    local lq = getGuiValue("landquality")
    local cs = (lq==0)? 50 : (lq==4)? 150 : 100
    setGuiValue("clipmapScale",cs)
  }

  landqualityClick = @() mShared.setLandquality()

  setCustomSettings = function() {
    mShared.setGraphicsQuality()
    mShared.setLandquality()
    mShared.setCompatibilityMode()
  }

  graphicsQualityClick = function(silent=false) {
    local quality = getGuiValue("graphicsQuality", "high")
    if (!silent && quality=="ultralow") {
      local ok_func = function() {
        mShared.graphicsQualityClick(true)
        updateGuiNavbar(true)
      }
      local cancel_func = function() {
        local lowQuality = "low"
        setGuiValue("graphicsQuality", lowQuality)
        mShared.graphicsQualityClick()
        updateGuiNavbar(true)
      }
      mHandler.msgBox("sysopt_compatibility", ::loc("msgbox/compatibilityMode"), [
          ["yes", ok_func],
          ["no", cancel_func],
        ], "no", { cancel_fn = cancel_func })
    }
    mShared.setCustomSettings()
  }

  presetCheck = function() {
    local preset = pickQualityPreset()
    setGuiValue("graphicsQuality", preset)
  }

  resolutionClick = function() {
    local id = "dlss"
    local desc = getOptionDesc(id)
    if (!desc)
      return

    desc.init(null, desc) //list of dlss values depends only on resolution
    setGuiValue(id, desc.values.indexof(getGuiValue(id)) ?? desc.def, true)
    local obj = getGuiWidget(id)
    if (!::check_obj(obj))
      return

    local markup = getListOption(id, desc, "onSystemOptionChanged", false)
    mContainerObj.getScene().replaceContentFromText(obj, markup, markup.len(), mHandler)
  }

  dlssClick = function() {
    foreach (id in [ "antialiasing", "ssaa" ])
      enableGuiOption(id, getOptionDesc(id)?.enabled() ?? true)
  }

  cloudsQualityClick = function() {
    local cloudsQualityVal = getGuiValue("cloudsQuality", 1)
    setGuiValue("skyQuality", cloudsQualityVal == 0 ? 0 : 1)
  }

  grassClick = function() {
    local grassRadiusMul = getGuiValue("grassRadiusMul", 100)
    setGuiValue("grass", (grassRadiusMul > 10))
  }

  ssaoQualityClick = function() {
    if (getGuiValue("ssaoQuality") == 0) {
      setGuiValue("ssrQuality", 0)
      setGuiValue("contactShadowsQuality", 0)
    }
  }

  ssrQualityClick = function() {
    if ((getGuiValue("ssrQuality") > 0) && (getGuiValue("ssaoQuality")==0))
      setGuiValue("ssaoQuality",1)
  }

  contactShadowsQualityClick = function() {
    if (getGuiValue("contactShadowsQuality") > 0 && getGuiValue("ssaoQuality") == 0)
      setGuiValue("ssaoQuality", 1)
  }

  ssaaClick = function() {
    if (getGuiValue("ssaa") == "4X") {
      local okFunc = function() {
        setGuiValue("backgroundScale", 2)
        mShared.presetCheck()
        updateGuiNavbar(true)
      }
      local cancelFunc = function() {
        setGuiValue("ssaa", "none")
        mShared.presetCheck()
        updateGuiNavbar(true)
      }
      mHandler.msgBox("sysopt_ssaa", ::loc("msgbox/ssaa_warning"), [
        ["ok", okFunc],
        ["cancel", cancelFunc],
      ], "cancel", { cancel_fn = cancelFunc })
    }
  }

  compatibilityModeClick = function() {
    local isEnable = getGuiValue("compatibilityMode")
    if (isEnable) {
      local ok_func = function() {
        mShared.setCompatibilityMode()
        mShared.presetCheck()
        updateGuiNavbar(true)
      }
      local cancel_func = function() {
        setGuiValue("compatibilityMode", false)
        mShared.setCompatibilityMode()
        mShared.presetCheck()
        updateGuiNavbar(true)
      }
      mHandler.msgBox("sysopt_compatibility", ::loc("msgbox/compatibilityMode"), [
        ["yes", ok_func],
        ["no", cancel_func],
      ], "no", { cancel_fn = cancel_func })
    } else
      mShared.setCompatibilityMode()
  }

  getVideoModes = function(curResolution = null, isNeedAuto = true) {
    local minW = 1024
    local minH = 720

    local list = ::get_video_modes()
    local isListTruncated = list.len() <= 1
    if (isNeedAuto)
      list.append("auto")
    if (curResolution != null && list.indexof(curResolution) == null)
      list.append(curResolution)

    local data = list.map(parseResolution).filter(@(r)
      (r.w >= minW && r.h >= minH) || r.resolution == curResolution || r.resolution == "auto")

    local sortFunc = @(a,b) a.w <=> b.w  || a.h <=> b.h
    data.sort(sortFunc)

    // Debug: Fixing the truncated list when working via Remote Desktop.
    if (isListTruncated && ::is_dev_version && ::is_platform_pc) {
      local debugResolutions = [ "1024 x 768", "1280 x 720", "1280 x 1024",
        "1920 x 1080", "2520 x 1080", "3840 x 1080", "2560 x 1440", "3840 x 2160" ]
      local psi = ::is_platform_windows ? get_primary_screen_info() : {}
      local maxW = psi?.pixelsWidth  ?? data?[data.len() - 1].w ?? 1024
      local maxH = psi?.pixelsHeight ?? data?[data.len() - 1].h ?? 768
      ::u.appendOnce($"{maxW} x {maxH}", debugResolutions)
      local bonus = debugResolutions.map(parseResolution).filter(@(r)
        (r.w <= maxW || r.h <= maxH) && !list.contains(r.resolution))
      data.extend(bonus)
      data.sort(sortFunc)
    }

    return data.map(@(r) r.resolution)
  }

  getCurResolution = function(blk, desc) {
    local modes = mShared.getVideoModes(null)
    local value = get_blk_value_by_path(blk, desc.blk, "")

    local isListed = modes.indexof(value) != null
    if (isListed) // Supported system.
      return value

    local looksReliable = regexp2(@"^\d+ x \d+$").match(value)
    if (looksReliable) // Unsupported system. Or maybe altered by user, but somehow works.
      return value

    if (value == "auto")
      return value

    local screen = format("%d x %d", ::screen_width(), ::screen_height())
    return screen // Value damaged by user. Screen size can be wrong, but anyway, i guess user understands why it's broken.

    /*
    Can we respect get_video_modes() ?
      - It will work on all desktop computers (Windows, Mac OS, Linux) later, but currently, it works in Windows only, and it still returns an empty list in all other systems.

    Can we respect screen_width() and screen_height() ?
    Windows:
      - Fullscreen - YES. If the game resolution aspect ratio doesn't match the screen aspect ratio, image is visually distorted, but technically resolution values are correct.
      - Fullscreen window - NO. If the game resolution aspect ratio doesn't match the screen aspect ratio, the game resolution can be altered to match the screen aspect ratio (like 1680x1050 -> 1680x945).
      - Windowed - YES. Always correct, even if the window doesn't fit the screen.
    Mac OS:
      - Fullscreen - probably YES. There is only one fullscreen game resolution possible, the screen native resolution.
      - Windowed - probably NO. It's impossible to create a fixed size window in Mac OS X, all windows are freely resizable by user, always.
    Linux:
      - Unknown - in Linux, window resizability and ability to have a fullscreen option entirely depends on the selected window manager. It needs to be tested in Steam OS.
    Android, iOS, PlayStation 4:
      - Fullscreen - maybe YES. There can be aspect ratios non-standard for PC monitors.
    */
  }
}
//------------------------------------------------------------------------------
/*
  widgetType - type of the widget in UI ("list", "slider", "checkbox", "editbox", "tabs").
  def - default value in UI (it is not required, if there are getFromBlk/setToBlk functions).
  blk - path to variable in config.blk file structure (it is not required, if there are getFromBlk/setToBlk functions).
  restart - client restart is required to apply an option (e.g. no support in Renderer::onSettingsChanged() function).
  values - for string variables only, list of possible variable values in UI (for dropdown widget).
  items - optional, for string variables only, list of item titles in UI (for dropdown widget).
  min, max - for integer variables only, minimum and maximum variable values in UI (for slider widget).
  maxlength - for string/integer/float variables only, maximum variable value input length (for input field widget).
  onChanged - function, reaction to user changes in UI. This function can change multiple variables in UI.
  getFromBlk - function, imports value from config.blk, returns value in UI format.
  setToBlk - function, accepts value in UI format and exports it to BLK. Can change multiple variables in BLK.
  init - function, initializes the variable config section, for example, defines 'def' value and/or 'values' list.
  tooltipExtra - optional, text to be added to option tooltip.
  isVisible - function, for hide options
*/
mSettings = {
  resolution = { widgetType="list" def="1024 x 768" blk="video/resolution" restart=true
    init = function(blk, desc) {
      local curResolution = mShared.getCurResolution(blk, desc)
      desc.values <- mShared.getVideoModes(curResolution)
      desc.def <- curResolution
      desc.restart <- !::is_platform_windows
    }
    onChanged = "resolutionClick"
  }
  mode = { widgetType="list" def="fullscreen" blk="video/mode" restart=true
    init = function(blk, desc) {
      desc.values <- ["windowed"]
      if (::is_platform_windows)
        desc.values.append("fullscreenwindowed")
      if (!::is_vendor_tencent())
        desc.values.append("fullscreen")
      desc.def = desc.values.top()
      desc.restart <- !::is_platform_windows
    }
    setToBlk = function(blk, desc, val) {
      set_blk_value_by_path(blk, desc.blk, val)
      set_blk_value_by_path(blk, "video/windowed", val == "windowed")
    }
  }
  vsync = { widgetType="list" def="vsync_off" blk="video/vsync" restart=true
    getFromBlk = function(blk, desc) {
      local vsync = get_blk_value_by_path(blk, "video/vsync", false)
      local adaptive = ::is_gpu_nvidia() && get_blk_value_by_path(blk, "video/adaptive_vsync", true)
      return (vsync && adaptive)? "vsync_adaptive" : (vsync)? "vsync_on" : "vsync_off"
    }
    setToBlk = function(blk, desc, val) {
      set_blk_value_by_path(blk, "video/vsync", val!="vsync_off")
      set_blk_value_by_path(blk, "video/adaptive_vsync", val=="vsync_adaptive")
    }
    init = function(blk, desc) {
      desc.values <- ::is_gpu_nvidia() ? [ "vsync_off", "vsync_on", "vsync_adaptive" ] : [ "vsync_off", "vsync_on" ]
    }
  }
  graphicsQuality = { widgetType="tabs" def="high" blk="graphicsQuality" restart=false
    values = [ "ultralow", "low", "medium", "high", "max", "movie", "custom" ]
    onChanged = "graphicsQualityClick"
  }
  dlss = { widgetType="list" def="off" blk="video/dlssQuality" restart=false
    init = function(blk, desc) {
      desc.values <- getAvailableDlssModes()
    }
    onChanged = "dlssClick"
    getFromBlk = function(blk, desc) {
      local quality = get_blk_value_by_path(blk, desc.blk, -1)
      return (quality == 0) ? "performance" : (quality == 1) ? "balanced" : (quality == 2) ? "quality" : "off"
    }
    setToBlk = function(blk, desc, val) {
      local quality = (val == "performance") ? 0 : (val == "balanced") ? 1 : (val == "quality") ? 2 : -1
      set_blk_value_by_path(blk, desc.blk, quality)
    }
  }
  anisotropy = { widgetType="list" def="2X" blk="graphics/anisotropy" restart=true
    values = [ "off", "2X", "4X", "8X", "16X" ]
    getFromBlk = function(blk, desc) {
      local anis = get_blk_value_by_path(blk, desc.blk, 2)
      return (anis==16)? "16X" : (anis==8)? "8X" : (anis==4)? "4X" : (anis==2)? "2X" : "off"
    }
    setToBlk = function(blk, desc, val) {
      local anis = (val=="16X")? 16 : (val=="8X")? 8 : (val=="4X")? 4 : (val=="2X")? 2 : 1
      set_blk_value_by_path(blk, desc.blk, anis)
    }
  }
  msaa = { widgetType="list" def="off" blk="directx/maxaa" restart=true
    values = [ "off", "on"]
    getFromBlk = function(blk, desc) {
      local msaa = get_blk_value_by_path(blk, desc.blk, 0)
      return (msaa>0)? "on" :"off"
    }
    setToBlk = function(blk, desc, val) {
      local msaa = (val=="on")? 2 : 0
      set_blk_value_by_path(blk, desc.blk, msaa)
    }
  }
  antialiasing = { widgetType="list" def="none" blk="video/postfx_antialiasing" restart=false
    values = ::is_opengl_driver() ? [ "none", "fxaa", "high_fxaa"] : [ "none", "fxaa", "high_fxaa", "low_taa", "high_taa" ]
    enabled = @() !getGuiValue("compatibilityMode") && getGuiValue("dlss", "off") == "off"
  }
  ssaa = { widgetType="list" def="none" blk="graphics/ssaa" restart=false
    values = [ "none", "4X" ]
    enabled = @() !getGuiValue("compatibilityMode") && getGuiValue("dlss", "off") == "off"
    onChanged = "ssaaClick"
    getFromBlk = function(blk, desc) {
      local val = get_blk_value_by_path(blk, desc.blk, 1.0)
      return (val == 4.0) ? "4X" : "none"
    }
    setToBlk = function(blk, desc, val) {
      local res = (val == "4X") ? 4.0 : 1.0
      set_blk_value_by_path(blk, desc.blk, res)
    }
  }
  texQuality = { widgetType="list" def="high" blk="graphics/texquality" restart=true
    init = function(blk, desc) {
      local dgsTQ = ::get_dgs_tex_quality() // 2=low, 1-medium, 0=high.
      local configTexQuality = desc.values.indexof(::getSystemConfigOption("graphics/texquality", "high")) ?? -1
      local sysTexQuality = [2, 1, 0].indexof(dgsTQ) ?? configTexQuality
      if (sysTexQuality == configTexQuality)
        return

      local restrictedValueName = localize("texQuality", desc.values[sysTexQuality])
      local restrictedValueItem = {
        text = ::colorize("badTextColor", restrictedValueName + " **")
        textStyle = "textStyle:t='textarea';"
      }
      desc.items <- []
      foreach (index, item in desc.values)
        desc.items.append((index <= sysTexQuality) ? localize("texQuality", item) : restrictedValueItem)
      desc.tooltipExtra <- ::colorize("badTextColor", "** " + ::loc("msgbox/graphicsOptionValueReduced/lowVideoMemory",
        { name = ::loc("options/texQuality"), value = restrictedValueName }))
    }
    values =   [ "low", "medium", "high" ]
  }
  shadowQuality= { widgetType="list" def="high" blk="graphics/shadowQuality" restart=false
    values = [ "ultralow", "low", "medium", "high", "ultrahigh" ]
  }
  selfReflection = { widgetType="checkbox" def=true blk="render/selfReflection" restart=false
  }
  backgroundScale = { widgetType="slider" def=2 min=0 max=2 blk="graphics/backgroundScale" restart=false
    blkValues = [ 0.7, 0.85, 1.0 ]
    getFromBlk = function(blk, desc) {
      local val = get_blk_value_by_path(blk, desc.blk, 1.0)
      if (getGuiValue("ssaa") == "4X" && !getGuiValue("compatibilityMode"))
        val = 2.0
      return ::find_nearest(val, desc.blkValues)
    }
    setToBlk = function(blk, desc, val) {
      local res = ::getTblValue(val, desc.blkValues, desc.def)
      if (getGuiValue("ssaa") == "4X" && !getGuiValue("compatibilityMode"))
        res = 2.0
      set_blk_value_by_path(blk, desc.blk, res)
    }
  }
  landquality = { widgetType="slider" def=0 min=0 max=4 blk="graphics/landquality" restart=false
    onChanged = "landqualityClick"
  }
  clipmapScale = { widgetType="slider" def=100 min=30 max=150 blk="graphics/clipmapScale" restart=false
    getFromBlk = function(blk, desc) { return (get_blk_value_by_path(blk, desc.blk, desc.def/100.0) * 100).tointeger() }
    setToBlk = function(blk, desc, val) { set_blk_value_by_path(blk, desc.blk, val/100.0) }
  }
  rendinstDistMul = { widgetType="slider" def=100 min=50 max=220 blk="graphics/rendinstDistMul" restart=false
    getFromBlk = function(blk, desc) { return (get_blk_value_by_path(blk, desc.blk, desc.def/100.0) * 100).tointeger() }
    setToBlk = function(blk, desc, val) { set_blk_value_by_path(blk, desc.blk, val/100.0) }
  }
  skyQuality = { widgetType="slider" def=1 min=0 max=2 blk="graphics/skyQuality" restart=false
    getFromBlk = function(blk, desc) { return (2 - get_blk_value_by_path(blk, desc.blk, 2-desc.def)).tointeger() }
    setToBlk = function(blk, desc, val) { set_blk_value_by_path(blk, desc.blk, 2-val) }
  }
  cloudsQuality = { widgetType="slider" def=1 min=0 max=2 blk="graphics/cloudsQuality" restart=false
    onChanged = "cloudsQualityClick"
    getFromBlk = function(blk, desc) { return (2 - get_blk_value_by_path(blk, desc.blk, 2-desc.def)).tointeger() }
    setToBlk = function(blk, desc, val) { set_blk_value_by_path(blk, desc.blk, 2-val) }
  }
  panoramaResolution = { widgetType="slider" def=8 min=4 max=16 blk="graphics/panoramaResolution" restart=false
    getFromBlk = function(blk, desc) { return (get_blk_value_by_path(blk, desc.blk, desc.def*256) / 256).tointeger() }
    setToBlk = function(blk, desc, val) { set_blk_value_by_path(blk, desc.blk, val*256) }
  }
  fxDensityMul = { widgetType="slider" def=100 min=20 max=100 blk="graphics/fxDensityMul" restart=false
    getFromBlk = function(blk, desc) { return (get_blk_value_by_path(blk, desc.blk, desc.def/100.0) * 100).tointeger() }
    setToBlk = function(blk, desc, val) { set_blk_value_by_path(blk, desc.blk, val/100.0) }
  }
  physicsQuality = { widgetType="slider" def=3 min=0 max=5 blk="graphics/physicsQuality" restart=false
  }
  grassRadiusMul = { widgetType="slider" def=80 min=1 max=180 blk="graphics/grassRadiusMul" restart=false
    onChanged = "grassClick"
    getFromBlk = function(blk, desc) { return (get_blk_value_by_path(blk, desc.blk, desc.def/100.0) * 100).tointeger() }
    setToBlk = function(blk, desc, val) { set_blk_value_by_path(blk, desc.blk, val/100.0) }
  }
  grass = { widgetType="checkbox" def=true blk="render/grass" restart=false
  }
  enableSuspensionAnimation = { widgetType="checkbox" def=false blk="graphics/enableSuspensionAnimation" restart=true
  }
  alpha_to_coverage = { widgetType="checkbox" def=false blk="video/alpha_to_coverage" restart=false
  }
  tireTracksQuality = { widgetType="list" def="none" blk="graphics/tireTracksQuality" restart=false
    values = [ "none", "medium", "high", "ultrahigh" ]
    getFromBlk = function(blk, desc) {
      local val = get_blk_value_by_path(blk, desc.blk, 0)
      return ::getTblValue(val, desc.values, desc.def)
    }
    setToBlk = function(blk, desc, val) {
      local res = desc.values.indexof(val) ?? 0
      set_blk_value_by_path(blk, desc.blk, res)
    }
  }
  waterQuality = { widgetType="list" def="high" blk="graphics/waterQuality" restart=false
    values = [ "low", "medium", "high", "ultrahigh" ]
  }
  giQuality = { widgetType="list" def="low" blk="graphics/giQuality" restart=false
    values = [ "low", "medium", "high" ], isVisible = @() !::is_opengl_driver()
  }
  dirtSubDiv = { widgetType="list" def="high" blk="graphics/dirtSubDiv" restart=false
    values = [ "high", "ultrahigh" ]
    getFromBlk = function(blk, desc) {
      local val = get_blk_value_by_path(blk, desc.blk, 1)
      return (val==2)? "ultrahigh" : "high"
    }
    setToBlk = function(blk, desc, val) {
      local res = (val=="ultrahigh")? 2 : 1
      set_blk_value_by_path(blk, desc.blk, res)
    }
  }
  ssaoQuality = { widgetType="slider" def=0 min=0 max=2 blk="render/ssaoQuality" restart=false
    onChanged = "ssaoQualityClick"
  }
  ssrQuality = { widgetType="slider" def=0 min=0 max=2 blk="render/ssrQuality" restart=false
    onChanged = "ssrQualityClick"
  }
  shadows = { widgetType="checkbox" def=true blk="render/shadows" restart=false
  }
  rendinstGlobalShadows = { widgetType="checkbox" def=true blk="render/rendinstGlobalShadows" restart=false
  }
  advancedShore = { widgetType="checkbox" def=false blk="graphics/advancedShore" restart=false
  }
  haze = { widgetType="checkbox" def=false blk="render/haze" restart=false
  }
  softFx = { widgetType="checkbox" def=true blk="render/softFx" restart=false
  }
  lastClipSize = { widgetType="checkbox" def=false blk="graphics/lastClipSize" restart=false
    getFromBlk = function(blk, desc) { return (get_blk_value_by_path(blk, desc.blk, 4096) == 8192) }
    setToBlk = function(blk, desc, val) { set_blk_value_by_path(blk, desc.blk, (val ? 8192 : 4096)) }
  }
  lenseFlares = { widgetType="checkbox" def=false blk="graphics/lenseFlares" restart=false
  }
  jpegShots = { widgetType="checkbox" def=true blk="debug/screenshotAsJpeg" restart=false }
  compatibilityMode = { widgetType="checkbox" def=false blk="video/compatibilityMode" restart=true
    onChanged = "compatibilityModeClick"
  }
  enableHdr = { widgetType="checkbox" def=false blk="directx/enableHdr" restart=true enabled=@() ::is_hdr_available() }
  displacementQuality = { widgetType="slider" def=2 min=0 max=3 blk="graphics/displacementQuality" restart=false
  }
  contactShadowsQuality = { widgetType="slider" def=0 min=0 max=2 blk="graphics/contactShadowsQuality" restart=false
    onChanged = "contactShadowsQualityClick"
  }
  staticShadowsOnEffects = { widgetType="checkbox" def=false blk="render/staticShadowsOnEffects" restart=false
  }
  riGpuObjects = { widgetType="checkbox" def=true blk="graphics/riGpuObjects" restart=false
  }
}
//------------------------------------------------------------------------------
local function validateInternalConfigs() {
  local errorsList = []
  foreach (id, desc in mSettings) {
    local widgetType = ::getTblValue("widgetType", desc)
    if (!isInArray(widgetType, ["list", "slider", "checkbox", "editbox", "tabs"]))
      errorsList.append(logError("sysopt.validateInternalConfigs()",
        "Option '"+id+"' - 'widgetType' invalid or undefined."))
    if ((!("blk" in desc) || type(desc.blk) != "string" || !desc.blk.len()) && (!("getFromBlk" in desc) || !("setToBlk" in desc)))
      errorsList.append(logError("sysopt.validateInternalConfigs()",
        "Option '"+id+"' - 'blk' invalid or undefined. It can be undefined only when both getFromBlk & setToBlk are defined."))
    if (("onChanged" in desc) && type(desc.onChanged) != "function")
      errorsList.append(logError("sysopt.validateInternalConfigs()",
        "Option '"+id+"' - 'onChanged' function not found in sysopt.shared."))

    local def = ::getTblValue("def", desc)
    if (def == null)
      errorsList.append(logError("sysopt.validateInternalConfigs()",
        "Option '"+id+"' - 'def' undefined."))

    local uiType = desc.uiType
    switch (widgetType)
    {
      case "checkbox":
        if (def != null && uiType != "bool")
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            "Option '"+id+"' - 'widgetType'/'def' conflict."))
        break
      case "slider":
        if (def != null && uiType != "integer")
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            "Option '"+id+"' - 'widgetType'/'def' conflict."))
        local invalidVal = -1
        local vMin = desc?.min ?? invalidVal
        local vMax = desc?.max ?? invalidVal
        local safeDef = (def != null) ? def : invalidVal
        if (!("min" in desc) || !("max" in desc) || type(vMin) != uiType || type(vMax) != uiType
            || vMin > vMax || vMin > safeDef || safeDef > vMax )
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            "Option '"+id+"' - 'min'/'def'/'max' conflict."))
        break
      case "list":
      case "tabs":
        if (def != null && uiType != "string")
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            "Option '"+id+"' - 'widgetType'/'def' conflict."))
        local values = ::getTblValue("values", desc, [])
        if (!values.len())
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            "Option '"+id+"' - 'values' is empty or undefined."))
        if (def != null && values.len() && !isInArray(def, values))
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            "Option '"+id+"' - 'def' is not listed in 'values'."))
        break
      case "editbox":
        if (def != null && uiType != "integer" && uiType != "float" && uiType != "string")
          errorsList.append(logError("sysopt.validateInternalConfigs()",
                                     "Option '"+id+"' - 'widgetType'/'def' conflict."))
        local maxlength = ::getTblValue("maxlength", desc, -1)
        if (maxlength < 0 || (def != null && def.tostring().len() > maxlength))
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            "Option '"+id+"' - 'maxlength'/'def' conflict."))
        break
    }
  }

  foreach (k, v in mQualityPresets)
  {
    if (v.paramCount() == 0)
      errorsList.append(logError("sysopt.validateInternalConfigs()",
       $"Quality presets - 'qualityPresets' k='{k}' contains invalid data."))
    if (!(k in mSettings))
      errorsList.append(logError("sysopt.validateInternalConfigs()",
        $"Quality presets - k='{k}' is not found in 'settings' table."))
    if (type(v)=="table" && ("graphicsQuality" in mSettings) && ("values" in mSettings.graphicsQuality))
    {
      local qualityValues = mSettings.graphicsQuality.values
      foreach (qualityId, value in v)
      {
        if (!isInArray(qualityId, qualityValues))
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            $"Quality presets - k='{k}', graphics quality '{qualityId}' not exists."))
        if (value != validateGuiValue(k, value))
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            $"Quality presets - k='{k}', v.{qualityId}='{value}' is invalid value for '{k}'."))
      }
    }
  }

  foreach (sectIndex, section in mUiStruct)
  {
    local container = ::getTblValue("container", section)
    local id = ::getTblValue("id", section)
    local items = ::getTblValue("items", section)
    if (!container || (!id && !items))
      errorsList.append(logError("sysopt.validateInternalConfigs()",
        "Array uiStruct - Index "+sectIndex+" contains invalid data."))
    local ids = items? items : id? [ id ] : []
    foreach (itemId in ids)
      if (!(itemId in mSettings))
        errorsList.append(logError("sysopt.validateInternalConfigs()",
          "Array uiStruct - Option '"+itemId+"' not found in 'settings' table."))
  }

  mScriptValid = !errorsList.len()
  if (::is_dev_version)
    mValidationError = ::g_string.implode(errorsList, "\n")
}

local function configRead() {
  mCfgInitial = {}
  mCfgCurrent = {}
  mBlk = ::DataBlock()
  if (!mBlk.tryLoad(::get_config_name()))
    ::dagor.debug(::get_config_name()+" not read")

  foreach (id, desc in mSettings) {
    if ("init" in desc)
      desc.init(mBlk, desc)
    local value = ("getFromBlk" in desc) ? desc.getFromBlk(mBlk, desc) : get_blk_value_by_path(mBlk, desc.blk, desc.def)
    mCfgInitial[id] <- value
    mCfgCurrent[id] <- validateGuiValue(id, value)
  }

  if (!mCfgStartup.len())
    foreach (id, value in mCfgInitial)
      mCfgStartup[id] <- value

  if (!mCfgApplied.len())
    foreach (id, value in mCfgInitial)
      mCfgApplied[id] <- value
}

local function init() {
  local blk = ::DataBlock()
  if (!blk.tryLoad(::get_config_name()))
    ::dagor.debug(::get_config_name()+" not read")

  foreach (id, desc in mSettings) {
    if ("init" in desc)
      desc.init(blk, desc)
    if (("onChanged" in desc) && type(desc.onChanged)=="string")
      desc.onChanged = (desc.onChanged in mShared) ? mShared[desc.onChanged] : null
    local uiType = ("def" in desc) ? type(desc.def) : null
    desc.uiType <- uiType
    desc.widgetId <- null
    desc.ignoreNextUiCallback <- false
  }

  validateInternalConfigs()
  configRead()
}

local function configWrite() {
  if (! ::is_platform_pc)
    return;
  if (!mBlk) return
  ::dagor.debug("[sysopt] Saving config:")
  foreach (id, _ in mCfgCurrent) {
    local value = getGuiValue(id)
    if (mCfgInitial?[id] != value)
      ::dagor.debug("[sysopt] " + id + ": " + (mCfgInitial?[id] ?? "null") + " -> " + value)
    local desc = getOptionDesc(id)
    if ("setToBlk" in desc)
      desc.setToBlk(mBlk, desc, value)
    else
      set_blk_value_by_path(mBlk, desc.blk, value)
  }
  mBlk.saveToTextFile(::get_config_name())
  ::dagor.debug("[sysopt] Config saved.")
}

local function configFree() {
  mBlk = null
  mHandler = null
  mContainerObj = null
  mCfgInitial = {}
  mCfgCurrent = {}
}

local function onGuiLoaded() {
  if (!mScriptValid)
    return

  mShared.setCustomSettings()
  mShared.presetCheck()
  updateGuiNavbar(true)
}

local function onGuiUnloaded() {
  updateGuiNavbar(false)
}

local isSavePending = @() checkChanges(mCfgInitial, mCfgCurrent).needSave

local function configMaintain() {
  if (mMaintainDone)
    return
  mMaintainDone = true
  if (!::is_platform_pc)
    return
  if (!mScriptValid)
    return

  if (::getSystemConfigOption("graphicsQuality", "high") == "user") // Need to reset
  {
    local isCompatibilityMode = ::getSystemConfigOption("video/compatibilityMode", false)
    ::setSystemConfigOption("graphicsQuality", isCompatibilityMode ? "ultralow" : "high")
  }

  configRead()

  mShared.setCustomSettings()
  mShared.presetCheck()

  if (isSavePending()) {
    ::dagor.debug("[sysopt] Graphics settings maintenance, config.blk repaired.")
    configWrite()
  }

  configFree()
}

local function applyRestartClient(forced=false) {
  if (!isClientRestartable())
    return

  if (!forced && !canRestartClient()) {
    ::showInfoMsgBox(::loc("msgbox/client_restart_rejected"), "sysopt_restart_rejected")
    return
  }

  ::dagor.debug("[sysopt] Restarting client.")
  ::save_profile(false)
  ::save_short_token()
  ::restart_game(false)
}

local function applyRestartEngine(reloadScene = false) {
  mCfgApplied = {}
  foreach (id, value in mCfgCurrent)
    mCfgApplied[id] <- value

  ::dagor.debug("[sysopt] Resetting renderer.")
  ::on_renderer_settings_change()
  ::handlersManager.updateSceneBgBlur(true)

  if (!reloadScene)
    return

  ::handlersManager.doDelayed(::handlersManager.markfullReloadOnSwitchScene)
  ::call_darg("updateExtWatched", {
      resolution = mCfgCurrent.resolution
      screenMode = mCfgCurrent.mode
  })
}

local isReloadSceneRerquired = @() mCfgApplied.resolution != mCfgCurrent.resolution
  || mCfgApplied.mode != mCfgCurrent.mode

local function onRestartClient() {
  configWrite()
  configFree()
  applyRestartClient()
}

local function onConfigApply() {
  if (!mScriptValid)
    return
  if (!::check_obj(mContainerObj))
    return

  mShared.presetCheck()
  onGuiUnloaded()

  if (isSavePending())
    configWrite()

  local restartPending = isRestartPending()
  if (!restartPending && isHotReloadPending())
    applyRestartEngine(isReloadSceneRerquired())

  local handler = mHandler
  configFree()

  if (restartPending && isClientRestartable())
  {
    local func_restart = function() {
      applyRestartClient()
    }

    if (canRestartClient())
    {
      local message = ::loc("msgbox/client_restart_required") + "\n" + ::loc("msgbox/restart_now")
      handler.msgBox("sysopt_apply", message, [
          ["restart", func_restart],
          ["no"],
        ], "restart", { cancel_fn = function(){} })
    }
    else
    {
      local message = ::loc("msgbox/client_restart_required")
      handler.msgBox("sysopt_apply", message, [
          ["ok"],
        ], "ok", { cancel_fn = function(){} })
    }
  }
}

local isCompatibiliyMode = @() mCfgStartup?.compatibilityMode
  ?? ::getSystemConfigOption("video/compatibilityMode", false)

local function onGuiOptionChanged(obj) {
  local widgetId = ::check_obj(obj) ? obj?.id : null
  if (!widgetId)
    return
  local id = widgetId.slice(("sysopt_").len())

  local desc = getOptionDesc(id)
  if (!desc)
    return

  local curValue = ::getTblValue(id, mCfgCurrent)
  if (curValue == null)  //not inited or already cleared?
    return

  if (desc.ignoreNextUiCallback) {
    desc.ignoreNextUiCallback = false
    return
  }

  local value = null
  local raw = obj.getValue()
  switch (desc.widgetType)
  {
    case "checkbox":
      value = raw == true
      break
    case "slider":
      value = raw.tointeger()
      break
    case "list":
    case "tabs":
      value = desc.values[raw]
      break
    case "editbox":
      switch (desc.uiType)
      {
        case "integer":
          value = (regexp2(@"^\-?\d+$").match(strip(raw))) ? raw.tointeger() : null
          break
        case "float":
          value = (regexp2(@"^\-?\d+(\.\d*)?$").match(strip(raw))) ? raw.tofloat() : null
          break
        case "string":
          value = raw.tostring()
          break
      }
      if (value == null)
      {
        value = curValue
        setGuiValue(id, value, false)
      }
      break
  }

  if (value == curValue)
    return

  setGuiValue(id, value, true)
  if (("onChanged" in desc) && desc.onChanged)
    desc.onChanged()

  if (id != "graphicsQuality")
    mShared.presetCheck()
  updateGuiNavbar(true)
}

local canUseGraphicsOptions = @() ::is_platform_pc && ::has_feature("GraphicsOptions")

local function fillGuiOptions(containerObj, handler) {
  if (!::check_obj(containerObj) || !handler)
    return
  local guiScene = containerObj.getScene()

  if (!mScriptValid) {
    local msg = ::loc("msgbox/internal_error_header") + "\n" + mValidationError
    local data = ::format("textAreaCentered { text:t='%s' size:t='pw,ph' }", ::g_string.stripTags(msg))
    guiScene.replaceContentFromText(containerObj.id, data, data.len(), handler)
    return
  }

  guiScene.setUpdatesEnabled(false, false)
  guiScene.replaceContent(containerObj, "gui/options/systemOptions.blk", handler)
  mContainerObj = containerObj
  mHandler = handler

  if (::get_video_modes().len() == 0 && !::is_platform_windows) // Hiding resolution, mode, vsync.
  {
    local topBlockId = "sysopt_top"
    if (topBlockId in guiScene)
    {
      guiScene.replaceContentFromText(topBlockId, "", 0, handler)
      guiScene[topBlockId].height = 0
    }
  }

  configRead()
  local cb = "onSystemOptionChanged"
  foreach (section in mUiStruct)
  {
    if (! guiScene[section.container]) continue
    local isTable = ("items" in section)
    local ids = isTable ? section.items : [ section.id ]
    local data = ""
    foreach (id in ids)
    {
      local desc = getOptionDesc(id)
      if (!(desc?.isVisible() ?? true))
        continue

      desc.widgetId = "sysopt_" + id
      local option = ""
      switch (desc.widgetType)
      {
        case "checkbox":
          local config = {
            id = desc.widgetId
            value = mCfgCurrent[id]
            cb = cb
          }
          option = ::create_option_switchbox(config)
          break
        case "slider":
          desc.step <- desc?.step ?? ::max(1, ::round((desc.max - desc.min) / mMaxSliderSteps).tointeger())
          option = ::create_option_slider(desc.widgetId, mCfgCurrent[id], cb, true, "slider", desc)
          break
        case "list":
          option = getListOption(id, desc, cb)
          break
        case "tabs":
          local raw = desc.values.indexof(mCfgCurrent[id]) ?? -1
          local items = []
          foreach (valueId in desc.values)
          {
            local warn = ::loc(format("options/%s_%s/comment", id, valueId), "")
            warn = warn.len() ? ("\n" + ::colorize("badTextColor", warn)) : ""

            items.append({
              text = localize(id, valueId)
              tooltip = ::loc(format("guiHints/%s_%s", id, valueId)) + warn
            })
          }
          option = ::create_option_row_listbox(desc.widgetId, items, raw, cb, isTable)
          break
        case "editbox":
          local raw = mCfgCurrent[id].tostring()
          option = ::create_option_editbox({
            id = desc.widgetId,
            value = raw,
            maxlength = desc.maxlength
          })
          break
      }

      if (isTable)
      {
        local enable = (desc?.enabled() ?? true) ? "yes" : "no"
        local requiresRestart = ::getTblValue("restart", desc, false)
        local tooltipExtra = desc?.tooltipExtra ?? ""
        local optionName = ::loc($"options/{id}")
        local label = ::g_string.stripTags("".join([optionName, requiresRestart ? $"{::nbsp}*" : $"{::nbsp}{::nbsp}"]))
        local tooltip = ::g_string.stripTags("\n".join(
          [ ::loc($"guiHints/{id}", optionName),
            requiresRestart ? ::colorize("warningTextColor", ::loc("guiHints/restart_required")) : "",
            tooltipExtra
          ], true)
        )
        option = "tr { id:t='" + id + "_tr'; enable:t='" + enable +"' selected:t='no' size:t='pw, " + mRowHeightScale + "@baseTrHeight' overflow:t='hidden' tooltip:t=\"" + tooltip + "\";"+
          " td { width:t='0.5pw'; cellType:t='left'; overflow:t='hidden'; height:t='" + mRowHeightScale + "@baseTrHeight' optiontext {text:t='" + label + "'} }" +
          " td { width:t='0.5pw'; cellType:t='right';  height:t='" + mRowHeightScale + "@baseTrHeight' padding-left:t='@optPad'; " + option + " } }"
      }

      data += option
    }

    guiScene.replaceContentFromText(section.container, data, data.len(), handler)
  }

  guiScene.setUpdatesEnabled(true, true)
  onGuiLoaded()
}
//------------------------------------------------------------------------------
init()
::cross_call_api.sysopt <- { getGuiValue = getGuiValue }
//------------------------------------------------------------------------------
return {
  fillSystemGuiOptions = fillGuiOptions
  onSystemGuiOptionChanged = onGuiOptionChanged
  onRestartClient = onRestartClient
  getVideoModes = mShared.getVideoModes
  isCompatibiliyMode = isCompatibiliyMode
  onSystemOptionsApply = onConfigApply
  canUseGraphicsOptions = canUseGraphicsOptions
  systemOptionsMaintain = configMaintain
}