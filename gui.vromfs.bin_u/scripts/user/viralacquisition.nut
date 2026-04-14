from "%scripts/dagui_natives.nut" import copy_to_clipboard
from "%scripts/dagui_library.nut" import *

let { Cost } = require("%scripts/money.nut")
let { format } = require("string")
let { userIdStr, isGuestLogin } = require("%scripts/user/profileStates.nut")
let { showUnlockWnd } = require("%scripts/unlocks/showUnlockWnd.nut")

let awardRanks = [3, 4, 7]
let awards = [[70000, 0], [300000, 100], [0, 2500]]
let awardCount = 3

let getLinkString = @() format(loc("msgBox/viralAcquisition"), userIdStr.get())

function getViralAcquisitionDesc(showLink = true) {
  let awardLines = [
    loc("msgbox/linkCopied/without2faAnyVehicleType", {
      awardPrize = Cost(awards[0][0], awards[0][1]).tostring()
      awardRank = get_roman_numeral(awardRanks[0])
    })
    loc("msgbox/linkCopied/with2faAviationArmy", {
      awardPrize = Cost(awards[1][0], awards[1][1]).tostring()
      awardRank = get_roman_numeral(awardRanks[1])
    })
    loc("msgbox/linkCopied/with2faAviationArmy", {
      awardPrize = Cost(awards[2][0], awards[2][1]).tostring()
      awardRank = get_roman_numeral(awardRanks[2])
    })
  ]
  let lines = [
    loc("msgbox/linkCopied/header")
    loc("msgbox/linkCopied/listTitle")
    ""
    "\n".join(awardLines)
    loc("msgbox/linkCopied/limit", { awardCount })
    ""
    loc("msgbox/linkCopied/inviteeReward", { gift = Cost(0, 50).tostring() })
  ]
  if (showLink)
    lines.append("", loc("msgbox/linkCopied/link", { link = getLinkString() }))
  return "\n".join(lines)
}

function showViralAcquisitionWnd() {
  if (!hasFeature("Invites") || isGuestLogin.get())
    return

  copy_to_clipboard(getLinkString())

  showUnlockWnd({
    name = loc("mainmenu/getLinkTitle")
    desc = getViralAcquisitionDesc()
    descAlign = "center"
    popupImage = $"#ui/images/new_rank_germany?P1"
    ratioHeight = "0.5"
    showSendEmail = true
    showPostLink = true
  })
}

return {
  getViralAcquisitionDesc
  showViralAcquisitionWnd
}
