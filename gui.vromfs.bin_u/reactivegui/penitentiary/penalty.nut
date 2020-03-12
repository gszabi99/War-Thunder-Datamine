local penalty = ::require_native("penalty")
local stdStr = require("string")
local time = require("std/time.nut")


local currentPenaltyDesc = Watched({})


local function isDevoiced() {
  currentPenaltyDesc.update(penalty.getPenaltyStatus())
  //currentPenaltyDesc.update({ status = penalty.DEVOICE, duration = 360091, category="FOUL", comment="test ban", seconds_left=2012})
  local penaltyStatus = currentPenaltyDesc.value?.status
  return penaltyStatus == penalty.DEVOICE || penaltyStatus == penalty.SILENT_DEVOICE
}


local function getDevoiceDescriptionText(highlightColor = Color(255, 255, 255)) {
  local txt = ""
  if (currentPenaltyDesc.value.duration >= penalty.BAN_USER_INFINITE_PENALTY) {
    txt += ::loc("charServer/mute/permanent") + "\n"
  } else {
    local durationHours = time.secondsToHours(currentPenaltyDesc.value.duration)
    local timeText = stdStr.format("<color=%d>%s</color>",
      highlightColor,
      time.hoursToString(durationHours, false))
    txt += stdStr.format(::loc("charServer/mute/timed"), timeText)

    if ((currentPenaltyDesc.value?.seconds_left ?? 0) > 0) {
      local leftHours = time.secondsToHours(currentPenaltyDesc.value.seconds_left)
      timeText = stdStr.format("<color=%d>%s</color>",
        highlightColor,
        time.hoursToString(leftHours, false, true))
      if (timeText != "") {
        txt += " " + stdStr.format(::loc("charServer/ban/timeLeft"), timeText)
      }
    }

    if (txt != "") {
      txt += "\n"
    }
  }

  txt += ::loc("charServer/ban/reason") + ::loc("ui/colon") + " " +
    ::loc("charServer/ban/reason/"+currentPenaltyDesc.value.category) + "\n" +
    ::loc("charServer/ban/comment") + "\n" + currentPenaltyDesc.value.comment
  return txt
}


return {
  isDevoiced = isDevoiced
  getDevoiceDescriptionText = getDevoiceDescriptionText
}
