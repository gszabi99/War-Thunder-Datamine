//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { initGraphicsAutodetect, getGpuBenchmarkDuration, startGpuBenchmark,
  closeGraphicsAutodetect, getPresetFor60Fps, getPresetForMaxQuality,
  getPresetForMaxFPS, isGpuBenchmarkRunning } = require("gpuBenchmark")
let { setQualityPreset, canShowGpuBenchmark, onConfigApplyWithoutUiUpdate,
  localizaQualityPreset } = require("%scripts/options/systemOptions.nut")
let { secondsToString } = require("%scripts/time.nut")
let { get_charserver_time_sec } = require("chard")

let gpuBenchmarkPresets = [
  {
    presetId = "presetMaxQuality"
    getPresetNameFunc = getPresetForMaxQuality
  }
  {
    presetId = "presetMaxFPS"
    getPresetNameFunc = getPresetForMaxFPS
  }
  {
    presetId = "preset60Fps"
    getPresetNameFunc = getPresetFor60Fps
  }
]

local class GpuBenchmarkWnd (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/options/gpuBenchmark.blk"
  needUiUpdate = false
  timeEndBenchmark = -1
  selectedPresetName = ""

  function initScreen() {
    saveLocalAccountSettings("gpuBenchmark/seen", true)
    initGraphicsAutodetect()
    this.showSceneBtn("btnApply", false)
  }

  function updateProgressText() {
    let timeLeft = this.timeEndBenchmark - get_charserver_time_sec()
    if (timeLeft < 0) {
      this.scene.findObject("progressText").setValue("")
      return
    }

    let timeText = secondsToString(timeLeft, true, true)
    let progressText = loc("gpuBenchmark/progress", { timeLeft = timeText })
    this.scene.findObject("progressText").setValue(progressText)
  }

  function getPresetsView() {
    return gpuBenchmarkPresets.map(function(cfg) {
      let { presetId, getPresetNameFunc } = cfg
      let presetName = getPresetNameFunc()
      return {
        presetName
        label = $"gpuBenchmark/{presetId}"
        presetText = localizaQualityPreset(presetName)
      }
    })
  }

  function onBenchmarkStart() {
    this.showSceneBtn("benchmarkStart", false)
    this.showSceneBtn("btnStart", false)
    this.showSceneBtn("waitAnimation", true)

    this.timeEndBenchmark = get_charserver_time_sec()
      + getGpuBenchmarkDuration().tointeger()
    this.updateProgressText()

    this.scene.findObject("progress_timer").setUserData(this)

    startGpuBenchmark()
  }

  function onSelectPreset(obj) {
    let index = obj.getValue()
    if (index < 0 || index >= obj.childrenCount())
      return
    this.selectedPresetName = obj.getChild(index)?.presetName
    this.scene.findObject("btnApply").enable(true)
  }

  function onUpdate(_, __) {
    if (this.timeEndBenchmark <= get_charserver_time_sec() && !isGpuBenchmarkRunning()) {
      this.scene.findObject("progress_timer").setUserData(null)
      this.onBenchmarkComplete()
      return
    }

    this.updateProgressText()
  }

  function onBenchmarkComplete() {
    this.showSceneBtn("waitAnimation", false)
    this.showSceneBtn("presetSelection", true)
    this.showSceneBtn("btnApply", true).enable(false)

    let view = { presets = this.getPresetsView() }
    let blk = handyman.renderCached("%gui/options/gpuBenchmarkPreset.tpl", view)
    this.guiScene.replaceContentFromText(
      this.scene.findObject("resultsList"), blk, blk.len(), this)
  }

  function presetApplyImpl(presetName) {
    setQualityPreset(presetName)
    if (!this.needUiUpdate)
      onConfigApplyWithoutUiUpdate()
    this.goBack()
  }

  function onPresetApply() {
    if (this.selectedPresetName != "ultralow") {
      this.presetApplyImpl(this.selectedPresetName)
      return
    }

    scene_msg_box("msg_sysopt_compatibility", null,
      loc("msgbox/compatibilityMode"),
      [
        ["yes", Callback(@() this.presetApplyImpl(this.selectedPresetName), this)],
        ["no", @() null],
      ], "no",
      { cancel_fn = @() null, checkDuplicateId = true })
  }

  function goBack() {
    closeGraphicsAutodetect()
    base.goBack()
  }
}

gui_handlers.GpuBenchmarkWnd <- GpuBenchmarkWnd

let function checkShowGpuBenchmarkWnd() {
  if (!canShowGpuBenchmark())
    return

  if (loadLocalAccountSettings("gpuBenchmark/seen", false))
    return

  handlersManager.loadHandler(GpuBenchmarkWnd)
}

let function showGpuBenchmarkWnd() {
  if (!canShowGpuBenchmark())
    return

  handlersManager.loadHandler(GpuBenchmarkWnd, { needUiUpdate = true })
}

return {
  checkShowGpuBenchmarkWnd
  showGpuBenchmarkWnd
}
