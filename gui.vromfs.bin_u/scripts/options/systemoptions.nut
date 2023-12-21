#default:allow-switch-statement
//-file:plus-string
from "%scripts/dagui_natives.nut" import get_dgs_tex_quality, is_dlss_quality_available_at_resolution, is_hdr_available, is_perf_metrics_available, is_xess_quality_available_at_resolution, is_low_latency_available, get_config_name, is_gpu_nvidia, get_video_modes
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

let DataBlock = require("DataBlock")
let { round } = require("math")
let { format, strip } = require("string")
let regexp2 = require("regexp2")
let { is_stereo_configured, configure_stereo } = require("vr")
let applyRendererSettingsChange = require("%scripts/clientState/applyRendererSettingsChange.nut")
let { setBlkValueByPath, getBlkValueByPath, blkOptFromPath } = require("%globalScripts/dataBlockExt.nut")
let { get_primary_screen_info } = require("dagor.system")
let { was_screenshot_applied_to_config } = require("debug.config")
let { eachBlock } = require("%sqstd/datablock.nut")
let { applyRestartClient, canRestartClient
} = require("%scripts/utils/restartClient.nut")
let { stripTags } = require("%sqstd/string.nut")
let { create_option_switchbox } = require("%scripts/options/optionsExt.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")

//------------------------------------------------------------------------------
local mSettings = {}
local mShared = {}
local mSkipUI = false
local mBlk = null
local mHandler = null
local mContainerObj = null
let mCfgStartup = {}
local mCfgApplied = {}
local mCfgInitial = {}
local mCfgCurrent = {}
local mScriptValid = true
local mValidationError = ""
local mMaintainDone = false
const mRowHeightScale = 1.0
const mMaxSliderSteps = 50
//-------------------------------------------------------------------------------
let mQualityPresets = DataBlock()
mQualityPresets.load("%guiConfig/graphicsPresets.blk")

/*
compMode - When TRUE, option is enabled in GUI when Compatibility Mode is ON.
           Defaults to FALSE for qualityPresetsOptions, and TRUE for standaloneOptions.
fullMode - When TRUE, Option is enabled in GUI when Compatibility Mode is OFF.
           Defaults to TRUE for both qualityPresetsOptions and standaloneOptions.
*/
let compModeGraphicsOptions = {
  qualityPresetsOptions = {
    texQuality        = { compMode = true }
    anisotropy        = { compMode = true }
    dirtSubDiv        = { compMode = true }
    tireTracksQuality = { compMode = true }
    msaa              = { compMode = true, fullMode = false }
    lastClipSize      = { compMode = true }
    compatibilityMode = { compMode = true }
    riGpuObjects      = { fullMode = false }
    compatibilityShadowQuality = { compMode = true, fullMode = false }
  }
  standaloneOptions = {
    xess              = { compMode = false }
    dlss              = { compMode = false }
    dlssSharpness     = { compMode = false }
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
      "xess"
      "dlss"
      "dlssSharpness"
      "anisotropy"
      "msaa"
      "antialiasing"
      "taau_ratio"
      "ssaa"
      "latency"
      "perfMetrics"
      "texQuality"
      "shadowQuality"
      "compatibilityShadowQuality"
      "fxResolutionQuality"
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
      "waterEffectsQuality"
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
      "mirrorQuality"
      "rendinstGlobalShadows"
      "staticShadowsOnEffects"
      "advancedShore"
      "haze"
      "lastClipSize"
      "lenseFlares"
      "enableSuspensionAnimation"
      "alpha_to_coverage"
      "jpegShots"
      "compatibilityMode"
      "enableHdr"
      "enableVr"
      "vrMirror"
      "vrStreamerMode"
    ]
  }
]

let perfValues = [
  "off",
  "fps",
  "compact",
  "full"
  // append new values to the end to keep original indexes consistent
]
//------------------------------------------------------------------------------
let getGuiValue = @(id, defVal = null) (id in mCfgCurrent) ? mCfgCurrent[id] : defVal

let function logError(from = "", msg = "") {
  let fullMsg = $"[sysopt] ERROR {from}: {msg}"
  log(fullMsg)
  return fullMsg
}

let function getOptionDesc(id) {
  if (!(id in mSettings)) {
    logError("sysopt.getOptionDesc()", $"Option '{id}' is UNKNOWN. It must be added to sysopt.settings table.")
    return null
  }
  return mSettings[id]
}

let function configValueToGuiValue(id, value) {
  let desc = getOptionDesc(id)
  return desc?.configValueToGuiValue(value) ?? value
}

let function validateGuiValue(id, value) {
  if (!is_platform_pc)
    return value

  let desc = getOptionDesc(id)
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

let function getGuiWidget(id) {
  if (!(id in mSettings)) {
    logError("sysopt.getGuiWidget()", $"Option '{id}' is UNKNOWN. It must be added to sysopt.settings table.")
    return null
  }

  let widgetId = getOptionDesc(id)?.widgetId
  let obj = (widgetId && checkObj(mContainerObj)) ? mContainerObj.findObject(widgetId) : null
  return checkObj(obj) ? obj : null
}

local function setGuiValue(id, value, skipUI = false) {
  value = validateGuiValue(id, value)
  mCfgCurrent[id] = value

  let obj = (skipUI || mSkipUI) ? null : getGuiWidget(id)
  if (obj) {
    let desc = getOptionDesc(id)
    local raw = null
    switch (desc.widgetType) {
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

local function setValue(id, value, skipUI = false) {
  setGuiValue(id, configValueToGuiValue(id, value), skipUI)
}

let function enableGuiOption(id, state) {
  if (mSkipUI)
    return
  let rowObj = checkObj(mContainerObj) ? mContainerObj.findObject(id + "_tr") : null
  if (checkObj(rowObj))
    rowObj.enable(state)
}

let function checkChanges(config1, config2) {
  let changes = {
    needSave = false
    needClientRestart = false
    needEngineReload = false
  }

  foreach (id, desc in mSettings) {
    let value1 = config1[id]
    let value2 = config2[id]
    if (value1 != value2) {
      changes.needSave = true

      let needApply = id != "graphicsQuality"
      if (needApply) {
        let requiresRestart = getTblValue("restart", desc)
        if (requiresRestart)
          changes.needClientRestart = true
        else
          changes.needEngineReload = true
      }
    }
  }

  return changes
}

let isRestartPending = @() checkChanges(mCfgStartup, mCfgCurrent).needClientRestart

let isHotReloadPending = @() checkChanges(mCfgApplied, mCfgCurrent).needEngineReload

let isSavePending = @() checkChanges(mCfgInitial, mCfgCurrent).needSave

let canUseGraphicsOptions = @() is_platform_pc && hasFeature("GraphicsOptions")
let canShowGpuBenchmark = @() canUseGraphicsOptions() && platformId != "macosx"

let function updateGuiNavbar(show = true) {
  let scene = mHandler?.scene
  if (!checkObj(scene))
    return

  let showText = show && isRestartPending()
  let showRestartButton = showText && canRestartClient()
  let applyText = loc((show && !showRestartButton && isHotReloadPending()) ? "mainmenu/btnApply" : "mainmenu/btnOk")

  showObjById("btn_reset", show && isSavePending(), scene)
  showObjById("restart_suggestion", showText, scene)
  showObjById("btn_restart", showRestartButton, scene)
  showObjById("btn_gpu_benchmark", show && canShowGpuBenchmark(), scene)

  let objNavbarApplyButton = scene.findObject("btn_apply")
  if (checkObj(objNavbarApplyButton))
    objNavbarApplyButton.setValue(applyText)
}

let function pickQualityPreset() {
  local preset = "custom"
  mSkipUI = true
  let _cfgCurrent = mCfgCurrent
  let graphicsQualityDesc = getOptionDesc("graphicsQuality")
  foreach (presetId in graphicsQualityDesc.values) {
    if (presetId == "custom")
      continue
    mCfgCurrent = {}
    foreach (id, value in _cfgCurrent)
      mCfgCurrent[id] <- value
    mCfgCurrent["graphicsQuality"] = presetId
    mShared.graphicsQualityClick(true)
    let changes = checkChanges(mCfgCurrent, _cfgCurrent)
    if (!changes.needClientRestart && !changes.needEngineReload) {
      preset = presetId
      break
    }
  }
  mCfgCurrent = _cfgCurrent
  mSkipUI = false

  return preset
}

let function localizaQualityPreset(presetName) {
  let txt = (presetName == "ultralow" || presetName == "min") ? "ultra_low"
    : presetName == "ultrahigh" ? "ultra_high"
    : presetName
  return loc($"options/quality_{txt}")
}

let function localize(optionId, valueId) {
  switch (optionId) {
    case "resolution": {
      if (valueId == "auto")
        return loc("options/auto")
      else
        return valueId
    }
    case "anisotropy":
    case "ssaa":
    case "msaa":
      return loc("options/" + valueId)
    case "graphicsQuality":
    case "texQuality":
    case "shadowQuality":
    case "waterEffectsQuality":
    case "compatibilityShadowQuality":
    case "fxResolutionQuality":
    case "tireTracksQuality":
    case "waterQuality":
    case "giQuality":
    case "dirtSubDiv":
      if (valueId == "none")
        return loc("options/none")
      return localizaQualityPreset(valueId)
  }
  return loc(format("options/%s_%s", optionId, valueId), valueId)
}

let function parseResolution(resolution) {
  let sides = resolution == "auto"
    ? [ 0, 0 ] // To be sorted first.
    : resolution.split("x").apply(@(v) to_integer_safe(strip(v), 0, false))
  return {
    resolution = resolution
    w = sides?[0] ?? 0
    h = sides?[1] ?? 0
  }
}

let function getAvailableXessModes() {
  let values = ["off"]
  let selectedResolution = parseResolution(getGuiValue("resolution", "auto"))
  if (is_xess_quality_available_at_resolution(0, selectedResolution.w, selectedResolution.h))
    values.append("performance")
  if (is_xess_quality_available_at_resolution(1, selectedResolution.w, selectedResolution.h))
    values.append("balanced")
  if (is_xess_quality_available_at_resolution(2, selectedResolution.w, selectedResolution.h))
    values.append("quality")
  if (is_xess_quality_available_at_resolution(3, selectedResolution.w, selectedResolution.h))
    values.append("ultra_quality")

  return values;
}

let function getAvailableDlssModes() {
  let values = ["off"]
  let selectedResolution = parseResolution(getGuiValue("resolution", "auto"))
  if (is_dlss_quality_available_at_resolution(0, selectedResolution.w, selectedResolution.h))
    values.append("performance")
  if (is_dlss_quality_available_at_resolution(1, selectedResolution.w, selectedResolution.h))
    values.append("balanced")
  if (is_dlss_quality_available_at_resolution(2, selectedResolution.w, selectedResolution.h))
    values.append("quality")

  return values;
}

let function getAvailableLatencyModes() {
  let values = ["off"]
  if (is_low_latency_available(1))
    values.append("on")
  if (is_low_latency_available(2))
    values.append("boost")

  return values;
}

let getAvailablePerfMetricsModes = @() perfValues.filter(@(_, id) id <= 1 || is_perf_metrics_available(id))

let function getListOption(id, desc, cb, needCreateList = true) {
  let raw = desc.values.indexof(mCfgCurrent[id]) ?? -1
  let customItems = ("items" in desc) ? desc.items : null
  let items = []
  foreach (index, valueId in desc.values)
    items.append(customItems ? customItems[index] : localize(id, valueId))
  return ::create_option_combobox(desc.widgetId, items, raw, cb, needCreateList)
}

//------------------------------------------------------------------------------
mShared = {
  setQualityPreset = function(preset) {
    eachBlock(mQualityPresets, function(v, k) {
      let value = v?[preset] ?? v?["medium"]
      if (value != null)
        setValue(k, value)
    })
  }

  setGraphicsQuality = function() {
    local quality = getGuiValue("graphicsQuality", "high")
    if (mQualityPresets?.texQuality[quality] == null && quality != "custom") {
      quality = getGuiValue("compatibilityMode", false) ? "ultralow" : "high"
      setGuiValue("graphicsQuality", quality)
    }
    if (quality == "custom") {
      return
    }
    else
      mShared.setQualityPreset(quality)
  }

  enableByCompMode = function(id, enable) {
    let desc = getOptionDesc(id)
    let enabled = enable && (desc?.enabled() ?? true)
    enableGuiOption(id, enabled)
  }

  setCompatibilityMode = function() {
    if (getGuiValue("compatibilityMode")) {
      setGuiValue("backgroundScale", 2)
      eachBlock(mQualityPresets, function(_, k) {
        let enabled = compModeGraphicsOptions.qualityPresetsOptions?[k].compMode ?? false
        mShared.enableByCompMode(k, enabled)
      })
      foreach (id, v in compModeGraphicsOptions.standaloneOptions)
        mShared.enableByCompMode(id, v?.compMode ?? true)
    }
    else {
      eachBlock(mQualityPresets, function(_, k) {
        let enabled = compModeGraphicsOptions.qualityPresetsOptions?[k].fullMode ?? true
        mShared.enableByCompMode(k, enabled)
      })
      foreach (id, v in compModeGraphicsOptions.standaloneOptions)
        mShared.enableByCompMode(id, v?.fullMode ?? true)
      setGuiValue("compatibilityMode", false)
    }
  }

  setLandquality = function() {
    let lq = getGuiValue("landquality")
    let cs = (lq == 0) ? 50 : (lq == 4) ? 150 : 100
    setGuiValue("clipmapScale", cs)
  }

  landqualityClick = @() mShared.setLandquality()

  setCustomSettings = function() {
    mShared.setGraphicsQuality()
    mShared.setLandquality()
    mShared.setCompatibilityMode()
  }

  graphicsQualityClick = function(silent = false) {
    let quality = getGuiValue("graphicsQuality", "high")
    if (!silent && quality == "ultralow") {
      let function ok_func() {
        mShared.graphicsQualityClick(true)
        updateGuiNavbar(true)
      }
      let function cancel_func() {
        let lowQuality = "low"
        setGuiValue("graphicsQuality", lowQuality)
        mShared.graphicsQualityClick()
        updateGuiNavbar(true)
      }
      scene_msg_box("msg_sysopt_compatibility", null,
        loc("msgbox/compatibilityMode"),
        [
          ["yes", ok_func],
          ["no", cancel_func],
        ], "no",
        { cancel_fn = cancel_func, checkDuplicateId = true })
    }
    mShared.setCustomSettings()
  }

  presetCheck = function() {
    let preset = pickQualityPreset()
    setGuiValue("graphicsQuality", preset)
  }

  resolutionClick = function() {
    let id = "dlss"
    let desc = getOptionDesc(id)
    if (!desc)
      return

    desc.init(null, desc) //list of dlss values depends only on resolution
    setGuiValue(id, desc.values.indexof(getGuiValue(id)) ?? desc.def, true)
    let obj = getGuiWidget(id)
    if (!checkObj(obj))
      return

    let markup = getListOption(id, desc, "onSystemOptionChanged", false)
    mContainerObj.getScene().replaceContentFromText(obj, markup, markup.len(), mHandler)
  }

  dlssClick = function() {
    foreach (id in [ "antialiasing", "xess", "ssaa", "dlssSharpness" ])
      enableGuiOption(id, getOptionDesc(id)?.enabled() ?? true)
  }

  xessClick = function() {
    foreach (id in [ "antialiasing", "dlss", "ssaa", "dlssSharpness" ])
      enableGuiOption(id, getOptionDesc(id)?.enabled() ?? true)
  }

  latencyClick = function() {
    let latencyMode = getGuiValue("latency", "off")
    if (latencyMode == "on" || latencyMode == "boost") {
      setGuiValue("vsync", false)
    }
    enableGuiOption("vsync", getOptionDesc("vsync")?.enabled() ?? true)
  }

  cloudsQualityClick = function() {
    let cloudsQualityVal = getGuiValue("cloudsQuality", 1)
    setGuiValue("skyQuality", cloudsQualityVal == 0 ? 0 : 1)
  }

  ssaoQualityClick = function() {
    if (getGuiValue("ssaoQuality") == 0) {
      setGuiValue("ssrQuality", 0)
      setGuiValue("contactShadowsQuality", 0)
    }
  }

  ssrQualityClick = function() {
    if ((getGuiValue("ssrQuality") > 0) && (getGuiValue("ssaoQuality") == 0))
      setGuiValue("ssaoQuality", 1)
  }

  contactShadowsQualityClick = function() {
    if (getGuiValue("contactShadowsQuality") > 0 && getGuiValue("ssaoQuality") == 0)
      setGuiValue("ssaoQuality", 1)
  }

  antiAliasingClick = function() {
    if (getGuiValue("antialiasing") == "low_taa") {
      setGuiValue("backgroundScale", 1.0)
      enableGuiOption("backgroundScale", false)
      enableGuiOption("taau_ratio", true)
    }
    else {
      enableGuiOption("backgroundScale", true)
      enableGuiOption("taau_ratio", false)
    }
  }

  ssaaClick = function() {
    if (getGuiValue("ssaa") == "4X") {
      let function okFunc() {
        setGuiValue("backgroundScale", 2)
        mShared.presetCheck()
        updateGuiNavbar(true)
      }
      let function cancelFunc() {
        setGuiValue("ssaa", "none")
        mShared.presetCheck()
        updateGuiNavbar(true)
      }
      scene_msg_box("msg_sysopt_ssaa", null, loc("msgbox/ssaa_warning"),
        [
          ["ok", okFunc],
          ["cancel", cancelFunc],
        ], "cancel",
        { cancel_fn = cancelFunc, checkDuplicateId = true })
    }
  }

  fxResolutionClick = function() {
    if (getGuiValue("fxResolutionQuality") == "ultrahigh") {
      let function okFunc() {
        setGuiValue("fxResolutionQuality", "ultrahigh")
        mShared.presetCheck()
        updateGuiNavbar(true)
      }
      let function cancelFunc() {
        setGuiValue("fxResolutionQuality", "high")
        mShared.presetCheck()
        updateGuiNavbar(true)
      }
      scene_msg_box("msg_sysopt_fxres", null,
        loc("msgbox/fxres_warning"),
        [
          ["ok", okFunc],
          ["cancel", cancelFunc],
        ], "cancel",
        { cancel_fn = cancelFunc, checkDuplicateId = true })
    }
  }

  compatibilityModeClick = function() {
    let isEnable = getGuiValue("compatibilityMode")
    if (isEnable) {
      let function ok_func() {
        mShared.setCompatibilityMode()
        mShared.presetCheck()
        updateGuiNavbar(true)
      }
      let function cancel_func() {
        setGuiValue("compatibilityMode", false)
        mShared.setCompatibilityMode()
        mShared.presetCheck()
        updateGuiNavbar(true)
      }
      scene_msg_box("msg_sysopt_compatibility", null,
        loc("msgbox/compatibilityMode"),
        [
          ["yes", ok_func],
          ["no", cancel_func],
        ], "no",
        { cancel_fn = cancel_func, checkDuplicateId = true })
    }
    else
      mShared.setCompatibilityMode()
  }

  getVideoModes = function(curResolution = null, isNeedAuto = true) {
    let minW = 1024
    let minH = 720

    let list = get_video_modes()
    let isListTruncated = list.len() <= 1
    if (isNeedAuto)
      list.append("auto")
    if (curResolution != null && list.indexof(curResolution) == null)
      list.append(curResolution)

    let data = list.map(parseResolution).filter(@(r)
      (r.w >= minW && r.h >= minH) || r.resolution == curResolution || r.resolution == "auto")

    let sortFunc = @(a, b) a.w <=> b.w  || a.h <=> b.h
    data.sort(sortFunc)

    // Fixing the truncated list when working via Remote Desktop (RDP).
    // get_primary_screen_info implemented only for windows and macosx platforms
    if (isListTruncated && (is_platform_windows || platformId == "macosx")) {
      let resolutions = [ "1024 x 768", "1280 x 720", "1280 x 1024",
        "1920 x 1080", "2520 x 1080", "2560 x 1440", "3840 x 1080", "3840 x 2160" ]
      local psi = {}
      try{
        psi = get_primary_screen_info()
      }
      catch(e) {
        log("get_primary_screen_info is not implemented?", e)
      }
      let maxW = psi?.pixelsWidth  ?? data?[data.len() - 1].w ?? 1024
      let maxH = psi?.pixelsHeight ?? data?[data.len() - 1].h ?? 768
      u.appendOnce($"{maxW} x {maxH}", resolutions)
      let bonus = resolutions.map(parseResolution).filter(@(r)
        (r.w <= maxW && r.h <= maxH) && !list.contains(r.resolution))
      data.extend(bonus)
      data.sort(sortFunc)
    }

    return data.map(@(r) r.resolution)
  }

  getCurResolution = function(blk, desc) {
    let modes = mShared.getVideoModes(null)
    let value = getBlkValueByPath(blk, desc.blk, "")

    let isListed = modes.indexof(value) != null
    if (isListed) // Supported system.
      return value

    let looksReliable = regexp2(@"^\d+ x \d+$").match(value)
    if (looksReliable) // Unsupported system. Or maybe altered by user, but somehow works.
      return value

    if (value == "auto")
      return value

    let screen = format("%d x %d", screen_width(), screen_height())
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
  def - default value in UI (it is not required, if there are getValueFromConfig/setGuiValueToConfig functions).
  blk - path to variable in config.blk file structure (it is not required, if there are getValueFromConfig/setGuiValueToConfig functions).
  restart - client restart is required to apply an option (e.g. no support in Renderer::onSettingsChanged() function).
  values - for string variables only, list of possible variable values in UI (for dropdown widget).
  items - optional, for string variables only, list of item titles in UI (for dropdown widget).
  min, max - for integer variables only, minimum and maximum variable values in UI (for slider widget).
  maxlength - for string/integer/float variables only, maximum variable value input length (for input field widget).
  onChanged - function, reaction to user changes in UI. This function can change multiple variables in UI.
  getValueFromConfig - function, imports value from config.blk, returns value in config format.
  setGuiValueToConfig - function, accepts value in UI format and exports it to BLK. Can change multiple variables in BLK.
  configValueToGuiValue - function, accepts value in config format and return value in UI format
  init - function, initializes the variable config section, for example, defines 'def' value and/or 'values' list.
  tooltipExtra - optional, text to be added to option tooltip.
  isVisible - function, for hide options
*/
mSettings = {
  resolution = { widgetType = "list" def = "1024 x 768" blk = "video/resolution" restart = true
    init = function(blk, desc) {
      let curResolution = mShared.getCurResolution(blk, desc)
      desc.values <- mShared.getVideoModes(curResolution)
      desc.def <- curResolution
      desc.restart <- !is_platform_windows
    }
    onChanged = "resolutionClick"
  }
  mode = { widgetType = "list" def = "fullscreenwindowed" blk = "video/mode" restart = true
    init = function(_blk, desc) {
      desc.values <- is_platform_windows
        ? ["windowed", "fullscreenwindowed", "fullscreen"]
        : ["windowed", "fullscreen"]
      desc.def = desc.values.top()
      desc.restart <- !is_platform_windows
    }
    setGuiValueToConfig = function(blk, desc, val) {
      setBlkValueByPath(blk, desc.blk, val)
      setBlkValueByPath(blk, "video/windowed", val == "windowed")
    }
  }
  vsync = { widgetType = "list" def = "vsync_off" blk = "video/vsync" restart = true
    getValueFromConfig = function(blk, _desc) {
      let vsync = getBlkValueByPath(blk, "video/vsync", false)
      let adaptive = is_gpu_nvidia() && getBlkValueByPath(blk, "video/adaptive_vsync", true)
      return (vsync && adaptive) ? "vsync_adaptive" : (vsync) ? "vsync_on" : "vsync_off"
    }
    setGuiValueToConfig = function(blk, _desc, val) {
      setBlkValueByPath(blk, "video/vsync", val != "vsync_off")
      setBlkValueByPath(blk, "video/adaptive_vsync", val == "vsync_adaptive")
    }
    init = function(_blk, desc) {
      desc.values <- is_gpu_nvidia() ? [ "vsync_off", "vsync_on", "vsync_adaptive" ] : [ "vsync_off", "vsync_on" ]
    }
    enabled = @() getGuiValue("latency", "off") != "on" && getGuiValue("latency", "off") != "boost"
  }
  graphicsQuality = { widgetType = "tabs" def = "high" blk = "graphicsQuality" restart = false
    values = [ "ultralow", "low", "medium", "high", "max", "movie", "custom" ]
    onChanged = "graphicsQualityClick"
  }
  xess = { widgetType = "list" def = "off" blk = "video/xessQuality" restart = false
    init = function(_blk, desc) {
      desc.values <- getAvailableXessModes()
    }
    onChanged = "xessClick"
    getValueFromConfig = function(blk, desc) {
      return getBlkValueByPath(blk, desc.blk, -1)
    }
    setGuiValueToConfig = function(blk, desc, val) {
      let quality = (val == "performance") ? 0 : (val == "balanced") ? 1 : (val == "quality") ? 2 : (val == "ultra_quality") ? 3 : -1
      setBlkValueByPath(blk, desc.blk, quality)
    }
    configValueToGuiValue = function(val) {
      return (val == 0) ? "performance" : (val == 1) ? "balanced" : (val == 2) ? "quality" : (val == 3) ? "ultra_quality" : "off"
    }
  }
  dlss = { widgetType = "list" def = "off" blk = "video/dlssQuality" restart = false
    init = function(_blk, desc) {
      desc.values <- getAvailableDlssModes()
    }
    onChanged = "dlssClick"
    getValueFromConfig = function(blk, desc) {
      return getBlkValueByPath(blk, desc.blk, -1)
    }
    setGuiValueToConfig = function(blk, desc, val) {
      let quality = (val == "performance") ? 0 : (val == "balanced") ? 1 : (val == "quality") ? 2 : -1
      setBlkValueByPath(blk, desc.blk, quality)
    }
    configValueToGuiValue = function(val) {
      return (val == 0) ? "performance" : (val == 1) ? "balanced" : (val == 2) ? "quality" : "off"
    }
  }
  dlssSharpness = { widgetType = "slider" def = 0 min = 0 max = 100 blk = "video/dlssSharpness" restart = false
    enabled = @() getGuiValue("dlss", "off") != "off"
  }
  anisotropy = { widgetType = "list" def = "2X" blk = "graphics/anisotropy" restart = true
    values = [ "off", "2X", "4X", "8X", "16X" ]
    getValueFromConfig = function(blk, desc) {
      return getBlkValueByPath(blk, desc.blk, 2)
    }
    setGuiValueToConfig = function(blk, desc, val) {
      let anis = (val == "16X") ? 16 : (val == "8X") ? 8 : (val == "4X") ? 4 : (val == "2X") ? 2 : 1
      setBlkValueByPath(blk, desc.blk, anis)
    }
    configValueToGuiValue = function(val) {
      if (val == 1)
        return "off"
      let strVal = val.tostring()
      return "".concat(strVal, "X")
    }
  }
  msaa = { widgetType = "list" def = "off" blk = "directx/maxaa" restart = true
    values = [ "off", "on"]
    configValueToGuiValue = function(val) {
      return (val > 0)?"on":"off"
    }
    getValueFromConfig = function(blk, desc) {
      return getBlkValueByPath(blk, desc.blk, 0)
    }
    setGuiValueToConfig = function(blk, desc, val) {
      let msaa = (val == "on") ? 2 : 0
      setBlkValueByPath(blk, desc.blk, msaa)
    }
  }
  antialiasing = { widgetType = "list" def = "none" blk = "video/postfx_antialiasing" restart = false
  getValueFromConfig = function(blk, desc) {
    let antiAliasing = getBlkValueByPath(blk, desc.blk, "none")
    return (antiAliasing == "high_taa") ? "low_taa" : antiAliasing
  }
    onChanged = "antiAliasingClick"
    values = [ "none", "fxaa", "high_fxaa", "low_taa"]
    enabled = @() !getGuiValue("compatibilityMode") && getGuiValue("dlss", "off") == "off" && getGuiValue("xess", "off") == "off"
  }
  taau_ratio = { widgetType = "slider" def = 100 min = 50 max = 100 blk = "video/temporalResolutionScale" restart = false
    enabled = @() !getGuiValue("compatibilityMode")
                  && (getGuiValue("antialiasing") == "low_taa")
    getValueFromConfig = function(blk, desc) { return getBlkValueByPath(blk, desc.blk, desc.def / 100.0) }
    setGuiValueToConfig = function(blk, desc, val) { setBlkValueByPath(blk, desc.blk, val.tofloat() / 100.0) }
    configValueToGuiValue = @(val) (val * 100.0).tointeger()
  }
  ssaa = { widgetType = "list" def = "none" blk = "graphics/ssaa" restart = false
    values = [ "none", "4X" ]
    enabled = @() !getGuiValue("compatibilityMode") && getGuiValue("dlss", "off") == "off" && getGuiValue("xess", "off") == "off"
    onChanged = "ssaaClick"
    getValueFromConfig = function(blk, desc) {
      return getBlkValueByPath(blk, desc.blk, 1.0)
    }
    setGuiValueToConfig = function(blk, desc, val) {
      let res = (val == "4X") ? 4.0 : 1.0
      setBlkValueByPath(blk, desc.blk, res)
    }
    configValueToGuiValue = @(val) (val == 4.0) ? "4X" : "none"
  }
  latency = { widgetType = "list" def = "off" blk = "video/latency" restart = false
    init = function(_blk, desc) {
      desc.values <- getAvailableLatencyModes()
      desc.items <- desc.values.map(@(value) { text = localize("latency", value), tooltip = loc($"guiHints/latency_{value}") })
    }
    getValueFromConfig = function(blk, desc) {
      return getBlkValueByPath(blk, desc.blk, -1)
    }
    setGuiValueToConfig = function(blk, desc, val) {
      let quality = (val == "on") ? 1 : (val == "boost") ? 2 : (val == "experimental") ? 4 : 0
      setBlkValueByPath(blk, desc.blk, quality)
    }
    configValueToGuiValue = function(val) {
      return (val == 1) ? "on" : (val == 2) ? "boost" : (val == 4) ? "experimental" : "off"
    }
    onChanged = "latencyClick"
  }
  perfMetrics = { widgetType = "list" def = "fps" blk = "video/perfMetrics" restart = false
    init = function(_blk, desc) {
      desc.values <- getAvailablePerfMetricsModes()
    }
    function getValueFromConfig(blk, desc) {
      let mode = getBlkValueByPath(blk, desc.blk, -1)
      return perfValues?[mode] ?? desc.def
    }
    function setGuiValueToConfig(blk, desc, val) {
      // -1 will use the default value when loaded
      setBlkValueByPath(blk, desc.blk, perfValues.findindex(@(name) name == val) ?? -1)
    }
  }
  texQuality = { widgetType = "list" def = "high" blk = "graphics/texquality" restart = true
    init = function(_blk, desc) {
      let dgsTQ = get_dgs_tex_quality() // 2=low, 1-medium, 0=high.
      let configTexQuality = desc.values.indexof(::getSystemConfigOption("graphics/texquality", "high")) ?? -1
      let sysTexQuality = [2, 1, 0].indexof(dgsTQ) ?? configTexQuality
      if (sysTexQuality == configTexQuality)
        return

      let restrictedValueName = localize("texQuality", desc.values[sysTexQuality])
      let restrictedValueItem = {
        text = colorize("badTextColor", restrictedValueName + " **")
        textStyle = "textStyle:t='textarea';"
      }
      desc.items <- []
      foreach (index, item in desc.values)
        desc.items.append((index <= sysTexQuality) ? localize("texQuality", item) : restrictedValueItem)
      desc.tooltipExtra <- colorize("badTextColor", "** " + loc("msgbox/graphicsOptionValueReduced/lowVideoMemory",
        { name = loc("options/texQuality"), value = restrictedValueName }))
    }
    values = [ "low", "medium", "high" ]
  }
  shadowQuality = { widgetType = "list" def = "high" blk = "graphics/shadowQuality" restart = false
    values = [ "ultralow", "low", "medium", "high", "ultrahigh" ]
  }
  waterEffectsQuality = { widgetType = "list" def = "high" blk = "graphics/waterEffectsQuality" restart = false
    values = [ "low", "medium", "high" ]
  }
  compatibilityShadowQuality = { widgetType = "list" def = "low" blk = "graphics/compatibilityShadowQuality" restart = false
    values = [ "low", "medium" ]
  }
  fxResolutionQuality = { widgetType = "list" def = "high" blk = "graphics/fxTarget" restart = false
    onChanged = "fxResolutionClick"
    values = [ "low", "medium", "high", "ultrahigh" ]
  }
  selfReflection = { widgetType = "checkbox" def = true blk = "render/selfReflection" restart = false
  }
  backgroundScale = { widgetType = "slider" def = 2 min = 0 max = 2 blk = "graphics/backgroundScale" restart = false
    blkValues = [ 0.7, 0.85, 1.0 ]
    getValueFromConfig = function(blk, desc) {
      return getBlkValueByPath(blk, desc.blk, 1.0)
    }
    enabled = @() getGuiValue("antialiasing") != "low_taa"
    setGuiValueToConfig = function(blk, desc, val) {
      local res = getTblValue(val, desc.blkValues, desc.def)
      if (getGuiValue("ssaa") == "4X" && !getGuiValue("compatibilityMode"))
        res = 2.0
      setBlkValueByPath(blk, desc.blk, res)
    }
    configValueToGuiValue = function(val) {
      if (getGuiValue("ssaa") == "4X" && !getGuiValue("compatibilityMode"))
        val = 2.0
      return ::find_nearest(val, this.blkValues)
    }
  }
  landquality = { widgetType = "slider" def = 0 min = 0 max = 4 blk = "graphics/landquality" restart = false
    onChanged = "landqualityClick"
  }
  clipmapScale = { widgetType = "slider" def = 100 min = 30 max = 150 blk = "graphics/clipmapScale" restart = false
    getValueFromConfig = function(blk, desc) { return getBlkValueByPath(blk, desc.blk, desc.def / 100.0) }
    setGuiValueToConfig = function(blk, desc, val) { setBlkValueByPath(blk, desc.blk, val / 100.0) }
    configValueToGuiValue = @(val) (val * 100).tointeger()
  }
  rendinstDistMul = { widgetType = "slider" def = 100 min = 50 max = 350 blk = "graphics/rendinstDistMul" restart = false
    getValueFromConfig = function(blk, desc) { return getBlkValueByPath(blk, desc.blk, desc.def / 100.0) }
    setGuiValueToConfig = function(blk, desc, val) { setBlkValueByPath(blk, desc.blk, val / 100.0) }
    configValueToGuiValue = @(val)(val * 100).tointeger()
  }
  skyQuality = { widgetType = "slider" def = 1 min = 0 max = 2 blk = "graphics/skyQuality" restart = false
    getValueFromConfig = function(blk, desc) { return getBlkValueByPath(blk, desc.blk, 2 - desc.def) }
    setGuiValueToConfig = function(blk, desc, val) { setBlkValueByPath(blk, desc.blk, 2 - val) }
    configValueToGuiValue = @(val)(2 - val).tointeger()
  }
  cloudsQuality = { widgetType = "slider" def = 1 min = 0 max = 2 blk = "graphics/cloudsQuality" restart = false
    onChanged = "cloudsQualityClick"
    getValueFromConfig = function(blk, desc) { return getBlkValueByPath(blk, desc.blk, 2 - desc.def) }
    setGuiValueToConfig = function(blk, desc, val) { setBlkValueByPath(blk, desc.blk, 2 - val) }
    configValueToGuiValue = @(val)(2 - val).tointeger()
  }
  panoramaResolution = { widgetType = "slider" def = 8 min = 4 max = 16 blk = "graphics/panoramaResolution" restart = false
    getValueFromConfig = function(blk, desc) { return getBlkValueByPath(blk, desc.blk, desc.def * 256) }
    setGuiValueToConfig = function(blk, desc, val) { setBlkValueByPath(blk, desc.blk, val * 256) }
    configValueToGuiValue = @(val)(val / 256).tointeger()
  }
  fxDensityMul = { widgetType = "slider" def = 100 min = 20 max = 100 blk = "graphics/fxDensityMul" restart = false
    getValueFromConfig = function(blk, desc) { return getBlkValueByPath(blk, desc.blk, desc.def / 100.0)}
    setGuiValueToConfig = function(blk, desc, val) { setBlkValueByPath(blk, desc.blk, val / 100.0) }
    configValueToGuiValue = @(val)(val * 100).tointeger()
  }
  physicsQuality = { widgetType = "slider" def = 3 min = 0 max = 5 blk = "graphics/physicsQuality" restart = false
  }
  grassRadiusMul = { widgetType = "slider" def = 80 min = 10 max = 180 blk = "graphics/grassRadiusMul" restart = false
    getValueFromConfig = function(blk, desc) { return getBlkValueByPath(blk, desc.blk, desc.def / 100.0) }
    setGuiValueToConfig = function(blk, desc, val) { setBlkValueByPath(blk, desc.blk, val / 100.0) }
    configValueToGuiValue = @(val)(val * 100).tointeger()
  }
  enableSuspensionAnimation = { widgetType = "checkbox" def = false blk = "graphics/enableSuspensionAnimation" restart = true
  }
  alpha_to_coverage = { widgetType = "checkbox" def = false blk = "video/alpha_to_coverage" restart = false
  }
  tireTracksQuality = { widgetType = "list" def = "none" blk = "graphics/tireTracksQuality" restart = false
    values = [ "none", "medium", "high", "ultrahigh" ]
    configValueToGuiValue = @(val) this.values[val]
    getValueFromConfig = function(blk, desc) {
      return getBlkValueByPath(blk, desc.blk, 0)
    }
    setGuiValueToConfig = function(blk, desc, val) {
      let res = desc.values.indexof(val) ?? 0
      setBlkValueByPath(blk, desc.blk, res)
    }
  }
  waterQuality = { widgetType = "list" def = "high" blk = "graphics/waterQuality" restart = false
    values = [ "low", "medium", "high", "ultrahigh" ]
  }
  giQuality = { widgetType = "list" def = "low" blk = "graphics/giQuality" restart = false
    values = [ "low", "medium", "high" ], isVisible = @() true
  }
  dirtSubDiv = { widgetType = "list" def = "high" blk = "graphics/dirtSubDiv" restart = false
    values = [ "high", "ultrahigh" ]
    getValueFromConfig = function(blk, desc) {
      return getBlkValueByPath(blk, desc.blk, 1)
    }
    setGuiValueToConfig = function(blk, desc, val) {
      let res = (val == "ultrahigh") ? 2 : 1
      setBlkValueByPath(blk, desc.blk, res)
    }
    configValueToGuiValue = @(val)(val == 2) ? "ultrahigh" : "high"
  }
  ssaoQuality = { widgetType = "slider" def = 0 min = 0 max = 2 blk = "render/ssaoQuality" restart = false
    onChanged = "ssaoQualityClick"
  }
  ssrQuality = { widgetType = "slider" def = 0 min = 0 max = 2 blk = "render/ssrQuality" restart = false
    onChanged = "ssrQualityClick"
  }
  shadows = { widgetType = "checkbox" def = true blk = "render/shadows" restart = false
  }
  rendinstGlobalShadows = { widgetType = "checkbox" def = true blk = "render/rendinstGlobalShadows" restart = false
  }
  advancedShore = { widgetType = "checkbox" def = false blk = "graphics/advancedShore" restart = false
  }
  mirrorQuality = { widgetType = "slider" def = 5 min = 0 max = 10 blk = "graphics/mirrorQuality" restart = false
  }
  haze = { widgetType = "checkbox" def = false blk = "render/haze" restart = false
  }
  lastClipSize = { widgetType = "checkbox" def = false blk = "graphics/lastClipSize" restart = false
    getValueFromConfig = function(blk, desc) { return getBlkValueByPath(blk, desc.blk, 4096) }
    setGuiValueToConfig = function(blk, desc, val) { setBlkValueByPath(blk, desc.blk, (val ? 8192 : 4096)) }
    configValueToGuiValue = @(val) val == 8192 ? true : false
  }
  lenseFlares = { widgetType = "checkbox" def = false blk = "graphics/lenseFlares" restart = false
  }
  jpegShots = { widgetType = "checkbox" def = true blk = "debug/screenshotAsJpeg" restart = false }
  compatibilityMode = { widgetType = "checkbox" def = false blk = "video/compatibilityMode" restart = true
    onChanged = "compatibilityModeClick"
  }
  enableHdr = { widgetType = "checkbox" def = false blk = (platformId == "macosx" ? "metal/enableHdr" : "directx/enableHdr") restart = true enabled = @() is_hdr_available() }
  enableVr = {
    widgetType = "checkbox"
    blk = "gameplay/enableVR"
    def = is_stereo_configured()
    getValueFromConfig = function(_blk, _desc) { return is_stereo_configured() }
    setGuiValueToConfig = function(blk, desc, val) {
      configure_stereo(val)
      return setBlkValueByPath(blk, desc.blk, val)
    }
    enabled = @() is_platform_windows && (platformId == "win64" || ::is_dev_version) && !getGuiValue("compatibilityMode")
  }
  vrMirror = { widgetType = "list" def = "left" blk = "video/vreye" restart = false values = [ "left", "right", "both" ]
  }
  vrStreamerMode = { widgetType = "checkbox" def = false blk = "video/vrStreamerMode" restart = false
  }
  displacementQuality = { widgetType = "slider" def = 2 min = 0 max = 3 blk = "graphics/displacementQuality" restart = false
  }
  contactShadowsQuality = { widgetType = "slider" def = 0 min = 0 max = 2 blk = "graphics/contactShadowsQuality" restart = false
    onChanged = "contactShadowsQualityClick"
  }
  staticShadowsOnEffects = { widgetType = "checkbox" def = false blk = "render/staticShadowsOnEffects" restart = false
  }
  riGpuObjects = { widgetType = "checkbox" def = true blk = "graphics/riGpuObjects" restart = false
  }
}
//------------------------------------------------------------------------------
let function validateInternalConfigs() {
  let errorsList = []
  foreach (id, desc in mSettings) {
    let widgetType = getTblValue("widgetType", desc)
    if (!isInArray(widgetType, ["list", "slider", "checkbox", "editbox", "tabs"]))
      errorsList.append(logError("sysopt.validateInternalConfigs()",
        "Option '" + id + "' - 'widgetType' invalid or undefined."))
    if ((!("blk" in desc) || type(desc.blk) != "string" || !desc.blk.len()) && (!("getValueFromConfig" in desc) || !("setGuiValueToConfig" in desc)))
      errorsList.append(logError("sysopt.validateInternalConfigs()",
        "Option '" + id + "' - 'blk' invalid or undefined. It can be undefined only when both getValueFromConfig & setGuiValueToConfig are defined."))
    if (("onChanged" in desc) && type(desc.onChanged) != "function")
      errorsList.append(logError("sysopt.validateInternalConfigs()",
        "Option '" + id + "' - 'onChanged' function not found in sysopt.shared."))

    let def = getTblValue("def", desc)
    if (def == null)
      errorsList.append(logError("sysopt.validateInternalConfigs()",
        "Option '" + id + "' - 'def' undefined."))

    let uiType = desc.uiType
    switch (widgetType) {
      case "checkbox":
        if (def != null && uiType != "bool")
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            "Option '" + id + "' - 'widgetType'/'def' conflict."))
        break
      case "slider":
        if (def != null && uiType != "integer")
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            "Option '" + id + "' - 'widgetType'/'def' conflict."))
        let invalidVal = -1
        let vMin = desc?.min ?? invalidVal
        let vMax = desc?.max ?? invalidVal
        let safeDef = (def != null) ? def : invalidVal
        if (!("min" in desc) || !("max" in desc) || type(vMin) != uiType || type(vMax) != uiType
            || vMin > vMax || vMin > safeDef || safeDef > vMax)
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            "Option '" + id + "' - 'min'/'def'/'max' conflict."))
        break
      case "list":
      case "tabs":
        if (def != null && uiType != "string")
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            "Option '" + id + "' - 'widgetType'/'def' conflict."))
        let values = getTblValue("values", desc, [])
        if (!values.len())
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            "Option '" + id + "' - 'values' is empty or undefined."))
        if (def != null && values.len() && !isInArray(def, values))
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            "Option '" + id + "' - 'def' is not listed in 'values'."))
        break
      case "editbox":
        if (def != null && uiType != "integer" && uiType != "float" && uiType != "string")
          errorsList.append(logError("sysopt.validateInternalConfigs()",
                                     "Option '" + id + "' - 'widgetType'/'def' conflict."))
        let maxlength = getTblValue("maxlength", desc, -1)
        if (maxlength < 0 || (def != null && def.tostring().len() > maxlength))
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            "Option '" + id + "' - 'maxlength'/'def' conflict."))
        break
    }
  }

  eachBlock(mQualityPresets, function(v, k) {
    if (v.paramCount() == 0)
      errorsList.append(logError("sysopt.validateInternalConfigs()",
       $"Quality presets - 'qualityPresets' k='{k}' contains invalid data."))
    if (!(k in mSettings))
      errorsList.append(logError("sysopt.validateInternalConfigs()",
        $"Quality presets - k='{k}' is not found in 'settings' table."))
    if (("graphicsQuality" in mSettings) && ("values" in mSettings.graphicsQuality)) {
      let qualityValues = mSettings.graphicsQuality.values
      foreach (quality in qualityValues) {
        if (quality == "custom")
          continue
        if (v?[quality] == null) {
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            $"Quality presets - k='{k}', graphics quality '{quality}' not exists."))
          continue
        }
        let guiValue = configValueToGuiValue(k, v[quality])
        if (guiValue != validateGuiValue(k, guiValue))
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            $"Quality presets - k='{k}', v.{quality}='{guiValue}' is invalid value for '{k}'."))
      }
    }
  })

  foreach (sectIndex, section in mUiStruct) {
    let container = getTblValue("container", section)
    let id = getTblValue("id", section)
    let items = getTblValue("items", section)
    if (!container || (!id && !items))
      errorsList.append(logError("sysopt.validateInternalConfigs()",
        "Array uiStruct - Index " + sectIndex + " contains invalid data."))
    let ids = items ? items : id ? [ id ] : []
    foreach (itemId in ids)
      if (!(itemId in mSettings))
        errorsList.append(logError("sysopt.validateInternalConfigs()",
          "Array uiStruct - Option '" + itemId + "' not found in 'settings' table."))
  }

  mScriptValid = !errorsList.len()
  if (::is_dev_version)
    mValidationError = "\n".join(errorsList, true)
  if (!mScriptValid) {
    let errorString = "\n".join(errorsList, true) // warning disable: -declared-never-used
    script_net_assert_once("system_options_not_valid", "not valid system option list")
  }
}

let function configRead() {
  mCfgInitial = {}
  mCfgCurrent = {}
  mBlk = blkOptFromPath(get_config_name())
  foreach (id, desc in mSettings) {
    if ("init" in desc)
      desc.init(mBlk, desc)
    local value = ("getValueFromConfig" in desc) ? desc.getValueFromConfig(mBlk, desc) : getBlkValueByPath(mBlk, desc.blk, desc.def)
    value = configValueToGuiValue(id, value)
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

let function configWrite() {
  if (! is_platform_pc)
    return;
  if (!mBlk)
    return

  if (was_screenshot_applied_to_config()) {
    log("[sysopt] Config was modified by screenshot, skipping save")
    return
  }

  log("[sysopt] Saving config:")
  foreach (id, _ in mCfgCurrent) {
    let value = getGuiValue(id)
    if (mCfgInitial?[id] != value)
      log("[sysopt] " + id + ": " + (mCfgInitial?[id] ?? "null") + " -> " + value)
    let desc = getOptionDesc(id)
    if ("setGuiValueToConfig" in desc)
      desc.setGuiValueToConfig(mBlk, desc, value)
    else
      setBlkValueByPath(mBlk, desc.blk, value)
  }

  mBlk.saveToTextFile(get_config_name())
  log("[sysopt] Config saved.")
}

let function init() {
  let blk = blkOptFromPath(get_config_name())
  foreach (_id, desc in mSettings) {
    if ("init" in desc)
      desc.init(blk, desc)
    if (("onChanged" in desc) && type(desc.onChanged) == "string")
      desc.onChanged = (desc.onChanged in mShared) ? mShared[desc.onChanged] : null
    let uiType = ("def" in desc) ? type(desc.def) : null
    desc.uiType <- uiType
    desc.widgetId <- null
    desc.ignoreNextUiCallback <- false
  }

  validateInternalConfigs()
  configRead()
}

let function configFree() {
  mBlk = null
  mHandler = null
  mContainerObj = null
  mCfgInitial = {}
  mCfgCurrent = {}
}

let function resetGuiOptions() {
  foreach (id, value in mCfgInitial) {
    setGuiValue(id, value)
  }
  updateGuiNavbar()
}

let function onGuiLoaded() {
  if (!mScriptValid)
    return

  mShared.setCustomSettings()
  mShared.presetCheck()
  updateGuiNavbar(true)
}

let function onGuiUnloaded() {
  updateGuiNavbar(false)
}

let function configMaintain() {
  if (mMaintainDone)
    return
  mMaintainDone = true
  if (!is_platform_pc)
    return
  if (!mScriptValid)
    return

  if (::getSystemConfigOption("graphicsQuality", "high") == "user") { // Need to reset
    let isCompatibilityMode = ::getSystemConfigOption("video/compatibilityMode", false)
    ::setSystemConfigOption("graphicsQuality", isCompatibilityMode ? "ultralow" : "high")
  }

  configRead()

  mShared.setCustomSettings()
  mShared.presetCheck()

  if (isSavePending()) {
    log("[sysopt] Graphics settings maintenance, config.blk repaired.")
    configWrite()
  }

  configFree()
}

let function applyRestartEngine(reloadScene = false) {
  mCfgApplied = {}
  foreach (id, value in mCfgCurrent)
    mCfgApplied[id] <- value

  log("[sysopt] Resetting renderer.")
  applyRendererSettingsChange(reloadScene, true)
}

let isReloadSceneRerquired = @() mCfgApplied.resolution != mCfgCurrent.resolution
  || mCfgApplied.mode != mCfgCurrent.mode
  || mCfgApplied.enableVr != mCfgCurrent.enableVr

let function onRestartClient() {
  configWrite()
  configFree()
  applyRestartClient()
}

let function hotReloadOrRestart() {
  if (isSavePending())
    configWrite()

  let restartPending = isRestartPending()
  if (!restartPending && isHotReloadPending())
    applyRestartEngine(isReloadSceneRerquired())

  configFree()

  if (restartPending) {
    let func_restart = function() {
      applyRestartClient()
    }

    if (canRestartClient()) {
      let message = loc("msgbox/client_restart_required") + "\n" + loc("msgbox/restart_now")
      scene_msg_box("sysopt_apply", null, message, [
          ["restart", func_restart],
          ["no"],
        ], "restart", { cancel_fn = @() null })
    }
    else {
      let message = loc("msgbox/client_restart_required")
      scene_msg_box("sysopt_apply", null, message, [
          ["ok"],
        ], "ok", { cancel_fn = @() null })
    }
  }
}

let function onConfigApply() {
  if (!mScriptValid)
    return

  if (!checkObj(mContainerObj))
    return

  mShared.presetCheck()
  onGuiUnloaded()
  hotReloadOrRestart()
}

let function onConfigApplyWithoutUiUpdate() {
  if (!mScriptValid)
    return

  mShared.presetCheck()
  hotReloadOrRestart()
}

let isCompatibiliyMode = @() mCfgStartup?.compatibilityMode
  ?? ::getSystemConfigOption("video/compatibilityMode", false)

let function onGuiOptionChanged(obj) {
  let widgetId = checkObj(obj) ? obj?.id : null
  if (!widgetId)
    return
  let id = widgetId.slice(("sysopt_").len())

  let desc = getOptionDesc(id)
  if (!desc)
    return

  if (desc.ignoreNextUiCallback) {
    desc.ignoreNextUiCallback = false
    return
  }

  let curValue = getTblValue(id, mCfgCurrent)
  if (curValue == null)  //not inited or already cleared?
    return

  local value = null
  let raw = obj.getValue()
  switch (desc.widgetType) {
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
      switch (desc.uiType) {
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
      if (value == null) {
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

let function fillGuiOptions(containerObj, handler) {
  if (!checkObj(containerObj) || !handler)
    return
  let guiScene = containerObj.getScene()

  if (!mScriptValid) {
    let msg = loc("msgbox/internal_error_header") + "\n" + mValidationError
    let data = format("textAreaCentered { text:t='%s' size:t='pw,ph' }", stripTags(msg))
    guiScene.replaceContentFromText(containerObj, data, data.len(), handler)
    return
  }

  guiScene.setUpdatesEnabled(false, false)
  guiScene.replaceContent(containerObj, "%gui/options/systemOptions.blk", handler)
  mContainerObj = containerObj
  mHandler = handler

  if (get_video_modes().len() == 0 && !is_platform_windows) { // Hiding resolution, mode, vsync.
    let topBlockId = "sysopt_top"
    if (topBlockId in guiScene) {
      guiScene.replaceContentFromText(topBlockId, "", 0, handler)
      guiScene[topBlockId].height = 0
    }
  }

  configRead()
  let cb = "onSystemOptionChanged"
  foreach (section in mUiStruct) {
    if (! guiScene[section.container])
      continue
    let isTable = ("items" in section)
    let ids = isTable ? section.items : [ section.id ]
    local data = ""
    foreach (id in ids) {
      let desc = getOptionDesc(id)
      if (!(desc?.isVisible() ?? true))
        continue

      desc.widgetId = "sysopt_" + id
      local option = ""
      switch (desc.widgetType) {
        case "checkbox":
          let config = {
            id = desc.widgetId
            value = mCfgCurrent[id]
            cb = cb
          }
          option = create_option_switchbox(config)
          break
        case "slider":
          desc.step <- desc?.step ?? max(1, round((desc.max - desc.min) / mMaxSliderSteps).tointeger())
          option = ::create_option_slider(desc.widgetId, mCfgCurrent[id], cb, true, "slider", desc)
          break
        case "list":
          option = getListOption(id, desc, cb)
          break
        case "tabs":
          let raw = desc.values.indexof(mCfgCurrent[id]) ?? -1
          let items = []
          foreach (valueId in desc.values) {
            local warn = loc(format("options/%s_%s/comment", id, valueId), "")
            warn = warn.len() ? ("\n" + colorize("badTextColor", warn)) : ""

            items.append({
              text = localize(id, valueId)
              tooltip = loc(format("guiHints/%s_%s", id, valueId)) + warn
            })
          }
          option = ::create_option_row_listbox(desc.widgetId, items, raw, cb, isTable)
          break
        case "editbox":
          let raw = mCfgCurrent[id].tostring()
          option = ::create_option_editbox({
            id = desc.widgetId,
            value = raw,
            maxlength = desc.maxlength
          })
          break
      }

      if (isTable) {
        let enable = (desc?.enabled() ?? true) ? "yes" : "no"
        let requiresRestart = getTblValue("restart", desc, false)
        let tooltipExtra = desc?.tooltipExtra ?? ""
        let optionName = loc($"options/{id}")
        let label = stripTags("".join([optionName, requiresRestart ? $"{nbsp}*" : $"{nbsp}{nbsp}"]))
        let tooltip = stripTags("\n".join(
          [ loc($"guiHints/{id}", optionName),
            requiresRestart ? colorize("warningTextColor", loc("guiHints/restart_required")) : "",
            tooltipExtra
          ], true)
        )
        option = "tr { id:t='" + id + "_tr'; enable:t='" + enable + "' selected:t='no' size:t='pw, " + mRowHeightScale + "@baseTrHeight' overflow:t='hidden' tooltip:t=\"" + tooltip + "\";" +
          " td { width:t='0.5pw'; cellType:t='left'; overflow:t='hidden'; height:t='" + mRowHeightScale + "@baseTrHeight' optiontext {text:t='" + label + "'} }" +
          " td { width:t='0.5pw'; cellType:t='right';  height:t='" + mRowHeightScale + "@baseTrHeight' padding-left:t='@optPad'; " + option + " } }"
      }

      data += option
    }

    guiScene.replaceContentFromText(guiScene[section.container], data, data.len(), handler)
  }

  guiScene.setUpdatesEnabled(true, true)
  onGuiLoaded()
}

let function setQualityPreset(presetName) {
  if (mCfgInitial.len() == 0)
    configRead()

  setGuiValue("graphicsQuality", presetName, mHandler == null)
  getOptionDesc("graphicsQuality")?.onChanged(true)
  updateGuiNavbar(true)
}

//------------------------------------------------------------------------------
init()

//------------------------------------------------------------------------------
return {
  fillSystemGuiOptions = fillGuiOptions
  resetSystemGuiOptions = resetGuiOptions
  onSystemGuiOptionChanged = onGuiOptionChanged
  onRestartClient = onRestartClient
  getVideoModes = mShared.getVideoModes
  isCompatibiliyMode = isCompatibiliyMode
  onSystemOptionsApply = onConfigApply
  canUseGraphicsOptions = canUseGraphicsOptions
  systemOptionsMaintain = configMaintain
  overrideUiStruct = @(struct) mUiStruct = struct
  setQualityPreset
  localizaQualityPreset
  onConfigApplyWithoutUiUpdate
  canShowGpuBenchmark
}
