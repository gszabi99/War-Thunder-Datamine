from "%rGui/globals/ui_library.nut" import *

let penalty = require("penalty")
let stdStr = require("string")
let time = require("%sqstd/time.nut")
let timeLocTable = require("%rGui/timeLocTable.nut")

let currentPenaltyDesc = Watched({})


let function isDevoiced() {
  currentPenaltyDesc.update(penalty.getPenaltyStatus())
  //currentPenaltyDesc.update({ status = penalty.DEVOICE, duration = 360091, category="FOUL", comment="test ban", seconds_left=2012})
  let penaltyStatus = currentPenaltyDesc.value?.status
  return penaltyStatus == penalty.DEVOICE || penaltyStatus == penalty.SILENT_DEVOICE
}


let function getDevoiceDescriptionText(highlightColor = Color(255, 255, 255)) {
  let txts = []
  if (currentPenaltyDesc.value.duration >= penalty.BAN_USER_INFINITE_PENALTY) {
    txts.append(loc("charServer/mute/permanent"), "\n")
  }
  else {
    local durationTime = time.roundTime(time.secondsToTime(currentPenaltyDesc.value.duration))
    durationTime.seconds = 0
    durationTime = time.secondsToTimeFormatString(durationTime).subst(timeLocTable)
    local timeText = stdStr.format("<color=%d>%s</color>", highlightColor, durationTime)
    txts.append(stdStr.format(loc("charServer/mute/timed"), timeText))

    if ((currentPenaltyDesc.value?.seconds_left ?? 0) > 0) {
      let leftTime = time.roundTime(currentPenaltyDesc.value.seconds_left)
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
    loc($"charServer/ban/reason/{currentPenaltyDesc.value.category}"), "\n",
    loc("charServer/ban/comment"), "\n", currentPenaltyDesc.value.comment)

  return "".join(txts)
}


return {
  isDevoiced = isDevoiced
  getDevoiceDescriptionText = getDevoiceDescriptionText
}
