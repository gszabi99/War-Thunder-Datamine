import "%rGui/style/fontsState.nut" as fontsState
import "%rGui/components/button.nut" as button
import "%rGui/components/spinner.nut" as mkSpinner
import "%appGlobals/style/cssColors.nut" as cssColors
from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst
from "%rGui/components/text.nut" import mkText
from "%sqstd/math.nut" import round_by_value
from "eventbus" import eventbus_subscribe
from "replays" import cancel_loading

let replayWait = mkWatched(persist, "replayWait", null)
let isReplayWaiting = Computed(@() replayWait.get() != null)
eventbus_subscribe("replayWait", @(ev) replayWait.set(ev.isShow ? ev : null))

let font = fontsState.get("normal")
let blockInterval = cssConst("blockInterval")
let waitIconWidth = cssConst("waitIconWidth")
let statusTextMargin = [0, 2 * blockInterval, 0, 0]

function cancelDownload() {
  cancel_loading()
  replayWait.set(null)
}

let pausedText = mkText(loc("hints/replay_paused"), font, cssColors.activeTextColor)
let cancelButton = button({ text = loc("mainmenu/btnCancel"), margin = [2 * blockInterval, 0, 0, 0] }, cancelDownload)

function downloadStatus() {
  let { dlCur = null, dlTotal = null, dlPercent = null } = replayWait.get()
  let text = dlPercent == null ? ""
    : loc("hints/replay_download_status", {
        downloadedMB = round_by_value(dlCur, 0.1),
        totalMB = round_by_value(dlTotal, 0.1),
        downloadedPercent = round_by_value(dlPercent, 0.1)
      })
  return mkText(text, font, cssColors.activeTextColor,
    { watch = replayWait, margin = statusTextMargin, vplace = ALIGN_CENTER })
}

let statusRow = freeze({
  hplace = ALIGN_CENTER
  margin = [blockInterval, 0, 0, 0]
  flow = FLOW_HORIZONTAL
  
  children = [downloadStatus, @() mkSpinner({ height = waitIconWidth })]
})

let cancelRow = freeze({
  hplace = ALIGN_CENTER
  children = cancelButton
})

let replayPausedBlock = @() {
  watch = isReplayWaiting
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  flow = FLOW_VERTICAL
  children = !isReplayWaiting.get() ? null : [
    pausedText
    statusRow
    cancelRow
  ]
}

return replayPausedBlock
