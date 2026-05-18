from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { saveLocalSharedSettings } = require("%scripts/clientState/localProfile.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { initGraphicsAutodetect, getGpuBenchmarkDuration, startGpuBenchmark,
  closeGraphicsAutodetect, getPresetFor60Fps, isGpuBenchmarkRunning, getGpuName
} = require("gpuBenchmark")
let { setQualityPreset, onConfigApplyWithoutUiUpdate
} = require("%scripts/options/systemOptions.nut")
let { secondsToString } = require("%scripts/time.nut")
let { get_charserver_time_sec } = require("chard")
let { register_command } = require("console")
let { animBgLoad } = require("%scripts/loading/animBg.nut")
let { GPU_BENCHMARK_SEEN_SAVE_ID, GPU_BENCHMARK_GPU_SAVE_ID
} = require("%scripts/options/gpuBenchmarkUtils.nut")

local class FirstGpuBenchmarkWnd(gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/options/firstGpuBenchmark.blk"
  timeEndBenchmark = -1

  function initScreen() {
    saveLocalSharedSettings(GPU_BENCHMARK_SEEN_SAVE_ID, true)
    saveLocalSharedSettings(GPU_BENCHMARK_GPU_SAVE_ID, getGpuName())

    initGraphicsAutodetect()
    this.timeEndBenchmark = get_charserver_time_sec()
     + getGpuBenchmarkDuration().tointeger()
    this.updateProgressText()
    animBgLoad("", this.scene.findObject("animated_bg_picture"))
    this.scene.findObject("progress_timer").setUserData(this)
    startGpuBenchmark()
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

  function onUpdate(_, __) {
    if (this.timeEndBenchmark <= get_charserver_time_sec() && !isGpuBenchmarkRunning()) {
      this.scene.findObject("progress_timer").setUserData(null)
      this.onBenchmarkComplete()
      return
    }
    this.updateProgressText()
  }

  function onBenchmarkComplete() {
    setQualityPreset(getPresetFor60Fps())
    onConfigApplyWithoutUiUpdate()
    this.goBack()
  }

  function goBack() {
    closeGraphicsAutodetect()
    base.goBack()
  }
}

gui_handlers.FirstGpuBenchmarkWnd <- FirstGpuBenchmarkWnd

function showFirstGpuBenchmarkWnd() {
  handlersManager.loadHandler(FirstGpuBenchmarkWnd)
}

register_command(showFirstGpuBenchmarkWnd, "debug.loadFirstBenchmarkWnd")