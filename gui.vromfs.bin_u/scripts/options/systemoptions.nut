
from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import is_hdr_available, is_perf_metrics_available,
  is_low_latency_available, has_ray_query
from "app" import is_dev_version, get_config_name
from "%scripts/utils_sa.nut" import findNearest
from "%scripts/options/optionsCtors.nut" import create_option_combobox, create_option_editbox, create_option_slider, create_option_switchbox, create_options_bar

let { has_enough_vram_for_rt = @() true } = require_optional("bvhSettings")
let u = require("%sqStdLibs/helpers/u.nut")
let DataBlock = require("DataBlock")
let { round } = require("math")
let { format, strip } = require("string")
let regexp2 = require("regexp2")
let { is_stereo_configured, configure_stereo } = require("vr")
let { get_available_monitors, get_monitor_info, get_antialiasing_options, get_antialiasing_upscaling_options,
  get_supported_generated_frames, is_dx12_supported, is_nvidia_gpu, is_amd_gpu,
  is_intel_gpu, getAutoGfxApi, getVideoModes, getDgsTexQuality } = require("graphicsOptions")
let applyRendererSettingsChange = require("%scripts/clientState/applyRendererSettingsChange.nut")
let { setBlkValueByPath, getBlkValueByPath, blkOptFromPath } = require("%globalScripts/dataBlockExt.nut")
let { get_primary_screen_info } = require("dagor.system")
let { was_screenshot_applied_to_config } = require("debug.config")
let { eachBlock } = require("%sqstd/datablock.nut")
let { applyRestartClient, canRestartClient
} = require("%scripts/utils/restartClient.nut")
let { stripTags } = require("%sqstd/string.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { getSystemConfigOption, setSystemConfigOption } = require("%globalScripts/systemConfig.nut")
let { eventbus_subscribe } = require("eventbus")
let { doesLocTextExist } = require("dagor.localize")
let { is_win64, is_windows, isPC, platformId, is_gdk } = require("%sqstd/platform.nut")
let { hardPersistWatched } = require("%sqstd/globalState.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { steam_is_running } = require("steam")
let { saveLocalAccountSettings, loadLocalAccountSettings,
NEED_SHOW_GRAPHICS_AA_SETTINGS_MODIFIED } = require("%scripts/clientState/localProfile.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")


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
local prevRtMode = null

let mQualityPresets = DataBlock()
mQualityPresets.load("%guiConfig/graphicsPresets.blk")

let isDx12Supported = hardPersistWatched("isDx12Supported", null)
function initIsDx12SupportedOnce() { 
  if (isDx12Supported.get() == null) {
    let is_dx12_sup = is_dx12_supported()
    isDx12Supported.set(is_win64 && is_dx12_sup)
  }
}







let compModeGraphicsOptions = {
  qualityPresetsOptions = {
    texQuality        = { compMode = true }
    anisotropy        = { compMode = true }
    lastClipSize      = { compMode = true }
    compatibilityMode = { compMode = true }
    riGpuObjects      = { fullMode = false }
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
      "latency_nvidia"
      "latency_amd"
      "latency_intel"
      "frameGeneration"
    ]
  }
  {
    title = "options/dlss_quality"
    items = [
      "graphicsQuality"
      "texQuality"
      "shadowQuality"
      "fxQuality"
      "fxDistortionStrength"
      "waterQuality"
      "waterEffectsQuality"
      "cloudsQuality"
      "panoramaResolution"
      "ssrQuality"
      "landquality"
      "ssaoQuality"
      "tireTracksQuality"
      "mirrorQuality"
      "giQuality"
      "physicsQuality"
      "displacementQuality"
      "volfogQuality"
    ]
  }
  {
    title = "options/renderer"
    items = [
      "rendinstDistMul"
      "grassRadiusMul"
      "contactShadowsQuality"
      "bloomQuality"
      "advancedShore"
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
      "ptgi"
      "rtao"
      "rtsmQuality"
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
  
]

let getGuiValue = @(id, defVal = null) (id in mCfgCurrent) ? mCfgCurrent[id] : defVal
let getOptionIdByObjId = @(objId) objId.slice(("sysopt_").len())

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

function tryGetOptionImageSrc(id, value = null) {
  value = value ?? mCfgCurrent?[id]
  if (value == null || value == "custom")
    return null
  let opt = getOptionDesc(id)
  let { infoImgPattern = null, availableInfoImgVals = null, imgInfoForDependentValueFn = null } = opt
  if (infoImgPattern == null && imgInfoForDependentValueFn == null)
    return null

  let { optRes = null, imgPatternRes = null } = imgInfoForDependentValueFn?(value)

  let imgPattern = imgPatternRes ?? infoImgPattern

  let imgVal = (optRes != null && imgPatternRes != null) ? optRes
    : availableInfoImgVals ? availableInfoImgVals[findNearest(value, availableInfoImgVals)]
    : value

  return format(imgPattern, imgVal.tostring().replace(" ",  ""))

}

function tryUpdateOptionImage(id) {
  let optInfoImg =   mHandler?.scene.findObject("option_info_image")
  if (!optInfoImg?.isValid())
    return
  optInfoImg["background-image"] = tryGetOptionImageSrc(id)
}

function getOptionInfoView(id) {
  let opt = getOptionDesc(id)
  let title = loc(opt?.titleLocId ?? $"options/{id}")
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
    preloadedImages = opt?.allInfoImgs
    hasImages = (opt?.allInfoImgs.len() ?? 0) > 0
  }
}

function onSystemOptionControlHover(obj) {
  if (!obj?.isValid() || !mHandler || obj?.idx == null)
    return
  let controlObjId = obj.getParent()?.getParent().id
  if (controlObjId == null)
    return
  let optId = getOptionIdByObjId(controlObjId)
  if (optId not in mSettings) 
    return                

  let desc = getOptionDesc(optId)
  let needHoverOnOptionRow = optId != mHandler.lastHoveredRowId?.split("_tr")[0]
  if (needHoverOnOptionRow)
    mHandler.onOptionContainerHover(mHandler.scene.findObject($"{optId}_tr"))

  let hoveredValue = desc.values[obj.idx.tointeger()]
  let imgSrc = tryGetOptionImageSrc(optId, hoveredValue)
  let imgObj = mHandler.scene.findObject("option_info_image")

  imgObj.show(imgSrc != null)
  if (imgSrc)
    imgObj["background-image"] = imgSrc
}

function configValueToGuiValue(id, value) {
  let desc = getOptionDesc(id)
  return desc?.configValueToGuiValue(value) ?? value
}

function validateGuiValue(id, value) {
  if (!isPC)
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
  else if ( widgetType == "list") {
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
  else if (widgetType == "button") {
    return desc?.def ?? value
  }
  return value
}

function getGuiWidget(id) {
  if (!(id in mSettings)) {
    logError("sysopt.getGuiWidget()", $"Option '{id}' is UNKNOWN. It must be added to sysopt.settings table.")
    return null
  }

  let widgetId = getOptionDesc(id)?.widgetId
  let obj = (widgetId && mContainerObj?.isValid()) ? mContainerObj.findObject(widgetId) : null
  return obj?.isValid() ? obj : null
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
    else if ( widgetType == "list" || widgetType == "options_bar") {
      raw = desc.values.indexof(value) ?? -1
    }
    else if ( widgetType == "editbox" ) {
      raw = value.tostring()
    }
    if (raw != null && obj.getValue() != raw) {
      desc.ignoreNextUiCallback = desc.widgetType != "checkbox"
      obj.setValue(raw)
    }
    if (widgetType == "options_bar")
      desc.updateText(mHandler?.scene.findObject($"sysopt_{id}"), value)
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
        let requiresRestart = desc?.restart
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

let canUseGraphicsOptions = @() isPC && hasFeature("GraphicsOptions")
let canShowGpuBenchmark = @() canUseGraphicsOptions()

local aaUseGui = false;

function updateGuiNavbar(show = true) {
  let scene = mHandler?.scene
  if (!scene?.isValid())
    return

  let showText = show && isRestartPending()
  let showRestartButton = showText && canRestartClient()
  let applyText = loc((show && !showRestartButton && isHotReloadPending()) ? "mainmenu/btnApply" : "mainmenu/btnOk")

  showObjById("btn_reset", show && isSavePending(), scene)
  showObjById("restart_suggestion", showText, scene)
  showObjById("btn_restart", showRestartButton, scene)
  showObjById("btn_gpu_benchmark", show && canShowGpuBenchmark(), scene)

  let objNavbarApplyButton = scene.findObject("btn_apply")
  if (objNavbarApplyButton?.isValid())
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
    mShared.graphicsQualityClick(true, true)
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
      optionId == "fxQuality" ||
      optionId == "tireTracksQuality" ||
      optionId == "waterQuality" ||
      optionId == "giQuality"
    ) {
    if (valueId == "none")
      return loc("options/none")
    return localizaQualityPreset(valueId)
  }
  return loc(format("options/%s_%s", optionId, valueId), valueId)
}

function parseResolution(resolution) {
  let sides = resolution == "auto"
    ? [ 0, 0 ] 
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
    let [name, version = null, replace_from = null, replace_to = null] = mode.split("|")
    local locName = localize("antialiasingMode", name)
    if (replace_from != null && replace_to != null)
      locName = locName.replace(replace_from, replace_to)
    let text = version != null
      ? " - v".concat(locName, version)
      : locName
    return { text }
  })
}

function antiAliasingUpscalingOptions(blk) {
  let aa = aaUseGui ? getGuiValue("antialiasingMode", "off") : getBlkValueByPath(blk, "video/antialiasing_mode", "off")
  let modesString = get_antialiasing_upscaling_options(aa)
  return modesString.split(";")
}

function supportedGeneratedFrames(blk) {
  let aa = aaUseGui ? getGuiValue("antialiasingMode", "off") : getBlkValueByPath(blk, "video/antialiasing_mode", "off")
  let mode = aaUseGui ? getGuiValue("mode", "fullscreen") : getBlkValueByPath(blk, "video/mode", "fullscreenwindowed")
  let frames = get_supported_generated_frames(aa, mode == "fullscreen")
  return frames
}

function supportedGeneratedFramesValues(blk) {
  let frames = supportedGeneratedFrames(blk)
  let modes = ["zero"]
  if (frames > 0)
    modes.append("one")
  if (frames > 1)
    modes.append("two")
  if (frames > 2)
    modes.append("three")
  return modes;
}

function hasAntialiasingUpscaling() {
  let aa = getGuiValue("antialiasingMode", "off")
  let modesString = get_antialiasing_upscaling_options(aa)
  return modesString.split(";").len() > 1
}

function getAvailableLatencyModes() {
  let values = ["off"]
  if (is_low_latency_available(1))
    values.append("on")
  if (is_low_latency_available(2))
    values.append("boost")

  return values;
}

function getFxDistortionAvailable() {
  let fxQualityStr = getGuiValue("fxQuality")
  return fxQualityStr == "high" || fxQualityStr == "ultrahigh"
}

let getAvailablePerfMetricsModes = @() perfValues.filter(@(_, id) id <= 1 || is_perf_metrics_available(id))

let is_platform_macosx = platformId == "macosx"
let hasRT = @() hasFeature("optionRT") && !is_platform_macosx && has_ray_query() && getGuiValue("graphicsQuality", "high") != "ultralow"
let hasRTGUI = @() getGuiValue("rayTracing", "off") != "off" && hasRT()
let hasRTAOGUI = @() getGuiValue("rayTracing", "off") != "off" && getGuiValue("ptao", "off") == "off" && hasRT()
let hasRTR = @() getGuiValue("rtr", "off") != "off" && hasRTGUI()
let hasRTRWater = @() getGuiValue("rtrWater", false) != false && hasRTGUI()

function isVsyncEnabledFromLowLatency() {
  if (is_nvidia_gpu()) {
    
    return getGuiValue("latency_nvidia", "off") == "off"
  }
  if (is_amd_gpu()) {
    
    return true
  }
  if (is_intel_gpu()) {
    
    return true
  }
  return true
}

log($"Options hasRT is {hasRT()}")
if (!hasRT()) {
  log($"optionRT is {hasFeature("optionRT")}")
  log($"macosx is {is_platform_macosx}")
  log($"has_ray_query is {has_ray_query()}")
  log($"ultalow is {getGuiValue("graphicsQuality", "high") == "ultralow"}")
}

function canDoBackgroundScale() {
  let mode = getGuiValue("antialiasingMode", "off")
  return !(mode == "dlss" || mode == "xess" || hasRTGUI())
}

function getOptionValueItems(id, desc) {
  let customItems = ("items" in desc) ? desc.items : null
  let items = []

  foreach (index, valueId in desc.values)
    items.append(customItems ? customItems[index] : localize(id, valueId))
  return items
}

function getListOption(id, desc, cb, onOptHoverFnName, needCreateList = true) {
  let raw = desc.values.indexof(mCfgCurrent[id]) ?? -1
  let items = getOptionValueItems(id, desc)
  return create_option_combobox(desc.widgetId, items, raw, cb, needCreateList, { onOptHoverFnName, controlStyle = "class:t='systemOption'" })
}

function updateOption(id) {
  let desc = getOptionDesc(id)
  if (!desc)
    return

  desc.init(null, desc)

  if (desc.widgetType == "list")
    setGuiValue(id, desc.values.indexof(getGuiValue(id)) ?? desc.def, true)
  else if (desc.widgetType == "options_bar") {
    let guiVal = getGuiValue(id)
    let val = desc.values.contains(guiVal) ? guiVal : desc.def
    setGuiValue(id, val)
  }

  let obj = getGuiWidget(id)
  if (!obj?.isValid())
    return

  local markup = ""
  let onChangeFnName = "onSystemOptionChanged"
  let onOptHoverFnName = "onSystemOptionControlHover"
  if (desc.widgetType == "list")
    markup = getListOption(id, desc, onChangeFnName, onOptHoverFnName, false)
  if (desc.widgetType == "options_bar") {
    let raw = desc.values.indexof(mCfgCurrent[id]) ?? -1
    let items = getOptionValueItems(id, desc)
    markup = create_options_bar(desc.widgetId, raw,
      localize(id, mCfgCurrent[id]), items, onChangeFnName, false, { onOptHoverFnName })
  }

  mContainerObj.getScene().replaceContentFromText(obj, markup, markup.len(), mHandler)
  if (desc.widgetType == "options_bar")
    obj.setValue(desc.values.indexof(mCfgCurrent[id]) ?? -1) 
}


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

  setCustomSettings = function() {
    mShared.setGraphicsQuality()
    mShared.setCompatibilityMode()
  }

  graphicsQualityClick = function(silent = false, skipRt = false) {
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
    if (!skipRt)
      mShared.rayTracingClick(silent)
  }

  presetCheck = function() {
    let preset = pickQualityPreset()
    setGuiValue("graphicsQuality", preset)
  }

  resolutionClick = function() {
    updateOption("antialiasingUpscaling")
  }

  modeClick = function() {
    aaUseGui = true

    enableGuiOption("monitor", getOptionDesc("monitor")?.enabled() ?? true)
    updateOption("frameGeneration")

    aaUseGui = false
  }

  antialiasingModeClick = function() {
    aaUseGui = true

    let canBgScale = canDoBackgroundScale()
    enableGuiOption("ssaa", canBgScale)
    enableGuiOption("antialiasingUpscaling", hasAntialiasingUpscaling())

    updateOption("antialiasingUpscaling")
    updateOption("frameGeneration")

    if (!canBgScale) {
      setGuiValue("ssaa", "none")
      setGuiValue("backgroundScale", 1.0)
    }

    aaUseGui = false
  }

  latencyClick = function() {
    if (!isVsyncEnabledFromLowLatency())
      setGuiValue("vsync", "vsync_off")
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
        updateOption("fxQuality")
        mShared.presetCheck()
        updateGuiNavbar(true)
      }
      function cancelFunc() {
        setGuiValue("ssaa", "none")
        updateOption("fxQuality")
        mShared.presetCheck()
        updateGuiNavbar(true)
      }
      scene_msg_box("msg_sysopt_ssaa", null, loc("msgbox/ssaa_warning"),
        [
          ["ok", okFunc],
          ["cancel", cancelFunc],
        ], "cancel",
        { cancel_fn = cancelFunc, checkDuplicateId = true })
    } else
      updateOption("fxQuality")
  }

  fxQualityClick = function() {
    if (getFxDistortionAvailable()) {
      enableGuiOption("fxDistortionStrength", true);
    }
    else {
      enableGuiOption("fxDistortionStrength", false);
    }

    if (getGuiValue("fxQuality") == "ultrahigh") {
      function okFunc() {
        setGuiValue("fxQuality", "ultrahigh")
        mShared.presetCheck()
        updateGuiNavbar(true)
      }
      function cancelFunc() {
        setGuiValue("fxQuality", "high")
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

    if (!rtIsOn) {
      setGuiValue("ptgi", "off")
      setGuiValue("rtao", "off")
      setGuiValue("rtr", "off")
      setGuiValue("rtrRes", "half")
      setGuiValue("rtsm", "off")
      setGuiValue("rtsmQuality", "low")
      setGuiValue("rtrWater", false)
      setGuiValue("rtrWaterRes", "half")
      setGuiValue("rtrTranslucent", "off")
    }
    if (rt == "low") {
      setGuiValue("bvhDistance", 1000)
      setGuiValue("ptgi", "off")
      setGuiValue("rtao", "low")
      setGuiValue("rtr", "low")
      setGuiValue("rtrRes", "half")
      setGuiValue("rtsm", "sun")
      setGuiValue("rtsmQuality", "low")
      setGuiValue("rtrWater", false)
      setGuiValue("rtrWaterRes", "half")
      setGuiValue("rtrTranslucent", "medium")
    } else if (rt == "medium") {
      setGuiValue("bvhDistance", 2000)
      setGuiValue("ptgi", "medium")
      setGuiValue("rtao", "off")
      setGuiValue("rtr", "medium")
      setGuiValue("rtrRes", "half")
      setGuiValue("rtsm", "sun")
      setGuiValue("rtsmQuality", "low")
      setGuiValue("rtrWater", true)
      setGuiValue("rtrWaterRes", "half")
      setGuiValue("rtrTranslucent", "medium")
    } else if (rt == "high") {
      setGuiValue("bvhDistance", 3000)
      setGuiValue("ptgi", "medium")
      setGuiValue("rtao", "off")
      setGuiValue("rtr", "high")
      setGuiValue("rtrRes", "half")
      setGuiValue("rtsm", "sun")
      setGuiValue("rtsmQuality", "medium")
      setGuiValue("rtrWater", true)
      setGuiValue("rtrWaterRes", "half")
      setGuiValue("rtrTranslucent", "high")
    } else if (rt == "ultra") {
      setGuiValue("bvhDistance", 4000)
      setGuiValue("ptgi", "medium")
      setGuiValue("rtao", "off")
      setGuiValue("rtr", "high")
      setGuiValue("rtrRes", "full")
      setGuiValue("rtsm", "sun_and_dynamic")
      setGuiValue("rtsmQuality", "high")
      setGuiValue("rtrWater", true)
      setGuiValue("rtrWaterRes", "full")
      setGuiValue("rtrTranslucent", "high")
    }

    enableGuiOption("bvhDistance", rtIsOn)
    enableGuiOption("rtr", rtIsOn)
    enableGuiOption("ptgi", rtIsOn)
    enableGuiOption("rtao", rtIsOn && getGuiValue("ptgi") == "off")
    enableGuiOption("rtsm", rtIsOn)
    enableGuiOption("rtsmQuality", rtIsOn)

    enableGuiOption("rtrWater", rtIsOn)
    enableGuiOption("rtrWaterRes", getGuiValue("rtrWater") && rtIsOn)

    enableGuiOption("rtrTranslucent", rtIsOn)
    enableGuiOption("rtrRes", getGuiValue("rtr") != "off" && rtIsOn)

    prevRtMode = rt
  }

  rayTracingClick = function(silent = false) {
    let rt = getGuiValue("rayTracing", "off")
    if (silent || rt == "off" || prevRtMode != "off") {
      mShared.rayTracingPresetHandler(rt)
      enableGuiOption("ssaa", true)
      mShared.ssaaClick()

      return
    }

    function okFunc() {
      mShared.rayTracingPresetHandler(rt)
      setGuiValue("ssaa", "none")
      enableGuiOption("ssaa", false)
      mShared.ssaaClick()
    }
    function cancelFunc() {
      setGuiValue("rayTracing", "off")
      mShared.rayTracingPresetHandler("off")
      enableGuiOption("ssaa", true)
      mShared.ssaaClick()
    }
    scene_msg_box("msg_sysopt_rt", null, loc("msgbox/rt_warning"),
      [
        ["ok", okFunc],
        ["cancel", cancelFunc],
      ], "cancel",
      { cancel_fn = cancelFunc, checkDuplicateId = true })
  }

  vrModeClick = function() {
    updateOption("antialiasingMode")
    updateOption("antialiasingUpscaling")
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

  getVideoResolution = function(curResolution = null, isNeedAuto = true) {
    let minW = 1024
    let minH = 720

    let list = getVideoModes()
    let isListTruncated = list.len() <= 1
    if (isNeedAuto)
      list.append("auto")
    if (curResolution != null && list.indexof(curResolution) == null)
      list.append(curResolution)

    let data = list.map(parseResolution).filter(@(r)
      (r.w >= minW && r.h >= minH) || r.resolution == curResolution || r.resolution == "auto")

    let sortFunc = @(a, b) a.w <=> b.w  || a.h <=> b.h
    data.sort(sortFunc)

    
    
    if (isListTruncated && (is_windows || platformId == "macosx")) {
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
    let modes = mShared.getVideoResolution(null)
    let value = getBlkValueByPath(blk, desc.blk, "")

    let isListed = modes.indexof(value) != null
    if (isListed) 
      return value

    let looksReliable = regexp2(@"^\d+ x \d+$").match(value)
    if (looksReliable) 
      return value

    if (value == "auto")
      return value

    let screen = format("%d x %d", screen_width(), screen_height())
    return screen 

    
















  }
}



























mSettings = {
  gfx_api = { widgetType = "list" def = "auto" blk = "video/driver" restart = true
    init = function(_blk, desc) {
      initIsDx12SupportedOnce()
      desc.values <- [ "auto", "dx11" ]

      if (isDx12Supported.get())
        desc.values.append("dx12")

      if (is_win64 && hasFeature("optionGFXAPIVulkan"))
        desc.values.append("vulkan")

      desc.items <- desc.values.map(function(value) {
        let optionLocText = loc($"options/gfx_api_{value}")
        if (is_win64 && value == "auto")
          return { text = "".concat(optionLocText, loc("ui/parentheses/space", {text = loc($"options/gfx_api_{getAutoGfxApi()}") })) }
        if (is_win64 && value == "vulkan")
          return { text = "".concat(optionLocText, loc("ui/parentheses/space", { text = "beta" })) }
        return { text = optionLocText }
      })
      desc.def <- desc.values[0]
    }
    onChanged = "gfxApiClick"
    isVisible = @() is_win64
  }
  resolution = { widgetType = "list" def = "1024 x 768" blk = "video/resolution" restart = true
    init = function(blk, desc) {
      let curResolution = mShared.getCurResolution(blk, desc)
      desc.values <- mShared.getVideoResolution(curResolution)
      desc.def <- curResolution
      desc.restart <- !is_windows
    }
    onChanged = "resolutionClick"
  }
  mode = { widgetType = "list" def = "fullscreenwindowed" blk = "video/mode" restart = true
    init = function(_blk, desc) {
      desc.values <-
        (is_windows && is_gdk)
        ? ["windowed", "fullscreenwindowed"]
        : (is_windows
          ? ["windowed", "fullscreenwindowed", "fullscreen"]
          : ["windowed", "fullscreen"]
        )
      desc.def = desc.values.top()
      desc.restart <- !is_windows
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
      desc.restart <- !is_windows
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
    enabled = @() isVsyncEnabledFromLowLatency() && getGuiValue("frameGeneration", "zero") == "zero"
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
    hidden_values = { low_fxaa = "low_fxaa", high_fxaa = "high_fxaa", taa = "taa", tsr = "tsr" }
    enabled = @() !getGuiValue("compatibilityMode")
    infoImgPattern = "#ui/images/settings/antiAliasing/%s"
  }

  antialiasingUpscaling = { widgetType = "list" def = "native" blk = "video/antialiasing_upscaling" restart = false
    init = function(blk, desc) {
      desc.values <- antiAliasingUpscalingOptions(blk)
      desc.def = "native"
      if (desc.values.len() > 0 && !desc.values.contains(desc.def))
        desc.def = desc.values[0]
    }
    enabled = @() hasAntialiasingUpscaling() && !getGuiValue("compatibilityMode")
    infoImgPattern = "#ui/images/settings/upscaling/%s"
    needSkipCheckSystemConfigValue = true
  }

  antialiasingSharpening = { widgetType = "button" def = 0 blk = "video/antialiasing_sharpening" restart = false
    enabled = @() !getGuiValue("compatibilityMode")
    onClick = "onPostFxSettings"
    btnLocId = "options/setInPostFxSettings"
    delayed = true
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
  anisotropy = { widgetType = "options_bar" def = "2X" blk = "graphics/anisotropy" restart = false
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
  latency_nvidia = { widgetType = "list" def = "off" blk = "video/latency" restart = false
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
    enabled = @() getGuiValue("frameGeneration", "zero") == "zero"
    isVisible = @() is_nvidia_gpu()
  }
  latency_amd = { widgetType = "list" def = "off" blk = "video/latency" restart = false
    init = function(_blk, desc) {
      desc.values <- getAvailableLatencyModes()
      desc.items <- desc.values.map(@(value) { text = localize("latency", value) })
    }
    getValueFromConfig = function(blk, desc) {
      return getBlkValueByPath(blk, desc.blk, -1)
    }
    setGuiValueToConfig = function(blk, desc, val) {
      let quality = (val == "on") ? 1 : 0
      setBlkValueByPath(blk, desc.blk, quality)
    }
    configValueToGuiValue = function(val) {
      return (val == 0) ? "off" : "on"
    }
    onChanged = "latencyClick"
    enabled = @() getGuiValue("frameGeneration", "zero") == "zero"
    isVisible = @() is_amd_gpu()
  }
  latency_intel = { widgetType = "list" def = "off" blk = "video/latency" restart = false
    init = function(_blk, desc) {
      desc.values <- getAvailableLatencyModes()
      desc.items <- desc.values.map(@(value) { text = localize("latency", value) })
    }
    getValueFromConfig = function(blk, desc) {
      return getBlkValueByPath(blk, desc.blk, -1)
    }
    setGuiValueToConfig = function(blk, desc, val) {
      let quality = (val == "on") ? 1 : 0
      setBlkValueByPath(blk, desc.blk, quality)
    }
    configValueToGuiValue = function(val) {
      return (val == 0) ? "off" : "on"
    }
    onChanged = "latencyClick"
    enabled = @() getGuiValue("frameGeneration", "zero") == "zero"
    isVisible = @() is_intel_gpu()
  }
  frameGeneration = { widgetType = "options_bar" def = "zero" blk = "video/antialiasing_fgc" restart = steam_is_running()
    init = function(blk, desc) {
      desc.values <- supportedGeneratedFramesValues(blk)
      desc.items <- desc.values.map(@(value) { text = localize("framegen", value), tooltip = loc($"guiHints/framegen_{value}") })
    }
    getValueFromConfig = function(blk, desc) {
      return getBlkValueByPath(blk, desc.blk, 0)
    }
    setGuiValueToConfig = function(blk, desc, val) {
      let num = (val == "one") ? 1 : (val == "two") ? 2 : (val == "three") ? 3 : (val == "four") ? 4 : 0
      setBlkValueByPath(blk, desc.blk, num)
    }
    configValueToGuiValue = function(val) {
      return (val == 1) ? "one" : (val == 2) ? "two" : (val == 3) ? "three" : (val == 4) ? "four" : "zero"
    }
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
      
      setBlkValueByPath(blk, desc.blk, perfValues.findindex(@(name) name == val) ?? -1)
    }
  }
  texQuality = { widgetType = "options_bar" def = "high" blk = "graphics/texquality" restart = false
    init = function(_blk, desc) {
      let dgsTQ = getDgsTexQuality() 
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
  shadowQuality = { widgetType = "options_bar" def = "high" blk = "graphics/shadowQuality" restart = false
    init = function(_blk, desc) {
      desc.values <- !getGuiValue("compatibilityMode") ? [ "low", "medium", "high", "ultrahigh" ] : ["ultralow"]
    }
    infoImgPattern = "#ui/images/settings/shadowQuality/%s"
  }
  volfogQuality = { widgetType = "options_bar" def = "low" blk = "graphics/volfogQuality" restart = false
    values = [ "off", "low", "medium", "high" ]
    isVisible = is_dev_version
  }
  waterEffectsQuality = { widgetType = "options_bar" def = "high" blk = "graphics/waterEffectsQuality" restart = false
    values = [ "low", "medium", "high" ]
    infoImgPattern = "#ui/images/settings/waterFxQuality/%s"
  }
  fxQuality = { widgetType = "options_bar" def = "medium" blk = "graphics/fxQuality" restart = false
    onChanged = "fxQualityClick"
    enabled = @() !getGuiValue("compatibilityMode")
    infoImgPattern = "#ui/images/settings/fxQuality/%s"
    init = function(blk, desc) {
      local hasSsaa = false
      let ssaaDesc = getOptionDesc("ssaa")
      if (ssaaDesc.enabled()) {
        let guiVal = getGuiValue("ssaa")
        let hasGuiValue = guiVal != null
        hasSsaa = hasGuiValue
          ? guiVal != "none"
          : ssaaDesc.getValueFromConfig(blk, ssaaDesc) != 1.0
      }
      if (!getGuiValue("compatibilityMode")) {
        desc.values <- hasSsaa
          ? [ "low", "medium", "high" ]
          : [ "low", "medium", "high", "ultrahigh" ]
      }
      else {
        desc.values <- ["ultralow"]
      }
    }
  }
  fxDistortionStrength = { widgetType = "slider" def = 100 min = 0 max = 100 blk = "graphics/fxDistortionStrength" restart = false
    titleLocId = "options/haze"
    enabled = @() getFxDistortionAvailable()
    getValueFromConfig = function(blk, desc) { return getBlkValueByPath(blk, desc.blk, desc.def / 100.0) }
    setGuiValueToConfig = function(blk, desc, val) { setBlkValueByPath(blk, desc.blk, val / 100.0) }
    configValueToGuiValue = @(val)(val * 100).tointeger()
    infoImgPattern = "#ui/images/settings/fxDistortionStrength/%s"
    availableInfoImgVals = [0, 20, 40, 60, 80, 100]
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
      local res = desc.blkValues?[val] ?? desc.def
      if (getGuiValue("ssaa") == "4X" && !getGuiValue("compatibilityMode"))
        res = 2.0
      setBlkValueByPath(blk, desc.blk, res)
    }
    infoImgPattern = "#ui/images/settings/resolution/%s"
    configValueToGuiValue = function(val) {
      if (getGuiValue("ssaa") == "4X" && !getGuiValue("compatibilityMode"))
        val = 2.0
      return findNearest(val, this.blkValues)
    }
  }
  landquality = { widgetType = "slider" def = 0 min = 0 max = 4 blk = "graphics/landquality" restart = false
    infoImgPattern = "#ui/images/settings/terrainQuality/%s"
    availableInfoImgVals = [0, 1, 2, 3, 4]
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
  physicsQuality = { widgetType = "slider" def = 3 min = 0 max = 5 blk = "graphics/physicsQuality" restart = false
  }
  grassRadiusMul = { widgetType = "slider" def = 80 min = 10 max = 180 blk = "graphics/grassRadiusMul" restart = false
    getValueFromConfig = function(blk, desc) { return getBlkValueByPath(blk, desc.blk, desc.def / 100.0) }
    setGuiValueToConfig = function(blk, desc, val) { setBlkValueByPath(blk, desc.blk, val / 100.0) }
    configValueToGuiValue = @(val)(val * 100).tointeger()
    infoImgPattern = "#ui/images/settings/grassRange/%s"
    availableInfoImgVals = [10, 55, 100, 145, 180]
  }
  tireTracksQuality = { widgetType = "options_bar" def = "none" blk = "graphics/tireTracksQuality" restart = false
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
  waterQuality = { widgetType = "options_bar" def = "high" blk = "graphics/waterQuality" restart = false
    values = [ "low", "medium", "high", "ultrahigh" ]
    infoImgPattern = "#ui/images/settings/waterQuality/%s"
  }
  giQuality = { widgetType = "options_bar" def = "low" blk = "graphics/giQuality" restart = false
    values = [ "low", "medium", "high" ], isVisible = @() true
    infoImgPattern = "#ui/images/settings/GI/%s"
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
  bloomQuality = { widgetType = "slider" def = 1 min = 0 max = 3 blk = "graphics/bloomQuality" restart = false
    enabled = @() !getGuiValue("compatibilityMode")
    getValueFromConfig = function(blk, desc) { return getBlkValueByPath(blk, desc.blk, desc.def)}
    setGuiValueToConfig = function(blk, desc, val) { setBlkValueByPath(blk, desc.blk, val) }
    infoImgPattern = "#ui/images/settings/bloomQuality/%s"
    availableInfoImgVals = [0, 1, 2, 3]
  }
  lastClipSize = { widgetType = "checkbox" def = false blk = "graphics/lastClipSize" restart = false
    getValueFromConfig = function(blk, desc) { return getBlkValueByPath(blk, desc.blk, 4096) }
    setGuiValueToConfig = function(blk, desc, val) { setBlkValueByPath(blk, desc.blk, (val ? 8192 : 4096)) }
    configValueToGuiValue = @(val) val == 8192
    infoImgPattern = "#ui/images/settings/farTerrain/%s"
  }
  lenseFlares = { widgetType = "checkbox" def = false blk = "graphics/lenseFlares" restart = false
    enabled = @() !getGuiValue("compatibilityMode")
    infoImgPattern = "#ui/images/settings/lensFlare/%s"
  }
  jpegShots = { widgetType = "checkbox" def = true blk = "debug/screenshotAsJpeg" restart = false }
  hiResShots = { widgetType = "checkbox" def = false blk = "debug/screenshotHiRes" restart = false enabled = @() getGuiValue("ssaa") == "4X" }
  compatibilityMode = { widgetType = "checkbox" def = false blk = "video/compatibilityMode" restart = true
    onChanged = "compatibilityModeClick"
  }
  enableHdr = { widgetType = "checkbox" def = false blk = "video/enableHdr" restart = true enabled = @() is_hdr_available() }
  enableVr = {
    widgetType = "checkbox"
    blk = "gameplay/enableVR"
    def = is_stereo_configured()
    getValueFromConfig = function(_blk, _desc) { return is_stereo_configured() }
    setGuiValueToConfig = function(blk, desc, val) {
      configure_stereo(val)
      return setBlkValueByPath(blk, desc.blk, val)
    }
    enabled = @() is_windows && (platformId == "win64" || is_dev_version()) && !getGuiValue("compatibilityMode")
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
    values = has_enough_vram_for_rt() ? ["off", "low", "medium", "high", "ultra", "custom"] : ["off"]
    onChanged = "rayTracingClick"
    infoImgPattern = "#ui/images/settings/rtQuality/%s"
    getValueFromConfig = function(blk, desc) {
      let isEnabled = getBlkValueByPath(blk, "graphics/enableBVH", false)
      if (!isEnabled)
        return "off"
      return getBlkValueByPath(blk, desc.blk, desc.def)
    }
    setGuiValueToConfig = function(blk, desc, val) {
      let rtIsOn = val != "off"
      setBlkValueByPath(blk, "graphics/enableBVH", rtIsOn)
      setBlkValueByPath(blk, desc.blk, val)
    }
  }
  bvhDistance = { widgetType = "slider" def = 3000 min = 1000 max = 6000 blk = "graphics/bvhRiGenRange" restart = false enabled = hasRTGUI
    infoImgPattern = "#ui/images/settings/bvhDistance/%s"
    availableInfoImgVals = [1000, 2650, 4300, 6000]
  }
  ptgi = { widgetType = "options_bar" def = "off" blk = "graphics/PTGIQuality" restart = false
    values = ["off", "medium"] enabled = hasRTGUI
    onChanged = "rtOptionChanged"
    infoImgPattern = "#ui/images/settings/ptGIQuality/%s"
  }
  rtao = { widgetType = "options_bar" def = "off" blk = "graphics/RTAOQuality" restart = false
    values = ["off", "low", "medium", "high"] enabled = hasRTAOGUI
    onChanged = "rtOptionChanged"
    infoImgPattern = "#ui/images/settings/rtAOQuality/%s"
  }
  rtsm = { widgetType = "options_bar" def = "off" blk = "graphics/enableRTSM" restart = false
    values = [ "off", "sun", "sun_and_dynamic" ]
    enabled = hasRTGUI
    onChanged = "rtOptionChanged"
    infoImgPattern = "#ui/images/settings/rtShadows/%s"
  }
  rtsmQuality = { widgetType = "options_bar" def = "low" blk = "graphics/RTSMQuality" restart = false
    values = [ "low", "medium", "high" ]
    enabled = hasRTGUI
    onChanged = "rtOptionChanged"
    infoImgPattern = "#ui/images/settings/rtShadowsQuality/%s"
  }
  rtr = { widgetType = "options_bar" def = "off" blk = "graphics/RTRQuality" restart = false
    values = ["off", "low", "medium", "high"]
    enabled = hasRTGUI
    onChanged = "rtrClick"
    infoImgPattern = "#ui/images/settings/rtReflections/%s"
  }
  rtrRes = { widgetType = "options_bar" def = "half" blk = "graphics/RTRRes" restart = false
    values = ["half", "full"]
    enabled = hasRTR
    onChanged = "rtOptionChanged"
    infoImgPattern = "#ui/images/settings/rtResolution/%s"
  }
  rtrWater = { widgetType = "checkbox" def = false blk = "graphics/RTRWater" restart = false
    enabled = hasRTGUI
    onChanged = "rtrWaterClick"
    infoImgPattern = "#ui/images/settings/rtWater/%s"
  }
  rtrWaterRes = { widgetType = "options_bar" def = "half" blk = "graphics/RTRWaterRes" restart = false
    values = ["half", "full"]
    enabled = hasRTRWater
    onChanged = "rtOptionChanged"
    infoImgPattern = "#ui/images/settings/rtWaterResolution/%s"
  }
  rtrTranslucent = { widgetType = "options_bar" def = "off" blk = "graphics/RTRTranslucent" restart = false
    values = ["off", "medium", "high"]
    enabled = hasRTGUI
    onChanged = "rtOptionChanged"
    infoImgPattern = "#ui/images/settings/rtTransQuality/%s"
  }
}

function validateInternalConfigs() {
  let errorsList = []
  foreach (id, desc in mSettings) {
    let widgetType = desc?.widgetType
    if (!isInArray(widgetType, ["list", "slider", "checkbox", "editbox", "options_bar", "button"]))
      errorsList.append(logError("sysopt.validateInternalConfigs()",
        $"Option '{id}' - 'widgetType' invalid or undefined."))
    if ((!("blk" in desc) || type(desc.blk) != "string" || !desc.blk.len()) && (!("getValueFromConfig" in desc) || !("setGuiValueToConfig" in desc)))
      errorsList.append(logError("sysopt.validateInternalConfigs()",
        $"Option '{id}' - 'blk' invalid or undefined. It can be undefined only when both getValueFromConfig & setGuiValueToConfig are defined."))
    if (("onChanged" in desc) && type(desc.onChanged) != "function")
      errorsList.append(logError("sysopt.validateInternalConfigs()",
        $"Option '{id}' - 'onChanged' function not found in sysopt.shared."))

    let def = desc?.def
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
    else if ( widgetType == "options_bar") {
      if (!desc?.values.len())
        errorsList.append(logError("sysopt.validateInternalConfigs()",
          $"Option '{id}' - 'values' is empty or undefined."))
    }
    else if ( widgetType == "list") {
      if (def != null && uiType != "string")
        errorsList.append(logError("sysopt.validateInternalConfigs()",
          $"Option '{id}' - 'widgetType'/'def' conflict."))
      let values = desc?.values ?? []
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
      let maxlength = desc?.maxlength ?? -1
      if (maxlength < 0 || (def != null && def.tostring().len() > maxlength))
        errorsList.append(logError("sysopt.validateInternalConfigs()",
          $"Option '{id}' - 'maxlength'/'def' conflict."))
    }
    else if (widgetType == "button") {
      let { onClick = null } = desc
      if (onClick == null)
        errorsList.append(logError("sysopt.validateInternalConfigs()", $"Option '{id}' - missing onClick."))
    }
  }

  eachBlock(mQualityPresets, function(v, k) {
    if (v.paramCount() == 0)
      errorsList.append(logError("sysopt.validateInternalConfigs()",
       $"Quality presets - 'qualityPresets' k='{k}' contains invalid data."))
    if (!(k in mSettings))
      errorsList.append(logError("sysopt.validateInternalConfigs()",
        $"Quality presets - k='{k}' is not found in 'settings' table."))
    let desc = getOptionDesc(k)
    if (desc?.needSkipCheckSystemConfigValue ?? false)
      return
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
  if (!mScriptValid)
    script_net_assert_once("system_options_not_valid",
      $"not valid system option list /*errorString = {"\n".join(errorsList, true)}*/")
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
  if (! isPC)
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

    if (!(desc?.isVisible() ?? true))
      continue

    if ("setGuiValueToConfig" in desc)
      desc.setGuiValueToConfig(mBlk, desc, value)
    else
      setBlkValueByPath(mBlk, desc.blk, value)
  }

  mBlk.saveToTextFile(get_config_name())
  log("[sysopt] Config saved.")
}

function getAllOptionInfoImages(opt) {
  let { widgetType, values = null, infoImgPattern = null, availableInfoImgVals = null, imgInfoForDependentValueFn = null } = opt
  local possibleImgValues = []

  if (widgetType == "list" || widgetType == "options_bar")
    possibleImgValues = values
  else if (widgetType == "slider")
    possibleImgValues = availableInfoImgVals
      ?? array(opt.max - opt.min + 1).map(@(_v, idx) (idx + opt.min))

  return possibleImgValues.map(function(val) {
    if (imgInfoForDependentValueFn) {
      let { optRes = null, imgPatternRes = null } = imgInfoForDependentValueFn(val)
      if (optRes != null && imgPatternRes != null)
        return { src = format(imgPatternRes, optRes) }
    }
    return { src = format(infoImgPattern, val.tostring()) }
  } )
}

function init() {
  let blk = blkOptFromPath(get_config_name())
  foreach (_id, desc in mSettings) {
    if ("init" in desc)
      desc.init(blk, desc)
    if (("onChanged" in desc) && type(desc.onChanged) == "string")
      desc.onChanged = (desc.onChanged in mShared) ? mShared[desc.onChanged] : null
    if ("infoImgPattern" in desc)
      desc.allInfoImgs <- getAllOptionInfoImages(desc)
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
  if (!isPC)
    return
  if (!mScriptValid)
    return

  let graphicsQuality = getSystemConfigOption("graphicsQuality", "high")
  if (graphicsQuality == "user") { 
    let isCompatibilityMode = getSystemConfigOption("video/compatibilityMode", false)
    setSystemConfigOption("graphicsQuality", isCompatibilityMode ? "ultralow" : "high")
  }

  if (getSystemConfigOption("graphics/bvhMode", "off") != "off") {
    if (is_platform_macosx || graphicsQuality == "ultralow" || !has_ray_query())
      setSystemConfigOption("graphics/bvhMode", "off")
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

  if (!mContainerObj?.isValid())
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

let isCompatibilityMode = @() mCfgStartup?.compatibilityMode
  ?? getSystemConfigOption("video/compatibilityMode", false)

function onGuiOptionChanged(obj) {
  let objId = obj?.isValid() ? obj.id : null
  if (!objId)
    return
  let id = getOptionIdByObjId(objId)

  let desc = getOptionDesc(id)
  if (!desc)
    return

  if (desc.ignoreNextUiCallback) {
    desc.ignoreNextUiCallback = false
    return
  }

  let curValue = mCfgCurrent?[id]
  if (curValue == null)  
    return

  local value = null
  let raw = obj.getValue()
  let {widgetType} = desc
  if (widgetType == "button")
    return

  if ( widgetType == "checkbox" ) {
    value = raw == true
  }
  else if ( widgetType == "slider" ) {
    value = raw.tointeger()
  }
  else if ( widgetType == "list" ) {
    value = desc.values[raw]
  }
  else if ( widgetType == "options_bar") {
    value = desc.values[raw]
    desc.updateText(obj, value)
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

function updateOptionsBarText(obj, val) {
  let id = getOptionIdByObjId(obj.id)
  let locVal = localize(id, val)
  obj.findObject($"{obj.id}_text_value").setValue(locVal)
}

function fillGuiOptions(containerObj, handler) {
  if (!containerObj?.isValid() || !handler)
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
  let onOptHoverFnName = "onSystemOptionControlHover"
  local data = ""
  foreach (section in mUiStruct) {
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
      if (id in platformDependentOpts && getVideoModes().len() == 0 && !is_windows)  
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
        desc.cssClass <- "systemOption"
        desc.step <- desc?.step ?? max(1, round((desc.max - desc.min) / mMaxSliderSteps).tointeger())
        option = create_option_slider(desc.widgetId, mCfgCurrent[id], cb, true, "slider", desc)
      }
      else if (widgetType == "options_bar") {
        let value = desc.values.findindex(@(v) v == mCfgCurrent[id])
        let items  = desc?.items ?? desc.values.map(@(v, idx) {
          text = localize(id, v)
          selected = idx == 0
        })

        option = create_options_bar(desc.widgetId, value, localize(id, mCfgCurrent[id]) items, cb, true, { onOptHoverFnName })
        desc.updateText <- updateOptionsBarText
      }
      else if ( widgetType == "list" ) {
        option = getListOption(id, desc, cb, onOptHoverFnName)
      }
      else if ( widgetType == "editbox" ) {
        let raw = mCfgCurrent[id].tostring()
        option = create_option_editbox({
          id = desc.widgetId,
          value = raw,
          maxlength = desc.maxlength
        })
      }
      else if (widgetType == "button") {
        option = handyman.renderCached(("%gui/commonParts/button.tpl"), {
          id = desc.widgetId,
          funcName = desc.onClick,
          delayed = desc?.delayed ?? false
          text = loc(desc?.btnLocId ?? "")
          buttonClass = "systemOption"
        })
      }

      if (isTable) {
        let disabled = (desc?.enabled() ?? true) ? "no" : "yes"
        let requiresRestart = desc?.restart ?? false
        let optionName = loc(desc?.titleLocId ?? $"options/{id}")
        let disabledTooltip = disabled == "yes" ? getDisabledOptionTooltip(id) : null
        let tooltipProp = disabledTooltip != null ? $" tooltip:t='{disabledTooltip}';" : ""
        let label = stripTags("".join([optionName, requiresRestart ? $"{nbsp}*" : $"{nbsp}{nbsp}"]))
        option = "".concat("tr { id:t='", id, "_tr'; disabled:t='", disabled, "' selected:t='no'", tooltipProp, "size:t='pw, ", mRowHeightScale,
          "@optContainerHeight' overflow:t='hidden' optContainer:t='yes' on_hover:t='onOptionContainerHover'",
          " td { width:t='0.50pw'; cellType:t='left'; overflow:t='hidden'; height:t='", mRowHeightScale,
          "@optContainerHeight' optiontext {text:t='", label, "'} }",  " td { width:t='0.50pw'; cellType:t='right';  height:t='",
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

function checkShowGraphicSettingsWasModified() {
  if (!isPC)
    return
  let needShow = loadLocalAccountSettings(NEED_SHOW_GRAPHICS_AA_SETTINGS_MODIFIED, true)
  if (!needShow)
    return

  saveLocalAccountSettings(NEED_SHOW_GRAPHICS_AA_SETTINGS_MODIFIED, false)
  let graphicsQuality = getSystemConfigOption("graphicsQuality", "high")
  if (graphicsQuality != "high")
    return

  scene_msg_box(
    "graphic_aa_settings_was_modified",
    null,
    loc("msgbox/graphic_aa_settings_was_modified"),
    [
      [
        "open_settings",
        @() broadcastEvent("showOptionsWnd", { group = "graphicsParameters" })
      ],
      ["continue", function() {}]
    ],
    "continue"
  )
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

eventbus_subscribe("on_force_graphics_preset_and_apply", function(event) {
  let {graphicsPreset} = event
  setQualityPreset(graphicsPreset, true)
  hotReloadOrRestart()
})


init()


return {
  fillSystemGuiOptions = fillGuiOptions
  resetSystemGuiOptions = resetGuiOptions
  onSystemGuiOptionChanged = onGuiOptionChanged
  onRestartClient = onRestartClient
  getVideoResolution = mShared.getVideoResolution
  isCompatibilityMode = isCompatibilityMode
  onSystemOptionsApply = onConfigApply
  canUseGraphicsOptions = canUseGraphicsOptions
  systemOptionsMaintain = configMaintain
  overrideUiStruct = @(struct) mUiStruct = struct
  setQualityPreset
  localizaQualityPreset
  onConfigApplyWithoutUiUpdate
  canShowGpuBenchmark
  getSystemOptionInfoView = getOptionInfoView
  onSystemOptionControlHover
  checkShowGraphicSettingsWasModified
}
