from "%sqStdLibs/helpers/subscriptions.nut" import add_event_listener
from "eventbus" import eventbus_subscribe
from "dagor.workcycle" import resetTimeout
from "dagor.system" import dgs_get_settings
from "string" import format
from "%scripts/dagui_library.nut" import *

let elemModelType = require("%scripts/sqDagui/elemUpdater/elemModelType.nut")
let elemViewType = require("%scripts/sqDagui/elemUpdater/elemViewType.nut")

const HIDE_STAT_TIME_SEC = 1
const HIDE_STAT_WITH_FAILED_TIME_SEC = 10



const SYS_MSG_INDENT_MULT_BY_PERF_METRIC = { [0] = 0.0, [1] = 1, [2] = 0.75, [3] = 1.75 }

local prevStat = null
local curStat = null
local perfMetricsIdxOverride = null

function getSystemMsgPos() {
  let idx = perfMetricsIdxOverride ?? dgs_get_settings()?.video.perfMetrics ?? 1
  let muliplier = SYS_MSG_INDENT_MULT_BY_PERF_METRIC?[idx] ?? 1
  return format("%.2f@systemMsgIndent, 0", muliplier)
}

add_event_listener("PerfMetricsOptionChanged", function(p) {
  perfMetricsIdxOverride = p.idx
  elemModelType.SYSTEM_MSG_INDENT.notify([])
})

local statText = null

let notifyDlDataChanged = @()  elemModelType.DL_DATA_STATE.notify([])

function updateDisplayStat() {
  prevStat = curStat
  curStat = null
  statText = null
  notifyDlDataChanged()
}

function updateStat(newStat) {
  curStat = newStat
  statText = null

  if (curStat?.filesInFlight == 0) {
    let delayed = curStat?.filesDelayed ?? 0
    let displayStatTimeSec = ((curStat?.filesFailed ?? 0) - (prevStat?.filesFailed ?? 0) > 0) && delayed > 0
      ? HIDE_STAT_WITH_FAILED_TIME_SEC
      : HIDE_STAT_TIME_SEC
    resetTimeout(displayStatTimeSec, updateDisplayStat)
  }

  notifyDlDataChanged()
}

function getLocText() {
  if (statText)
    return statText

  let inFlightText = loc("loadDlDataStat/inFlight",
    { filesInFlight = curStat?.filesInFlight ?? 0
      filesInFlightSizeKB = curStat?.filesInFlightSizeKB ?? 0 })

  local delayedText = ""
  let filesDelayed = curStat?.filesDelayed ?? 0
  if (filesDelayed > 0)
    delayedText = "".concat(loc("ui/comma"),
      colorize("newTextBrightColor", loc("loadDlDataStat/delayed",
      { filesDelayed = filesDelayed
        filesDelayedSizeKB = curStat?.filesDelayedSizeKB ?? 0 }))
    )

  local failedText = ""
  let filesFailed = (curStat?.filesFailed ?? 0) - (prevStat?.filesFailed ?? 0)
  let filesFailedSizeKB = (curStat?.filesFailedSizeKB ?? 0) - (prevStat?.filesFailedSizeKB ?? 0)
  if (filesFailed > 0)
    failedText = "".concat(loc("ui/comma"),
      colorize("badTextColor", loc("loadDlDataStat/failed",
      { filesFailed, filesFailedSizeKB }))
    )

  statText = "".concat(inFlightText, delayedText, failedText)
  return statText
}

eventbus_subscribe("on_show_dldata_stat", updateStat)

elemModelType.addTypes({
  DL_DATA_STATE = {}
  SYSTEM_MSG_INDENT = {}
})

elemViewType.addTypes({
  DL_DATA_STATE_TEXT = {
    model = elemModelType.DL_DATA_STATE

    updateView = function(obj, _params) {
      let needShowStat = curStat != null
      let objAnimText = obj.getChild(0)
      objAnimText.fade = needShowStat ? "in" : "out"

      if (!needShowStat)
        return

      objAnimText.setValue(getLocText())
    }
  }

  DL_DATA_WAIT_MSG = {
    model = elemModelType.DL_DATA_STATE

    updateView = function(obj, _params) {
      obj.fade = ((curStat?.filesInFlight ?? 0) != 0) ? "in" : "out"
    }
  }

  SYSTEM_MSG_INDENT = {
    model = elemModelType.SYSTEM_MSG_INDENT

    updateView = function(obj, _params) {
      obj.pos = getSystemMsgPos()
    }
  }
})

return {
}