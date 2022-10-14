from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { initGraphicsAutodetect, getGpuBenchmarkDuration, startGpuBenchmark,
  closeGraphicsAutodetect, getPresetFor60Fps, getPresetForMaxQuality,
  getPresetForMaxFPS, isGpuBenchmarkRunning } = require("gpuBenchmark")
let { setQualityPreset, canShowGpuBenchmark, onConfigApplyWithoutUiUpdate,
  localizaQualityPreset } = require("%scripts/options/systemOptions.nut")
let { secondsToString } = require("%scripts/time.nut")

let gpuBenchmarkPresets = [
  {
    presetId = "presetMaxQuality"
    getPresetNameFunc = getPresetForMaxQuality
    shortcut = "A"
  }
  {
    presetId = "presetMaxFPS"
    getPresetNameFunc = getPresetForMaxFPS
    shortcut = "X"
  }
  {
    presetId = "preset60Fps"
    getPresetNameFunc = getPresetFor60Fps
    shortcut = "Y"
  }
]

local class GpuBenchmarkWnd extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/options/gpuBenchmark.blk"
  needUiUpdate = false
  timeEndBenchmark = -1

  function initScreen() {
    ::save_local_account_settings("gpuBenchmark/seen", true)
    initGraphicsAutodetect()
  }

  function updateProgressText() {
    let timeLeft = timeEndBenchmark - ::get_charserver_time_sec()
    if (timeLeft < 0) {
      scene.findObject("progressText").setValue("")
      return
    }

    let timeText = secondsToString(timeLeft, true, true)
    let progressText = loc("gpuBenchmark/progress", { timeLeft = timeText })
    scene.findObject("progressText").setValue(progressText)
  }

  function getPresetsView() {
    return gpuBenchmarkPresets.map(function(cfg) {
      let { presetId, getPresetNameFunc, shortcut } = cfg
      let presetName = getPresetNameFunc()
      return {
        presetName
        shortcut
        label = $"gpuBenchmark/{presetId}"
        presetText = localizaQualityPreset(presetName)
      }
    })
  }

  function onBenchmarkStart() {
    this.showSceneBtn("benchmarkStart", false)
    this.showSceneBtn("btnStart", false)
    this.showSceneBtn("waitAnimation", true)

    timeEndBenchmark = ::get_charserver_time_sec()
      + getGpuBenchmarkDuration().tointeger()
    updateProgressText()

    scene.findObject("progress_timer").setUserData(this)

    startGpuBenchmark()
  }

  function onUpdate(_, __) {
    if (timeEndBenchmark <= ::get_charserver_time_sec() && !isGpuBenchmarkRunning()) {
      scene.findObject("progress_timer").setUserData(null)
      onBenchmarkComplete()
      return
    }

    updateProgressText()
  }

  function onBenchmarkComplete() {
    this.showSceneBtn("waitAnimation", false)
    this.showSceneBtn("presetSelection", true)

    let view = { presets = getPresetsView() }
    let blk = ::handyman.renderCached("%gui/options/gpuBenchmarkPreset", view)
    guiScene.replaceContentFromText("resultsList", blk, blk.len(), this)
  }

  function presetApplyImpl(presetName) {
    setQualityPreset(presetName)
    if (!needUiUpdate)
      onConfigApplyWithoutUiUpdate()
    goBack()
  }

  function onPresetApply(obj) {
    let presetName = obj.presetName
    if (presetName != "ultralow") {
      presetApplyImpl(presetName)
      return
    }

    ::scene_msg_box("msg_sysopt_compatibility", null,
      loc("msgbox/compatibilityMode"),
      [
        ["yes", Callback(@() presetApplyImpl(presetName), this)],
        ["no", @() null],
      ], "no",
      { cancel_fn = @() null, checkDuplicateId = true })
  }

  function goBack() {
    closeGraphicsAutodetect()
    base.goBack()
  }
}

::gui_handlers.GpuBenchmarkWnd <- GpuBenchmarkWnd

let function checkShowGpuBenchmarkWnd() {
  if (!canShowGpuBenchmark())
    return

  if (::load_local_account_settings("gpuBenchmark/seen", false))
    return

  ::handlersManager.loadHandler(GpuBenchmarkWnd)
}

let function showGpuBenchmarkWnd() {
  if (!canShowGpuBenchmark())
    return

  ::handlersManager.loadHandler(GpuBenchmarkWnd, { needUiUpdate = true })
}

return {
  checkShowGpuBenchmarkWnd
  showGpuBenchmarkWnd
}
