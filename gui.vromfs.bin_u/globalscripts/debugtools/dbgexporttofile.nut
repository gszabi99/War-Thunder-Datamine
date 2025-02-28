from "dagor.debug" import console_print
from "math" import max
from "string" import format
from "console" import command
from "dagor.workcycle" import defer
from "dagor.fs" import mkpath
from "dagor.time" import get_local_unixtime
import "DataBlock" as DataBlock

// warning disable: -file:forbidden-function

/**
 *  export() is a tool for batch exporting a huge amounts of data into blk file without a freeze.
 *  It uses defer() from dagor.workcycle lib to prosess a little part of data on every frame.
 *
 *  @params {table} params - Table of parameters, see EXPORT_PARAMS below.
 *
**/

let EXPORT_PARAMS = { //const
  resultFilePath  = "export/file.blk" // Resulting blk filename to write results to.
  itemsPerFrame   = 1                 // Num of items to process per single frame.
  list            = []                // Array of items to process.
  itemProcessFunc = @(_value) null    // Function, takes value from list, returns processed result -
                                      // table { key="id", value = DataBlock }, or null.
                                      // If it returns table, its keys will be written to resulting
                                      // blk this way: resBlk[table.key] <- table.value
  onFinish        = null              // Function to execute when finished, or null.
}

let indicatorId = "dbgExportToFile"
let timeToStr = @(s) format("%02dm%02ds", s / 60, s % 60)
let nbsp = "\u00A0"

function exportImpl(params, resBlk, idx, startTime) {
  let exportImplFunc = callee()
  let { resultFilePath, itemsPerFrame, list, itemProcessFunc, onFinish } = params
  let total = list.len()
  for (local i = idx; i < total; i++) {
    if (i != idx && !(i % itemsPerFrame)) { //avoid freeze
      let prc = (100.0 * i / total).tointeger()
      let passedSec = get_local_unixtime() - startTime
      let eta = timeToStr(max(0, (1.0 * passedSec / i * total).tointeger() - passedSec))
      command($"console.progress_indicator {indicatorId} {i}/{total}{nbsp}({prc}%),{nbsp}ETA:{nbsp}{eta}")

      defer(@() exportImplFunc(params, resBlk, i, startTime))
      return
    }

    let item = list[i]
    let data = item != null ? itemProcessFunc(item) : null
    if (data != null)
      resBlk[data.key] <- data.value
  }

  mkpath(resultFilePath)
  resBlk.saveToTextFile(resultFilePath)

  onFinish?()
  command($"console.progress_indicator {indicatorId}")
  console_print($"Export finished in {timeToStr(get_local_unixtime() - startTime)}")
}

function export(params = EXPORT_PARAMS) {
  params = EXPORT_PARAMS.__merge(params)
  console_print($"Export started ({params.list.len()} items)...")
  exportImpl(params, DataBlock(), 0, get_local_unixtime())
}

return {
  export = export
}
