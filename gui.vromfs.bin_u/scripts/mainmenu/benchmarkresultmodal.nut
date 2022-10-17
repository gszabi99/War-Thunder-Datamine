let { format } = require("string")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")

::gui_handlers.BenchmarkResultModal <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/benchmark.blk"

  title = null
  benchmark_data = null

  function initScreen()
  {
    if (title)
      scene.findObject("mission_title").setValue(title)

    if ("benchTotalTime" in benchmark_data)
    {
      local resultTableData = ""
      let avgfps = format("%.1f", benchmark_data.benchTotalTime > 0.1 ?
        (benchmark_data.benchTotalFrames / benchmark_data.benchTotalTime) : 0.0 )

      resultTableData = getStatRow("stat_avgfps", "benchmark/avgfps", avgfps)

      let minfps = format("%.1f", benchmark_data.benchMinFPS)
      resultTableData += getStatRow("stat_minfps", "benchmark/minfps", minfps)

      resultTableData += getStatRow("stat_total", "benchmark/total", benchmark_data.benchTotalFrames)

      guiScene.replaceContentFromText("results_list", resultTableData, resultTableData.len(), this)
    }

    if (isPlatformSony)
      ::d3d_enable_vsync(::ps4_vsync_enabled)
  }

  function getStatRow(id, statType, statCount)
  {
    let rowData = [
                      {
                        text = ::loc(statType),
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

    return ::buildTableRowNoPad(id, rowData, null, "commonTextColor:t='yes'")
  }
}
