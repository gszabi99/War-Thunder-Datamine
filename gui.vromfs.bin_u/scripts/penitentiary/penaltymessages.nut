from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import get_time_till_decals_disabled
let { format } = require("string")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { secondsToHours, hoursToString } = require("%scripts/time.nut")
let { updateEntitlementsLimited } = require("%scripts/onlineShop/entitlementsUpdate.nut")
let { getPenaltyStatus, DEVOICE, BAN_USER_INFINITE_PENALTY } = require("penalty")

function getDevoiceMessage(activeColor = "chatActiveInfoColor") {
  let st = getPenaltyStatus()
  
  if (st.status != DEVOICE) {
    return null
  }

  local txt = ""
  if (st.duration >= BAN_USER_INFINITE_PENALTY) {
    txt = "".concat(txt, loc("charServer/mute/permanent"), "\n")
  }
  else {
    let durationHours = secondsToHours(st.duration)
    local timeText = colorize(activeColor, hoursToString(durationHours, false))
    txt = "".concat(txt, format(loc("charServer/mute/timed"), timeText))

    if (("seconds_left" in st) && st.seconds_left > 0) {
      let leftHours = secondsToHours(st.seconds_left)
      timeText = colorize(activeColor, hoursToString(leftHours, false, true))
      if (timeText != "") {
        txt = "".concat(txt, " ", format(loc("charServer/ban/timeLeft"), timeText))
      }
    }
    else if (isInMenu.get()) {
      updateEntitlementsLimited()
    }

    if (txt != "") {
      txt = $"{txt}\n"
    }
  }

  txt = "".concat(txt, loc("charServer/ban/reason"), loc("ui/colon"), " ",
    colorize(activeColor, loc($"charServer/ban/reason/{st.category}")), "\n",
    loc("charServer/ban/comment"), "\n", st.comment)
  return txt
}

function getBannedMessage(status = null, banType = "ban") {
  let { duration, seconds_left, category, comment } = status ?? getPenaltyStatus()
  let onlyDecalsDisabled = banType == "decal"
  let txtArr = []
  if (duration >= BAN_USER_INFINITE_PENALTY || onlyDecalsDisabled) {
    txtArr.append(loc($"charServer/{banType}/permanent"))
  }
  else {
    let timeLeft = secondsToHours(get_time_till_decals_disabled() || seconds_left)
    let durationHours = secondsToHours(duration)
    txtArr.append(" ".concat(
      format(loc($"charServer/{banType}/timed"), hoursToString(durationHours, false))
      format(loc("charServer/ban/timeLeft"), hoursToString(timeLeft, false, true))
    ))
  }

  if (!onlyDecalsDisabled) {
    txtArr.append(
      "".concat(loc("charServer/ban/reason"), loc("ui/colon"),
        colorize("highlightedTextColor", loc($"charServer/ban/reason/{category}"))),
      "", loc("charServer/ban/comment"), comment)
  }

  return "\n".join(txtArr)
}

return { getDevoiceMessage, getBannedMessage }