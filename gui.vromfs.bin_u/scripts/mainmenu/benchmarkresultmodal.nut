from "%scripts/dagui_natives.nut" import d3d_enable_vsync
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import buildTableRowNoPad


let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { format } = require("string")
let { isPlatformSony, isPs4VsyncEnabled } = require("%scripts/clientState/platform.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

gui_handlers.BenchmarkResultModal <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/benchmark.blk"

  title = null
  benchmark_data = null

  function initScreen() {
    if (this.title)
      this.scene.findObject("mission_title").setValue(this.title)

    if ("benchTotalTime" in this.benchmark_data) {
      local resultTableData = ""
      let avgfps = format("%.1f", this.benchmark_data.benchTotalTime > 0.1 ?
        (this.benchmark_data.benchTotalFrames / this.benchmark_data.benchTotalTime) : 0.0)

      resultTableData = this.getStatRow("stat_avgfps", "benchmark/avgfps", avgfps)

      let minfps = format("%.1f", this.benchmark_data.benchMinFPS)
      resultTableData = "".concat(resultTableData,
        this.getStatRow("stat_minfps", "benchmark/minfps", minfps))

      resultTableData = "".concat(resultTableData,
        this.getStatRow("stat_total", "benchmark/total", this.benchmark_data.benchTotalFrames))

      this.guiScene.replaceContentFromText(this.scene.findObject("results_list"), resultTableData, resultTableData.len(), this)
    }

    if (isPlatformSony)
      d3d_enable_vsync?(isPs4VsyncEnabled.get())
  }

  function getStatRow(id, statType, statCount) {
    let rowData = [
                      {
                        text = loc(statType),
                        tdalign = "right",
                        width = "46%pw"
                      }
                      {
                        text = statCount.tostring(),
                        tdalign = "left",
                        width = "46%pw",
                        rawParam = "padding-left:t='8%@p.pw';"
                      }
                    ]

    return buildTableRowNoPad(id, rowData, null, "commonTextColor:t='yes'")
  }
}
