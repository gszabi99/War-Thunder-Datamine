from "%rGui/globals/ui_library.nut" import *

let penalty = require("penalty")
let stdStr = require("string")
let time = require("%sqstd/time.nut")
let timeLocTable = require("%rGui/timeLocTable.nut")

let currentPenaltyDesc = Watched({})


function isDevoiced() {
  currentPenaltyDesc.set(penalty.getPenaltyStatus())
  
  let penaltyStatus = currentPenaltyDesc.get()?.status
  return penaltyStatus == penalty.DEVOICE || penaltyStatus == penalty.SILENT_DEVOICE
}


function getDevoiceDescriptionText(highlightColor = Color(255, 255, 255)) {
  let txts = []
  if (currentPenaltyDesc.get().duration >= penalty.BAN_USER_INFINITE_PENALTY) {
    txts.append(loc("charServer/mute/permanent"), "\n")
  }
  else {
    local durationTime = time.roundTime(time.secondsToTime(currentPenaltyDesc.get().duration))
    durationTime.seconds = 0
    durationTime = time.secondsToTimeFormatString(durationTime).subst(timeLocTable)
    local timeText = stdStr.format("<color=%d>%s</color>", highlightColor, durationTime)
    txts.append(stdStr.format(loc("charServer/mute/timed"), timeText))

    if ((currentPenaltyDesc.get()?.seconds_left ?? 0) > 0) {
      let leftTime = time.roundTime(currentPenaltyDesc.get().seconds_left)
      timeText = stdStr.format("<color=%d>%s</color>",
        highlightColor, time.secondsToTimeFormatString(leftTime).subst(timeLocTable)
      )
      if (timeText != "") {
        txts.append(" ", stdStr.format(loc("charServer/ban/timeLeft"), timeText))
      }
    }
    txts.append("\n")
  }

  txts.append(loc("charServer/ban/reason"), loc("ui/colon"), " ",
    loc($"charServer/ban/reason/{currentPenaltyDesc.get().category}"), "\n",
    loc("charServer/ban/comment"), "\n", currentPenaltyDesc.get().comment)

  return "".join(txts)
}


return {
  isDevoiced = isDevoiced
  getDevoiceDescriptionText = getDevoiceDescriptionText
}
