//-file:param-pos
from "%scripts/dagui_natives.nut" import get_dgs_tex_quality, is_hdr_available, is_perf_metrics_available, is_low_latency_available, is_vrr_available, get_config_name, is_gpu_nvidia, get_video_modes
from "app" import is_dev_version
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

let DataBlock = require("DataBlock")
let { round } = require("math")
let { format, strip } = require("string")
let regexp2 = require("regexp2")
let { is_stereo_configured, configure_stereo } = require("vr")
<<<<<<< HEAD   (9f2714 WT: hitContext: Fix crash for replay's Hit Analysis)
let { get_available_monitors, get_monitor_info, has_broken_recreate_image, get_antialiasing_options, get_antialiasing_upscaling_options, has_antialiasing_sharpening } = require("graphicsOptions")
=======
let { get_available_monitors, get_monitor_info, get_antialiasing_options, get_antialiasing_upscaling_options,
  has_antialiasing_sharpening, is_dx12_supported } = require("graphicsOptions")
>>>>>>> CHANGE (1b31a4 WT: GUI: FIX: DX12 graphic API is available to choose on PC )
let applyRendererSettingsChange = require("%scripts/clientState/applyRendererSettingsChange.nut")
let { setBlkValueByPath, getBlkValueByPath, blkOptFromPath } = require("%globalScripts/dataBlockExt.nut")
let { get_primary_screen_info } = require("dagor.system")
let { was_screenshot_applied_to_config } = require("debug.config")
let { eachBlock } = require("%sqstd/datablock.nut")
let { applyRestartClient, canRestartClient
} = require("%scripts/utils/restartClient.nut")
let { stripTags } = require("%sqstd/string.nut")
let { create_option_switchbox, create_option_slider } = require("%scripts/options/optionsExt.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { getSystemConfigOption, setSystemConfigOption } = require("%globalScripts/systemConfig.nut")
let { eventbus_subscribe } = require("eventbus")
let { doesLocTextExist } = require("dagor.localize")
let { findNearest } = require("%scripts/util.nut")
let { is_win64 } = require("%sqstd/platform.nut")
let { hardPersistWatched } = require("%sqstd/globalState.nut")

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

let isDx12Supported = hardPersistWatched("isDx12Supported", null)
function initIsDx12SupportedOnce() { //is_dx12_supported is a heavy function and should not be called often.
  if (isDx12Supported.get() == null) {
    let is_dx12_sup = is_dx12_supported()
    isDx12Supported.set(is_win64 && is_dx12_sup)
  }
}

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
    lastClipSize      = { compMode = true }
    compatibilityMode = { compMode = true }
    riGpuObjects      = { fullMode = false }
    compatibilityShadowQuality = { compMode = true, fullMode = false }
  }
  standaloneOptions = {
  }
}

let platformDependentOpts = {
  gfx_api = true
  resolution = true
  mode = true
  monitor = true
  vsync = true
}

let initialGfxApi = blkOptFromPath(get_config_name())?.video.driver ?? "auto"

//------------------------------------------------------------------------------
local mUiStruct = [
  {
    title = "options/display"
    items = [
      "mode"
      "resolution"
      "vsync"
      "monitor"
      "gfx_api"
      "backgroundScale"
      "antialiasingMode"
      "antialiasingUpscaling"
      "antialiasingSharpening"
      "anisotropy"
      "ssaa"
      "latency"
    ]
  }
  {
    title = "options/dlss_quality"
    items = [
      "graphicsQuality"
      "texQuality"
      "shadowQuality"
      "compatibilityShadowQuality"
      "waterQuality"
      "waterEffectsQuality"
      "cloudsQuality"
      "panoramaResolution"
      "ssrQuality"
      "fxResolutionQuality"
      "landquality"
      "ssaoQuality"
      "tireTracksQuality"
      "mirrorQuality"
      "giQuality"
      "physicsQuality"
      "displacementQuality"
      "dirtSubDiv"
    ]
  }
  {
    title = "options/renderer"
    items = [
      "rendinstDistMul"
      "fxDensityMul"
      "grassRadiusMul"
      "contactShadowsQuality"
      "advancedShore"
      "haze"
      "lastClipSize"
      "lenseFlares"
    ]
  }
  {
    title = "options/rt"
    addTitleInfo = is_win64 && initialGfxApi == "auto"
      ? "options/dx12_only" : null
    items = [
      "rayTracing"
      "bvhDistance"
      "rtao"
      "rtsm"
      "rtr"
      "rtrRes"
      "rtrWater"
      "rtrWaterRes"
      "rtrTranslucent"
    ]
  }
  {
    title = "options/vr"
    items = [
      "enableVr"
      "vrMirror"
      "vrStreamerMode"
    ]
  }
  {
    title = "chapters/other"
    items = [
      "perfMetrics"
      "motionBlurStrength"
      "motionBlurCancelCamera"
      "jpegShots"
      "hiResShots"
      "compatibilityMode"
      "enableHdr"
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

function logError(from = "", msg = "") {
  let fullMsg = $"[sysopt] ERROR {from}: {msg}"
  log(fullMsg)
  return fullMsg
}

function getOptionDesc(id) {
  if (!(id in mSettings)) {
    logError("sysopt.getOptionDesc()", $"Option '{id}' is UNKNOWN. It must be added to sysopt.settings table.")
    return null
  }
  return mSettings[id]
}

function tryGetOptionImageSrc(id) {
  let opt = getOptionDesc(id)
  let curValue = mCfgCurrent[id]
  let { infoImgPattern = null, availableInfoImgVals = null } = opt

  if (infoImgPattern == null || curValue == null || curValue == "custom")
    return null

  let imgVal = availableInfoImgVals
    ? availableInfoImgVals[findNearest(curValue, availableInfoImgVals)]
    : curValue

  return format(infoImgPattern, imgVal.tostring().replace(" ",  ""))

}

function tryUpdateOptionImage(id) {
  let optInfoImg =   mHandler?.scene.findObject("option_info_image")
  if (!optInfoImg?.isValid())
    return
  optInfoImg["background-image"] = tryGetOptionImageSrc(id)
}

function getOptionInfoView(id) {
  let opt = getOptionDesc(id)
  let title = loc($"options/{id}")
  let descLocKey = $"guiHints/{id}"
  let description = doesLocTextExist(descLocKey) ? [loc(descLocKey)] : []
  if (opt?.restart)
    description.append(colorize("warningTextColor", loc("guiHints/restart_required")))
  if (opt?.tooltipExtra)
    description.append(opt?.tooltipExtra)

  return {
    title
    description =  "\n".join(description)
    imageSrc = tryGetOptionImageSrc(id)
  }
}

function configValueToGuiValue(id, value) {
  let desc = getOptionDesc(id)
  return desc?.configValueToGuiValue(value) ?? value
}

function validateGuiValue(id, value) {
  if (!is_platform_pc)
    return value

  let desc = getOptionDesc(id)
  if (type(value) != desc.uiType) {
    logError("sysopt.validateGuiValue()", $"Can't set '{id}'='{value}', value type is invalid.")
    return desc.def
  }

  let {widgetType} = desc

  if ( widgetType == "checkbox") {
    return value ? true : false
  }
  else if ( widgetType == "slider" ) {
    if (value < desc.min || value > desc.max) {
      logError("sysopt.validateGuiValue()", $"Can't set '{id}'='{value}', value is out of range.")
      return (value < desc.min) ? desc.min : desc.max
    }
  }
  else if ( widgetType == "list" || widgetType == "tabs" || widgetType == "value_slider") {
    if (desc.values.indexof(value) == null && (value not in desc?.hidden_values)) {
      logError("sysopt.validateGuiValue()", $"Can't set '{id}'='{value}', value is not in the allowed values list.")
      return desc.def
    }
  }
  else if ( widgetType == "editbox" ) {
    if (value.tostring().len() > desc.maxlength) {
      logError("sysopt.validateGuiValue()", $"Can't set '{id}'='{value}', value is too long.")
      return value
    }
  }
  return value
}

function getGuiWidget(id) {
  if (!(id in mSettings)) {
    logError("sysopt.getGuiWidget()", $"Option '{id}' is UNKNOWN. It must be added to sysopt.settings table.")
    return null
  }

  let widgetId = getOptionDesc(id)?.widgetId
  let obj = (widgetId && checkObj(mContainerObj)) ? mContainerObj.findObject(widgetId) : null
  return checkObj(obj) ? obj : null
}

function setGuiValue(id, value, skipUI = false) {
  value = validateGuiValue(id, value)
  mCfgCurrent[id] = value

  let obj = (skipUI || mSkipUI) ? null : getGuiWidget(id)
  if (obj) {
    let desc = getOptionDesc(id)
    local raw = null
    let { widgetType } = desc
    if ( widgetType == "checkbox"  || "slider" == widgetType) {
      raw = value
    }
    else if ( widgetType == "list" || widgetType == "tabs" || widgetType == "value_slider") {
      raw = desc.values.indexof(value) ?? -1
    }
    else if ( widgetType == "editbox" ) {
      raw = value.tostring()
    }
    if (raw != null && obj.getValue() != raw) {
      desc.ignoreNextUiCallback = desc.widgetType != "checkbox"
      obj.setValue(raw)
    }
  }
}

function setValue(id, value, skipUI = false) {
  setGuiValue(id, configValueToGuiValue(id, value), skipUI)
}

function getDisabledOptionTooltip(id) {
  let locKey = $"guiHints/{id}/disabled"
  return doesLocTextExist(locKey) ? stripTags(loc(locKey)) : null
}

function enableGuiOption(id, state) {
  if (mSkipUI || !mContainerObj?.isValid())
    return
  let rowObj = mContainerObj.findObject($"{id}_tr")
  let controlObj = mContainerObj.findObject($"sysopt_{id}")
  if (!controlObj?.isValid() || !rowObj?.isValid())
    return

  rowObj.disabled = state ? "no" : "yes"
  controlObj.enable(state)

  let disabledTooltip = getDisabledOptionTooltip(id)
  if (disabledTooltip != null)
    rowObj.tooltip = state ? null : disabledTooltip
}

function checkChanges(config1, config2) {
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
let canShowGpuBenchmark = @() canUseGraphicsOptions()

local aaUseGui = false;

function updateGuiNavbar(show = true) {
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

function pickQualityPreset() {
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

function localizaQualityPreset(presetName) {
  let txt = (presetName == "ultralow" || presetName == "min") ? "ultra_low"
    : presetName == "ultrahigh" ? "ultra_high"
    : presetName
  return loc($"options/quality_{txt}")
}

function localize(optionId, valueId) {
  if (optionId == "resolution") {
    if (valueId == "auto")
      return loc("options/auto")
    else
      return valueId
  }
  if (optionId == "anisotropy" || optionId == "ssaa")
    return loc($"options/{valueId}")

  if (optionId == "graphicsQuality" ||
      optionId == "texQuality" ||
      optionId == "shadowQuality" ||
      optionId == "waterEffectsQuality" ||
      optionId == "compatibilityShadowQuality" ||
      optionId == "fxResolutionQuality" ||
      optionId == "tireTracksQuality" ||
      optionId == "waterQuality" ||
      optionId == "giQuality" ||
      optionId == "dirtSubDiv"
    ) {
    if (valueId == "none")
      return loc("options/none")
    return localizaQualityPreset(valueId)
  }
  return loc(format("options/%s_%s", optionId, valueId), valueId)
}

function parseResolution(resolution) {
  let sides = resolution == "auto"
    ? [ 0, 0 ] // To be sorted first.
    : resolution.split("x").apply(@(v) to_integer_safe(strip(v), 0, false))
  return {
    resolution = resolution
    w = sides?[0] ?? 0
    h = sides?[1] ?? 0
  }
}

function antiAliasingOptions() {
  let modesString = get_antialiasing_options(getGuiValue("enableVr"))
  return modesString.split(";").map(@(mode) mode.split("|")[0])
}

function antiAliasingOptionsWithVersion() {
  let modesString = get_antialiasing_options(getGuiValue("enableVr"))
  return modesString.split(";").map(function(mode) {
    let [name, version = null] = mode.split("|")
    let locName = localize("antialiasingMode", name)
    return version != null
      ? " - v".concat(locName, version)
      : locName
  })
}

function antiAliasingUpscalingOptions(blk) {
  let aa = aaUseGui ? getGuiValue("antialiasingMode", "off") : getBlkValueByPath(blk, "video/antialiasing_mode", "off")
  let modesString = get_antialiasing_upscaling_options(aa)
  return modesString.split(";")
}

function hasAntialiasingUpscaling() {
  let aa = getGuiValue("antialiasingMode", "off")
  let modesString = get_antialiasing_upscaling_options(aa)
  return modesString.split(";").len() > 1
}

function hasAntialiasingSharpening() {
  let aa = getGuiValue("antialiasingMode", "off")
  return has_antialiasing_sharpening(aa)
}

function canDoBackgroundScale() {
  let mode = getGuiValue("antialiasingMode", "off")
  return !(mode == "dlss" || mode == "xess")
}

function getAvailableLatencyModes() {
  let values = ["off"]
  if (is_low_latency_available(1))
    values.append("on")
  if (is_low_latency_available(2))
    values.append("boost")

  return values;
}

let getAvailablePerfMetricsModes = @() perfValues.filter(@(_, id) id <= 1 || is_perf_metrics_available(id))

let hasRT = @() hasFeature("optionRT") && !is_platform_macosx && getGuiValue("graphicsQuality", "high") != "ultralow"
  && getGuiValue("gfx_api") == "dx12"
let hasRTGUI = @() getGuiValue("rayTracing", "off") != "off" && hasRT()
let hasRTR = @() getGuiValue("rtr", "off") != "off" && hasRTGUI()
let hasRTRWater = @() getGuiValue("rtrWater", false) != false && hasRTGUI()
let isRTVisible = @() hasFeature("optionBVH")
let isRTAOVisible = @() hasFeature("optionBVH") && hasFeature("optionBVH_AO")
let isRTSMVisible = @() hasFeature("optionBVH") && hasFeature("optionBVH_SM")
function getListOption(id, desc, cb, needCreateList = true) {
  let raw = desc.values.indexof(mCfgCurrent[id]) ?? -1
  let customItems = ("items" in desc) ? desc.items : null
  let items = []
  foreach (index, valueId in desc.values)
    items.append(customItems ? customItems[index] : localize(id, valueId))
  return ::create_option_combobox(desc.widgetId, items, raw, cb, needCreateList)
}

function changeOptions(id) {
  let desc = getOptionDesc(id)
  if (!desc)
    return

  desc.init(null, desc)
  setGuiValue(id, desc.values.indexof(getGuiValue(id)) ?? desc.def, true)
  let obj = getGuiWidget(id)
  if (!checkObj(obj))
    return

  let markup = getListOption(id, desc, "onSystemOptionChanged", false)
  mContainerObj.getScene().replaceContentFromText(obj, markup, markup.len(), mHandler)
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
      function ok_func() {
        setGuiValue("rayTracing", "off")
        mShared.graphicsQualityClick(true)
        updateGuiNavbar(true)
      }
      function cancel_func() {
        let lowQuality = "low"
        setGuiValue("graphicsQuality", lowQuality)
        mShared.graphicsQualityClick()
        updateGuiNavbar(true)
      }
      scene_msg_box("msg_ultra_low_quality_preset", null,
        loc("msgbox/ultra_low_quality_preset"),
        [
          ["yes", ok_func],
          ["no", cancel_func],
        ], "no",
        { cancel_fn = cancel_func, checkDuplicateId = true })
    }
    mShared.setCustomSettings()
    mShared.rayTracingClick(silent)
  }

  presetCheck = function() {
    let preset = pickQualityPreset()
    setGuiValue("graphicsQuality", preset)
  }

  resolutionClick = function() {
    changeOptions("antialiasingUpscaling")
  }

  modeClick = @() enableGuiOption("monitor", getOptionDesc("monitor")?.enabled() ?? true)

  antialiasingModeClick = function() {
    aaUseGui = true

    let canBgScale = canDoBackgroundScale()
    enableGuiOption("ssaa", canBgScale)
    enableGuiOption("antialiasingUpscaling", hasAntialiasingUpscaling())
    enableGuiOption("antialiasingSharpening", hasAntialiasingSharpening())

    changeOptions("antialiasingUpscaling")
    setGuiValue("antialiasingSharpening", 0)

    if (!canBgScale) {
      setGuiValue("ssaa", "none")
      setGuiValue("backgroundScale", 1.0)
    }

    aaUseGui = false;
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

  ssaaClick = function() {
    if (getGuiValue("ssaa") == "4X") {
      function okFunc() {
        setGuiValue("backgroundScale", 2)
        mShared.presetCheck()
        updateGuiNavbar(true)
      }
      function cancelFunc() {
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
      function okFunc() {
        setGuiValue("fxResolutionQuality", "ultrahigh")
        mShared.presetCheck()
        updateGuiNavbar(true)
      }
      function cancelFunc() {
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
      function ok_func() {
        mShared.setCompatibilityMode()
        mShared.presetCheck()
        updateGuiNavbar(true)
      }
      function cancel_func() {
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

  gfxApiClick = function() {
    let api = getGuiValue("gfx_api")
    let isSupportedApi = api == "dx12"
    enableGuiOption("rayTracing", isSupportedApi)
    if (!isSupportedApi) {
      setGuiValue("rayTracing", "off")
      mShared.rayTracingClick()
    }
  }

  rtOptionChanged = function() {
    setGuiValue("rayTracing", "custom")
  }

  rtrWaterClick = function() {
    enableGuiOption("rtrWaterRes", getGuiValue("rtrWater") && getGuiValue("rayTracing", "off") != "off")
    mShared.rtOptionChanged()
  }

  rtrClick = function() {
    enableGuiOption("rtrRes", getGuiValue("rtr") != "off" && getGuiValue("rayTracing", "off") != "off")
    mShared.rtOptionChanged()
  }

  rayTracingPresetHandler = function(rt) {
    let rtIsOn = rt != "off"
    setBlkValueByPath(mBlk, "graphics/enableBVH", rtIsOn)

    if (!rtIsOn) {
      setGuiValue("rtao", "off")
      setGuiValue("rtr", "off")
      setGuiValue("rtrRes", "half")
      setGuiValue("rtsm", "off")
      setGuiValue("rtrWater", false)
      setGuiValue("rtrWaterRes", "half")
      setGuiValue("rtrTranslucent", "off")
    }
    if (rt == "low") {
      setGuiValue("bvhDistance", 1000)
      setGuiValue("rtao", "low")
      setGuiValue("rtr", "low")
      setGuiValue("rtrRes", "half")
      setGuiValue("rtsm", "sun")
      setGuiValue("rtrWater", false)
      setGuiValue("rtrWaterRes", "half")
      setGuiValue("rtrTranslucent", "medium")
    } else if (rt == "medium") {
      setGuiValue("bvhDistance", 2000)
      setGuiValue("rtao", "low")
      setGuiValue("rtr", "medium")
      setGuiValue("rtrRes", "half")
      setGuiValue("rtsm", "sun")
      setGuiValue("rtrWater", true)
      setGuiValue("rtrWaterRes", "half")
      setGuiValue("rtrTranslucent", "medium")
    } else if (rt == "high") {
      setGuiValue("bvhDistance", 3000)
      setGuiValue("rtao", "medium")
      setGuiValue("rtr", "high")
      setGuiValue("rtrRes", "half")
      setGuiValue("rtsm", "sun")
      setGuiValue("rtrWater", true)
      setGuiValue("rtrWaterRes", "half")
      setGuiValue("rtrTranslucent", "high")
    } else if (rt == "ultra") {
      setGuiValue("bvhDistance", 4000)
      setGuiValue("rtao", "high")
      setGuiValue("rtr", "high")
      setGuiValue("rtrRes", "full")
      setGuiValue("rtsm", "sun_and_dynamic")
      setGuiValue("rtrWater", true)
      setGuiValue("rtrWaterRes", "full")
      setGuiValue("rtrTranslucent", "high")
    }

    enableGuiOption("bvhDistance", rtIsOn)
    enableGuiOption("rtr", rtIsOn)
    enableGuiOption("rtao", rtIsOn)
    enableGuiOption("rtsm", rtIsOn)

    enableGuiOption("rtrWater", rtIsOn)
    enableGuiOption("rtrWaterRes", getGuiValue("rtrWater") && rtIsOn)

    enableGuiOption("rtrTranslucent", rtIsOn)
    enableGuiOption("rtrRes", getGuiValue("rtr") != "off" && rtIsOn)
  }

  rayTracingClick = function(silent = false) {
    let rt = getGuiValue("rayTracing", "off")
    if (silent || rt == "off") {
      mShared.rayTracingPresetHandler(rt)
      return;
    }

    function okFunc() {
      mShared.rayTracingPresetHandler(rt)
    }
    function cancelFunc() {
      setGuiValue("rayTracing", "off")
      mShared.rayTracingPresetHandler("off")
    }
    scene_msg_box("msg_sysopt_rt", null, loc("msgbox/rt_warning"),
      [
        ["ok", okFunc],
        ["cancel", cancelFunc],
      ], "cancel",
      { cancel_fn = cancelFunc, checkDuplicateId = true })
  }

  vrModeClick = function() {
    changeOptions("antialiasingMode")
    changeOptions("antialiasingUpscaling")
    setGuiValue("antialiasingMode", "off")
    setGuiValue("antialiasingUpscaling", "native")
    if (getGuiValue("enableVr")) {
      setGuiValue("rayTracing", "off")
      mShared.rayTracingClick(true);
      enableGuiOption("rayTracing", false)
    } else if (hasRT()) {
      enableGuiOption("rayTracing", true)
      mShared.rayTracingClick(true);
    }
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
  widgetType - type of the widget in UI ("list", "slider", "value_slider", "checkbox", "editbox", "tabs").
  def - default value in UI (it is not required, if there are getValueFromConfig/setGuiValueToConfig functions).
  blk - path to variable in config.blk file structure (it is not required, if there are getValueFromConfig/setGuiValueToConfig functions).
  restart - client restart is required to apply an option (e.g. no support in Renderer->onSettingsChanged() function).
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
  infoImgPattern - optional, pattern for the option image in the format `#ui/path/img_name_%s`, where `%s` will be replaced with the current option value.
    For correct functionality, images for all possible options listed in the 'values' must be present.
  availableInfoImgVals - optional, (works with the 'slider' and 'value_slider' widgetType) allows specifying which values have corresponding images.
    Sliders may have high granularity, so instead of loading an image for every option,
    we can load a few images. The image with the closest matching value will be displayed.


*/
mSettings = {
  gfx_api = { widgetType = "list" def = "auto" blk = "video/driver" restart = true
    init = function(_blk, desc) {
      initIsDx12SupportedOnce()
      desc.values <- [ "auto" ]

      if (isDx12Supported.get())
        desc.values.append("dx12")

      if (is_win64 && hasFeature("optionGFXAPIVulkan"))
        desc.values.append("vulkan")

      desc.items <- desc.values.map(function(value) {
        if (is_win64 && value == "auto")
          return { text = "".concat(loc("options/gfx_api_auto"), loc("ui/parentheses/space", {text = loc("options/gfx_api_dx11") })) }
        return { text = loc($"options/gfx_api_{value}") }
      })
      desc.def <- desc.values[0]
    }
    onChanged = "gfxApiClick"
    isVisible = @() is_win64 && hasFeature("optionGFXAPI")
  }
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
    onChanged = "modeClick"
  }
  monitor = { widgetType = "list" def = "auto" blk = "video/monitor" restart = true
    function init(_blk, desc) {
      let availableMonitors = get_available_monitors()
      desc.values <- availableMonitors?.list ?? ["auto"]
      desc.items <- desc.values.map(function(value) {
        if (value == "auto")
          return { text = loc("options/auto") }
        let info = get_monitor_info(value)
        return { text = info != null ? $"{info[0]} [#{info[1] + 1}]" : value }
      })
      desc.def = availableMonitors?.current ?? "auto"
      desc.restart <- !is_platform_windows
    }
    setGuiValueToConfig = @(blk, desc, val) setBlkValueByPath(blk, desc.blk, val)
    enabled = @() getGuiValue("mode", "fullscreen") != "windowed"
    isVisible = @() (get_available_monitors()?.list ?? []).len() > 2
  }
  vsync = { widgetType = "list" def = "vsync_off" blk = "video/vsync" restart = false
    getValueFromConfig = function(blk, _desc) {
      let vsync = getBlkValueByPath(blk, "video/vsync", false)
      return vsync ? "vsync_on" : "vsync_off"
    }
    setGuiValueToConfig = function(blk, _desc, val) {
      setBlkValueByPath(blk, "video/vsync", val == "vsync_on")
    }
    init = function(_blk, desc) {
      desc.values <- [ "vsync_off", "vsync_on" ]
    }
    enabled = @() getGuiValue("latency", "off") != "on" && getGuiValue("latency", "off") != "boost"
  }
  graphicsQuality = { widgetType = "list" def = "high" blk = "graphicsQuality" restart = false
    values = [ "ultralow", "low", "medium", "high", "max", "movie", "custom" ]
    onChanged = "graphicsQualityClick"
    infoImgPattern = "#ui/images/settings/graphicsQuality/%s"
  }

  antialiasingMode = { widgetType = "list" def = "off" blk = "video/antialiasing_mode" restart = false
    init = function(_blk, desc) {
      desc.values <- antiAliasingOptions()
      desc.items <- antiAliasingOptionsWithVersion()
    }
    onChanged = "antialiasingModeClick"
    hidden_values = { low_fxaa = "low_fxaa", high_fxaa = "high_fxaa", taa = "taa" }
    enabled = @() !getGuiValue("compatibilityMode")
    infoImgPattern = "#ui/images/settings/antiAliasing/%s"
  }

  antialiasingUpscaling = { widgetType = "list" def = "native" blk = "video/antialiasing_upscaling" restart = false
    init = function(blk, desc) {
      desc.values <- antiAliasingUpscalingOptions(blk)
    }
    enabled = @() hasAntialiasingUpscaling() && !getGuiValue("compatibilityMode")
    infoImgPattern = "#ui/images/settings/upscaling/%s"
  }

  antialiasingSharpening = { widgetType = "slider" def = 0 min = 0 max = 100 blk = "video/antialiasing_sharpening" restart = false
    enabled = @() hasAntialiasingSharpening() && !getGuiValue("compatibilityMode")
    infoImgPattern = "#ui/images/settings/sharpening/%s"
    availableInfoImgVals = [0, 33, 66, 100]
  }

  ssaa = { widgetType = "list" def = "none" blk = "graphics/ssaa" restart = false
    values = [ "none", "4X" ]
    enabled = @() canDoBackgroundScale()
    onChanged = "ssaaClick"
    getValueFromConfig = function(blk, desc) {
      return getBlkValueByPath(blk, desc.blk, 1.0)
    }
    infoImgPattern = "#ui/images/settings/ssaa/%s"
    setGuiValueToConfig = function(blk, desc, val) {
      let res = (val == "4X") ? 4.0 : 1.0
      setBlkValueByPath(blk, desc.blk, res)
    }
    configValueToGuiValue = @(val) (val == 4.0) ? "4X" : "none"
  }
  anisotropy = { widgetType = "list" def = "2X" blk = "graphics/anisotropy" restart = false
    values = [ "off", "2X", "4X", "8X", "16X" ]
    getValueFromConfig = function(blk, desc) {
      return getBlkValueByPath(blk, desc.blk, 2)
    }
    infoImgPattern = "#ui/images/settings/anisotropy/%s"
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
  texQuality = { widgetType = "value_slider" def = "high" blk = "graphics/texquality" restart = has_broken_recreate_image()
    init = function(_blk, desc) {
      let dgsTQ = get_dgs_tex_quality() // 2=low, 1-medium, 0=high.
      let configTexQuality = desc.values.indexof(getSystemConfigOption("graphics/texquality", "high")) ?? -1
      let sysTexQuality = [2, 1, 0].indexof(dgsTQ) ?? configTexQuality
      if (sysTexQuality == configTexQuality)
        return

      let restrictedValueName = localize("texQuality", desc.values[sysTexQuality])
      let restrictedValueItem = {
        text = colorize("badTextColor", $"{restrictedValueName} **")
        textStyle = "textStyle:t='textarea';"
      }
      desc.items <- []
      foreach (index, item in desc.values)
        desc.items.append((index <= sysTexQuality) ? localize("texQuality", item) : restrictedValueItem)
      desc.tooltipExtra <- colorize("badTextColor", "".concat("** ", loc("msgbox/graphicsOptionValueReduced/lowVideoMemory",
        { name = loc("options/texQuality"), value = restrictedValueName })))
      desc.hidden_values <- {ultralow = "ultralow"}
    }
    values = [ "low", "medium", "high" ]
    infoImgPattern = "#ui/images/settings/textureQuality/%s"
  }
  shadowQuality = { widgetType = "value_slider" def = "high" blk = "graphics/shadowQuality" restart = false
    values = [ "ultralow", "low", "medium", "high", "ultrahigh" ]
    infoImgPattern = "#ui/images/settings/shadowQuality/%s"
  }
  waterEffectsQuality = { widgetType = "value_slider" def = "high" blk = "graphics/waterEffectsQuality" restart = false
    values = [ "low", "medium", "high" ]
    infoImgPattern = "#ui/images/settings/waterFxQuality/%s"
  }
  compatibilityShadowQuality = { widgetType = "value_slider" def = "low" blk = "graphics/compatibilityShadowQuality" restart = false
    values = [ "low", "medium" ]
    infoImgPattern = "#ui/images/settings/compShadowQuality/%s"
  }
  fxResolutionQuality = { widgetType = "value_slider" def = "high" blk = "graphics/fxTarget" restart = false
    onChanged = "fxResolutionClick"
    values = [ "low", "medium", "high", "ultrahigh" ]
    infoImgPattern = "#ui/images/settings/fxQuality/%s"
  }
  selfReflection = { widgetType = "checkbox" def = true blk = "render/selfReflection" restart = false
  }
  backgroundScale = { widgetType = "slider" def = 2 min = 0 max = 2 blk = "graphics/backgroundScale" restart = false
    blkValues = [ 0.7, 0.85, 1.0 ]
    getValueFromConfig = function(blk, desc) {
      return getBlkValueByPath(blk, desc.blk, 1.0)
    }
    enabled = @() canDoBackgroundScale()
    setGuiValueToConfig = function(blk, desc, val) {
      local res = getTblValue(val, desc.blkValues, desc.def)
      if (getGuiValue("ssaa") == "4X" && !getGuiValue("compatibilityMode"))
        res = 2.0
      setBlkValueByPath(blk, desc.blk, res)
    }
    infoImgPattern = "#ui/images/settings/resolution/%s"
    configValueToGuiValue = function(val) {
      if (getGuiValue("ssaa") == "4X" && !getGuiValue("compatibilityMode"))
        val = 2.0
      return ::find_nearest(val, this.blkValues)
    }
  }
  landquality = { widgetType = "slider" def = 0 min = 0 max = 4 blk = "graphics/landquality" restart = false
    onChanged = "landqualityClick"
    infoImgPattern = "#ui/images/settings/terrainQuality/%s"
    availableInfoImgVals = [0, 1, 2, 3, 4]
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
    infoImgPattern = "#ui/images/settings/rendinstRange/%s"
    availableInfoImgVals = [50, 100, 150, 200, 250, 300, 350]
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
    infoImgPattern = "#ui/images/settings/cloudQuality/%s"
    availableInfoImgVals = [0, 1, 2]
  }
  panoramaResolution = { widgetType = "slider" def = 8 min = 4 max = 16 blk = "graphics/panoramaResolution" restart = false
    getValueFromConfig = function(blk, desc) { return getBlkValueByPath(blk, desc.blk, desc.def * 256) }
    setGuiValueToConfig = function(blk, desc, val) { setBlkValueByPath(blk, desc.blk, val * 256) }
    configValueToGuiValue = @(val)(val / 256).tointeger()
    infoImgPattern = "#ui/images/settings/panoramaQuality/%s"
    availableInfoImgVals = [7, 10, 13, 16]
  }
  fxDensityMul = { widgetType = "slider" def = 100 min = 20 max = 100 blk = "graphics/fxDensityMul" restart = false
    getValueFromConfig = function(blk, desc) { return getBlkValueByPath(blk, desc.blk, desc.def / 100.0)}
    setGuiValueToConfig = function(blk, desc, val) { setBlkValueByPath(blk, desc.blk, val / 100.0) }
    configValueToGuiValue = @(val)(val * 100).tointeger()
    infoImgPattern = "#ui/images/settings/fxDensity/%s"
    availableInfoImgVals = [20, 40, 60, 80, 100]
  }
  physicsQuality = { widgetType = "slider" def = 3 min = 0 max = 5 blk = "graphics/physicsQuality" restart = false
  }
  grassRadiusMul = { widgetType = "slider" def = 80 min = 10 max = 180 blk = "graphics/grassRadiusMul" restart = false
    getValueFromConfig = function(blk, desc) { return getBlkValueByPath(blk, desc.blk, desc.def / 100.0) }
    setGuiValueToConfig = function(blk, desc, val) { setBlkValueByPath(blk, desc.blk, val / 100.0) }
    configValueToGuiValue = @(val)(val * 100).tointeger()
    infoImgPattern = "#ui/images/settings/grassRange/%s"
    availableInfoImgVals = [10, 55, 100, 145, 180]
  }
  tireTracksQuality = { widgetType = "value_slider" def = "none" blk = "graphics/tireTracksQuality" restart = false
    values = [ "none", "medium", "high", "ultrahigh" ]
    configValueToGuiValue = @(val) this.values[val]
    getValueFromConfig = function(blk, desc) {
      return getBlkValueByPath(blk, desc.blk, 0)
    }
    setGuiValueToConfig = function(blk, desc, val) {
      let res = desc.values.indexof(val) ?? 0
      setBlkValueByPath(blk, desc.blk, res)
    }
    infoImgPattern = "#ui/images/settings/trackMarks/%s"
  }
  waterQuality = { widgetType = "value_slider" def = "high" blk = "graphics/waterQuality" restart = false
    values = [ "low", "medium", "high", "ultrahigh" ]
    infoImgPattern = "#ui/images/settings/waterQuality/%s"
  }
  giQuality = { widgetType = "value_slider" def = "low" blk = "graphics/giQuality" restart = false
    values = [ "low", "medium", "high" ], isVisible = @() true
    infoImgPattern = "#ui/images/settings/GI/%s"
  }
  dirtSubDiv = { widgetType = "value_slider" def = "high" blk = "graphics/dirtSubDiv" restart = false
    values = [ "high", "ultrahigh" ]
    getValueFromConfig = function(blk, desc) {
      return getBlkValueByPath(blk, desc.blk, 1)
    }
    setGuiValueToConfig = function(blk, desc, val) {
      let res = (val == "ultrahigh") ? 2 : 1
      setBlkValueByPath(blk, desc.blk, res)
    }
    configValueToGuiValue = @(val)(val == 2) ? "ultrahigh" : "high"
    infoImgPattern = "#ui/images/settings/terrainDeformation/%s"
  }
  ssaoQuality = { widgetType = "slider" def = 0 min = 0 max = 2 blk = "render/ssaoQuality" restart = false
    onChanged = "ssaoQualityClick"
    infoImgPattern = "#ui/images/settings/ssao/%s"
    availableInfoImgVals = [0, 1, 2]
  }
  ssrQuality = { widgetType = "slider" def = 0 min = 0 max = 2 blk = "render/ssrQuality" restart = false
    onChanged = "ssrQualityClick"
    infoImgPattern = "#ui/images/settings/ssr/%s"
    availableInfoImgVals = [0, 1, 2]
  }
  shadows = { widgetType = "checkbox" def = true blk = "render/shadows" restart = false
  }
  advancedShore = { widgetType = "checkbox" def = false blk = "graphics/advancedShore" restart = false
    infoImgPattern = "#ui/images/settings/advancedShores/%s"
  }
  mirrorQuality = { widgetType = "slider" def = 5 min = 0 max = 10 blk = "graphics/mirrorQuality" restart = false
    infoImgPattern = "#ui/images/settings/mirrorQuality/%s"
    availableInfoImgVals = [0, 1, 3, 5, 8, 10]
  }
  motionBlurStrength = { widgetType = "slider" def = 0 min = 0 max = 10 blk = "graphics/motionBlurStrength" restart = false
    enabled = @() !getGuiValue("compatibilityMode")
  }
  motionBlurCancelCamera = { widgetType = "checkbox" def = false blk = "graphics/motionBlurCancelCamera" restart = false
    enabled = @() !getGuiValue("compatibilityMode")
  }
  haze = { widgetType = "checkbox" def = false blk = "render/haze" restart = false
    infoImgPattern = "#ui/images/settings/haze/%s"
  }
  lastClipSize = { widgetType = "checkbox" def = false blk = "graphics/lastClipSize" restart = false
    getValueFromConfig = function(blk, desc) { return getBlkValueByPath(blk, desc.blk, 4096) }
    setGuiValueToConfig = function(blk, desc, val) { setBlkValueByPath(blk, desc.blk, (val ? 8192 : 4096)) }
    configValueToGuiValue = @(val) val == 8192 ? true : false
    infoImgPattern = "#ui/images/settings/farTerrain/%s"
  }
  lenseFlares = { widgetType = "checkbox" def = false blk = "graphics/lenseFlares" restart = false
    infoImgPattern = "#ui/images/settings/lensFlare/%s"
  }
  jpegShots = { widgetType = "checkbox" def = true blk = "debug/screenshotAsJpeg" restart = false }
  hiResShots = { widgetType = "checkbox" def = false blk = "debug/screenshotHiRes" restart = false enabled = @() getGuiValue("ssaa") == "4X" }
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
    enabled = @() is_platform_windows && (platformId == "win64" || is_dev_version()) && !getGuiValue("compatibilityMode")
    onChanged = "vrModeClick"
  }
  vrMirror = { widgetType = "list" def = "left" blk = "video/vreye" restart = false values = [ "left", "right", "both" ]
  }
  vrStreamerMode = { widgetType = "checkbox" def = false blk = "video/vrStreamerMode" restart = false
  }
  displacementQuality = { widgetType = "slider" def = 2 min = 0 max = 4 blk = "graphics/displacementQuality" restart = false
    infoImgPattern = "#ui/images/settings/terrainDisplacement/%s"
    availableInfoImgVals = [0, 1, 2, 3, 4]
  }
  contactShadowsQuality = { widgetType = "slider" def = 0 min = 0 max = 2 blk = "graphics/contactShadowsQuality" restart = false
    onChanged = "contactShadowsQualityClick"
    infoImgPattern = "#ui/images/settings/contactShadows/%s"
    availableInfoImgVals = [0, 1, 2]
  }
  riGpuObjects = { widgetType = "checkbox" def = true blk = "graphics/riGpuObjects" restart = false
  }
  rayTracing = { widgetType = "list" def = "off" blk = "graphics/bvhMode" restart = false enabled = hasRT
    values = ["off", "low", "medium", "high", "ultra", "custom"]
    onChanged = "rayTracingClick" isVisible = isRTVisible
    infoImgPattern = "#ui/images/settings/rtQuality/%s"
  }
  bvhDistance = { widgetType = "slider" def = 3000 min = 1000 max = 6000 blk = "graphics/bvhRiGenRange" restart = false enabled = hasRTGUI
  isVisible = isRTVisible
    infoImgPattern = "#ui/images/settings/bvhDistance/%s"
    availableInfoImgVals = [1000, 2650, 4300, 6000]
  }
  rtao = { widgetType = "value_slider" def = "off" blk = "graphics/RTAOQuality" restart = false
    values = ["off", "low", "medium", "high"] enabled = hasRTGUI
    onChanged = "rtOptionChanged" isVisible = isRTAOVisible
    infoImgPattern = "#ui/images/settings/rtAOQuality/%s"
  }
  rtsm = { widgetType = "value_slider" def = "off" blk = "graphics/enableRTSM" restart = false
    values = [ "off", "sun", "sun_and_dynamic" ]
    enabled = hasRTGUI
    onChanged = "rtOptionChanged" isVisible = isRTSMVisible
    infoImgPattern = "#ui/images/settings/rtShadows/%s"
  }
  rtr = { widgetType = "value_slider" def = "off" blk = "graphics/RTRQuality" restart = false
    values = ["off", "low", "medium", "high"]
    enabled = hasRTGUI
    onChanged = "rtrClick" isVisible = isRTVisible
    infoImgPattern = "#ui/images/settings/rtReflections/%s"
  }
  rtrRes = { widgetType = "value_slider" def = "half" blk = "graphics/RTRRes" restart = false
    values = ["half", "full"]
    enabled = hasRTR
    onChanged = "rtOptionChanged" isVisible = isRTVisible
    infoImgPattern = "#ui/images/settings/rtResolution/%s"
  }
  rtrWater = { widgetType = "checkbox" def = false blk = "graphics/RTRWater" restart = false
    enabled = hasRTGUI
    onChanged = "rtrWaterClick" isVisible = isRTVisible
    infoImgPattern = "#ui/images/settings/rtWater/%s"
  }
  rtrWaterRes = { widgetType = "value_slider" def = "half" blk = "graphics/RTRWaterRes" restart = false
    values = ["half", "full"]
    enabled = hasRTRWater
    onChanged = "rtOptionChanged" isVisible = isRTVisible
    infoImgPattern = "#ui/images/settings/rtWaterResolution/%s"
  }
  rtrTranslucent = { widgetType = "value_slider" def = "off" blk = "graphics/RTRTranslucent" restart = false
    values = ["off", "medium", "high"]
    enabled = hasRTGUI
    onChanged = "rtOptionChanged" isVisible = isRTVisible
    infoImgPattern = "#ui/images/settings/rtTransQuality/%s"
  }
}
//------------------------------------------------------------------------------
function validateInternalConfigs() {
  let errorsList = []
  foreach (id, desc in mSettings) {
    let widgetType = getTblValue("widgetType", desc)
    if (!isInArray(widgetType, ["list", "slider", "value_slider", "checkbox", "editbox", "tabs"]))
      errorsList.append(logError("sysopt.validateInternalConfigs()",
        $"Option '{id}' - 'widgetType' invalid or undefined."))
    if ((!("blk" in desc) || type(desc.blk) != "string" || !desc.blk.len()) && (!("getValueFromConfig" in desc) || !("setGuiValueToConfig" in desc)))
      errorsList.append(logError("sysopt.validateInternalConfigs()",
        $"Option '{id}' - 'blk' invalid or undefined. It can be undefined only when both getValueFromConfig & setGuiValueToConfig are defined."))
    if (("onChanged" in desc) && type(desc.onChanged) != "function")
      errorsList.append(logError("sysopt.validateInternalConfigs()",
        $"Option '{id}' - 'onChanged' function not found in sysopt.shared."))

    let def = getTblValue("def", desc)
    if (def == null)
      errorsList.append(logError("sysopt.validateInternalConfigs()",
        $"Option '{id}' - 'def' undefined."))

    let uiType = desc.uiType
    if ( widgetType == "checkbox" ) {
      if (def != null && uiType != "bool")
        errorsList.append(logError("sysopt.validateInternalConfigs()",
          $"Option '{id}' - 'widgetType'/'def' conflict."))
    }
    else if ( widgetType == "slider" ) {
      if (def != null && uiType != "integer")
        errorsList.append(logError("sysopt.validateInternalConfigs()",
          $"Option '{id}' - 'widgetType'/'def' conflict."))
      let invalidVal = -1
      let vMin = desc?.min ?? invalidVal
      let vMax = desc?.max ?? invalidVal
      let safeDef = (def != null) ? def : invalidVal
      if (!("min" in desc) || !("max" in desc) || type(vMin) != uiType || type(vMax) != uiType
          || vMin > vMax || vMin > safeDef || safeDef > vMax)
        errorsList.append(logError("sysopt.validateInternalConfigs()",
          $"Option '{id}' - 'min'/'def'/'max' conflict."))
    }
    else if ( widgetType == "value_slider") {
      if (!desc?.values.len())
        errorsList.append(logError("sysopt.validateInternalConfigs()",
          $"Option '{id}' - 'values' is empty or undefined."))
    }
    else if ( widgetType == "list" || widgetType ==  "tabs") {
      if (def != null && uiType != "string")
        errorsList.append(logError("sysopt.validateInternalConfigs()",
          $"Option '{id}' - 'widgetType'/'def' conflict."))
      let values = getTblValue("values", desc, [])
      if (!values.len())
        errorsList.append(logError("sysopt.validateInternalConfigs()",
          $"Option '{id}' - 'values' is empty or undefined."))
      if (def != null && values.len() && !isInArray(def, values))
        errorsList.append(logError("sysopt.validateInternalConfigs()",
          $"Option '{id}' - 'def' is not listed in 'values'."))
    }
    else if ( widgetType == "editbox" ) {
      if (def != null && uiType != "integer" && uiType != "float" && uiType != "string")
        errorsList.append(logError("sysopt.validateInternalConfigs()",
                                   $"Option '{id}' - 'widgetType'/'def' conflict."))
      let maxlength = getTblValue("maxlength", desc, -1)
      if (maxlength < 0 || (def != null && def.tostring().len() > maxlength))
        errorsList.append(logError("sysopt.validateInternalConfigs()",
          $"Option '{id}' - 'maxlength'/'def' conflict."))
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

  foreach (section in mUiStruct) {
    let { id = null, items = null } = section
    let ids = items ? items : id ? [ id ] : []
    foreach (itemId in ids)
      if (!(itemId in mSettings))
        errorsList.append(logError("sysopt.validateInternalConfigs()",
          $"Array uiStruct - Option '{itemId}' not found in 'settings' table."))
  }

  mScriptValid = !errorsList.len()
  if (is_dev_version())
    mValidationError = "\n".join(errorsList, true)
  if (!mScriptValid) {
    let errorString = "\n".join(errorsList, true) // warning disable: -declared-never-used
    script_net_assert_once("system_options_not_valid", "not valid system option list")
  }
}

function configRead() {
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

function configWrite() {
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
      log($"[sysopt] {id}: {mCfgInitial?[id] ?? "null"} -> {value}")
    let desc = getOptionDesc(id)
    if ("setGuiValueToConfig" in desc)
      desc.setGuiValueToConfig(mBlk, desc, value)
    else
      setBlkValueByPath(mBlk, desc.blk, value)
  }

  mBlk.saveToTextFile(get_config_name())
  log("[sysopt] Config saved.")
}

function init() {
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
}

function configFree() {
  mBlk = null
  mHandler = null
  mContainerObj = null
  mCfgInitial = {}
  mCfgCurrent = {}
}

function resetGuiOptions() {
  foreach (id, value in mCfgInitial) {
    setGuiValue(id, value)
  }
  updateGuiNavbar()
}

function onGuiLoaded() {
  if (!mScriptValid)
    return

  mShared.setCustomSettings()
  mShared.presetCheck()
  updateGuiNavbar(true)
}

function onGuiUnloaded() {
  updateGuiNavbar(false)
}

function configMaintain() {
  if (mMaintainDone)
    return
  mMaintainDone = true
  if (!is_platform_pc)
    return
  if (!mScriptValid)
    return

  if (getSystemConfigOption("graphicsQuality", "high") == "user") { // Need to reset
    let isCompatibilityMode = getSystemConfigOption("video/compatibilityMode", false)
    setSystemConfigOption("graphicsQuality", isCompatibilityMode ? "ultralow" : "high")
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

function applyRestartEngine(reloadScene = false) {
  mCfgApplied = {}
  foreach (id, value in mCfgCurrent)
    mCfgApplied[id] <- value

  log("[sysopt] Resetting renderer.")
  applyRendererSettingsChange(reloadScene, true)
}

let isReloadSceneRerquired = @() mCfgApplied.resolution != mCfgCurrent.resolution
  || mCfgApplied.mode != mCfgCurrent.mode
  || mCfgApplied.enableVr != mCfgCurrent.enableVr

function onRestartClient() {
  configWrite()
  configFree()
  applyRestartClient()
}

function hotReloadOrRestart() {
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
      let message = "\n".concat(loc("msgbox/client_restart_required"), loc("msgbox/restart_now"))
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

function onConfigApply() {
  if (!mScriptValid)
    return

  if (!checkObj(mContainerObj))
    return

  mShared.presetCheck()
  onGuiUnloaded()
  hotReloadOrRestart()
}

function onConfigApplyWithoutUiUpdate() {
  if (!mScriptValid)
    return

  mShared.presetCheck()
  hotReloadOrRestart()
}

let isCompatibiliyMode = @() mCfgStartup?.compatibilityMode
  ?? getSystemConfigOption("video/compatibilityMode", false)

function onGuiOptionChanged(obj) {
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
  let {widgetType} = desc
  if ( widgetType == "checkbox" ) {
    value = raw == true
  }
  else if ( widgetType == "slider" ) {
    value = raw.tointeger()
  }
  else if ( widgetType == "list" || widgetType == "tabs" || widgetType == "value_slider") {
    value = desc.values[raw]
  }
  else if ( widgetType == "editbox") {
    let {uiType} = desc
    if (uiType == "integer")
      value = (regexp2(@"^\-?\d+$").match(strip(raw))) ? raw.tointeger() : null
    else if (uiType == "float")
      value = (regexp2(@"^\-?\d+(\.\d*)?$").match(strip(raw))) ? raw.tofloat() : null
    else if ( uiType == "string")
      value = raw.tostring()
    if (value == null) {
      value = curValue
      setGuiValue(id, value, false)
    }
  }

  if (value == curValue)
    return

  setGuiValue(id, value, true)
  if (("onChanged" in desc) && desc.onChanged)
    desc.onChanged()

  if (id != "graphicsQuality")
    mShared.presetCheck()
  updateGuiNavbar(true)

  tryUpdateOptionImage(id)
}

function fillGuiOptions(containerObj, handler) {
  if (!checkObj(containerObj) || !handler)
    return
  let guiScene = containerObj.getScene()

  if (!mScriptValid) {
    let msg = "\n".concat(loc("msgbox/internal_error_header"), mValidationError)
    let data = format("textAreaCentered { text:t='%s' size:t='pw,ph' }", stripTags(msg))
    guiScene.replaceContentFromText(containerObj, data, data.len(), handler)
    return
  }

  guiScene.setUpdatesEnabled(false, false)
  guiScene.replaceContent(containerObj, "%gui/options/systemOptions.blk", handler)
  mContainerObj = containerObj
  mHandler = handler


  configRead()
  let cb = "onSystemOptionChanged"
  local data = ""
  foreach (section in mUiStruct) {
    if (section.title == "options/rt" && !hasFeature("optionBVH"))
      continue
    let isTable = ("items" in section)
    let ids = isTable ? section.items : [ section.id ]
    let addTitleInfo = section?.addTitleInfo
      ? loc("ui/parentheses/space", { text = loc(section.addTitleInfo) }) : ""
    let titleText = "".concat(loc(section.title), addTitleInfo)
    let sectionHeader = format("optionBlockHeader { text:t='%s'; }", titleText)
    let sectionRow = format(
      "tr { optContainer:t='yes'; headerRow:t='yes'; td { cellType:t='left'; %s } optionHeaderLine{} }",
      sectionHeader
    )
    data = "".concat(data, sectionRow)
    foreach (id in ids) {
      if (id in platformDependentOpts && get_video_modes().len() == 0 && !is_platform_windows)  // Hiding resolution, mode, vsync.
        continue

      let desc = getOptionDesc(id)
      if (!(desc?.isVisible() ?? true))
        continue

      desc.widgetId = $"sysopt_{id}"
      local option = ""
      let { widgetType } = desc
      if ( widgetType == "checkbox" ) {
        let config = {
          id = desc.widgetId
          value = mCfgCurrent[id]
          cb = cb
        }
        option = create_option_switchbox(config)
      }
      else if ( widgetType == "slider" ) {
        desc.step <- desc?.step ?? max(1, round((desc.max - desc.min) / mMaxSliderSteps).tointeger())
        option = create_option_slider(desc.widgetId, mCfgCurrent[id], cb, true, "slider", desc)
      }
      else if ( widgetType == "value_slider" ) {
        desc.step <- 1
        desc.max <- desc.values.len() - 1
        let val = desc.values.findindex(@(v) v == mCfgCurrent[id])
        option = create_option_slider(desc.widgetId, val, cb, true, "slider", desc)
      }
      else if ( widgetType == "list" ) {
        option = getListOption(id, desc, cb)
      }
      else if ( widgetType == "tabs" ) {
        let raw = desc.values.indexof(mCfgCurrent[id]) ?? -1
        let items = []
        foreach (valueId in desc.values) {
          local warn = loc(format("options/%s_%s/comment", id, valueId), "")
          warn = warn.len() ? $"\n{colorize("badTextColor", warn)}" : ""

          items.append({
            text = localize(id, valueId)
            tooltip = "".concat(loc(format("guiHints/%s_%s", id, valueId)), warn)
          })
        }
        option = ::create_option_row_listbox(desc.widgetId, items, raw, cb, isTable)
      }
      else if ( widgetType == "editbox" ) {
        let raw = mCfgCurrent[id].tostring()
        option = ::create_option_editbox({
          id = desc.widgetId,
          value = raw,
          maxlength = desc.maxlength
        })
      }

      if (isTable) {
        let disabled = (desc?.enabled() ?? true) ? "no" : "yes"
        let requiresRestart = getTblValue("restart", desc, false)
        let optionName = loc($"options/{id}")
        let disabledTooltip = disabled == "yes" ? getDisabledOptionTooltip(id) : null
        let tooltipProp = disabledTooltip != null ? $" tooltip:t='{disabledTooltip}';" : ""
        let label = stripTags("".join([optionName, requiresRestart ? $"{nbsp}*" : $"{nbsp}{nbsp}"]))
        option = "".concat("tr { id:t='", id, "_tr'; disabled:t='", disabled, "' selected:t='no'", tooltipProp, "size:t='pw, ", mRowHeightScale,
          "@optContainerHeight' overflow:t='hidden' optContainer:t='yes'  on_hover:t='onOptionContainerHover' on_unhover='onOptionContainerUnhover'",
          " td { width:t='0.55pw'; cellType:t='left'; overflow:t='hidden'; height:t='", mRowHeightScale,
          "@optContainerHeight' optiontext {text:t='", label, "'} }",  " td { width:t='0.45pw'; cellType:t='right';  height:t='",
          mRowHeightScale, "@optContainerHeight' padding-left:t='@optPad'; cellSeparator{}", option, " } }"
        )
      }
      data = "".concat(data, option)
    }
  }

  guiScene.replaceContentFromText(guiScene.sysopts, data, data.len(), handler)
  guiScene.setUpdatesEnabled(true, true)
  onGuiLoaded()
}

function setQualityPreset(presetName, force = false) {
  if (mCfgInitial.len() == 0)
    configRead()

  setGuiValue("graphicsQuality", presetName, mHandler == null)
  getOptionDesc("graphicsQuality")?.onChanged(true)
  updateGuiNavbar(true)
  if (force)
    configWrite()
}

eventbus_subscribe("on_force_graphics_preset", function(event) {
  let {graphicsPreset} = event
  setQualityPreset(graphicsPreset, true)
})

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
  getSystemOptionInfoView = getOptionInfoView
}
