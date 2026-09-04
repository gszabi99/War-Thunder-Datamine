from "gpuBenchmark" import initGraphicsAutodetect, getGpuBenchmarkDuration, startGpuBenchmark, closeGraphicsAutodetect, getPresetFor60Fps, isGpuBenchmarkRunning, getGpuName
from "chard" import get_charserver_time_sec
from "console" import register_command
from "%scripts/dagui_library.nut" import *

let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let { saveLocalSharedSettings } = require("%scripts/clientState/localProfile.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { setQualityPreset, onConfigApplyWithoutUiUpdate } = require("%scripts/options/systemOptions.nut")
let { secondsToString } = require("%scripts/time.nut")
let { animBgLoad } = require("%scripts/loading/animBg.nut")
let { GPU_BENCHMARK_SEEN_SAVE_ID, GPU_BENCHMARK_GPU_SAVE_ID } = require("%scripts/options/gpuBenchmarkUtils.nut")

local class FirstGpuBenchmarkWnd(BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/options/firstGpuBenchmark.blk"
  timeEndBenchmark = -1

  function initScreen() {
    saveLocalSharedSettings(GPU_BENCHMARK_SEEN_SAVE_ID, true)
    saveLocalSharedSettings(GPU_BENCHMARK_GPU_SAVE_ID, getGpuName())

    initGraphicsAutodetect("graphicsAutodetect")
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

register_gui_handler("FirstGpuBenchmarkWnd", FirstGpuBenchmarkWnd)

function showFirstGpuBenchmarkWnd() {
  handlersManager.loadHandler(FirstGpuBenchmarkWnd)
}

register_command(showFirstGpuBenchmarkWnd, "debug.loadFirstBenchmarkWnd")

return { FirstGpuBenchmarkWnd }
