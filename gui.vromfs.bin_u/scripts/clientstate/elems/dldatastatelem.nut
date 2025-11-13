from "%scripts/dagui_library.nut" import *

let { eventbus_subscribe } = require("eventbus")
let elemModelType = require("%sqDagui/elemUpdater/elemModelType.nut")
let elemViewType = require("%sqDagui/elemUpdater/elemViewType.nut")
let { resetTimeout } = require("dagor.workcycle")

const HIDE_STAT_TIME_SEC = 1
const HIDE_STAT_WITH_FAILED_TIME_SEC = 10

local prevStat = null
local curStat = null
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
})

return {
}