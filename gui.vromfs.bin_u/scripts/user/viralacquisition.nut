from "%scripts/dagui_natives.nut" import copy_to_clipboard
from "%scripts/dagui_library.nut" import *

let { Cost } = require("%scripts/money.nut")
let { format } = require("string")
let { userIdStr, isGuestLogin } = require("%scripts/user/profileStates.nut")
let { showUnlockWnd } = require("%scripts/unlocks/showUnlockWnd.nut")

let awardRanks = [3, 4, 7]
let awardVesselsRanks = [3, 4, 5]
let awards = [[70000, 0], [300000, 100], [0, 2500]]

let getLinkString = @() format(loc("msgBox/viralAcquisition"), userIdStr.get())

function getViralAcquisitionDesc(locId = "msgbox/linkCopied") {
  locId = "/".concat(locId, "disabledSecondAndThirdStageForVessels") 
  let desc = loc(locId, {
    firstAwardRank = get_roman_numeral(awardRanks[0]),
    secondAwardRank = get_roman_numeral(awardRanks[1]),
    thirdAwardRank = get_roman_numeral(awardRanks[2]),
    firstAwardVesselsRank = get_roman_numeral(awardVesselsRanks[0]),
    secondAwardVesselsRank = get_roman_numeral(awardVesselsRanks[1]),
    thirdAwardVesselsRank = get_roman_numeral(awardVesselsRanks[2]),
    firstAwardPrize = Cost(awards[0][0], awards[0][1]).tostring(),
    secondAwardPrize = Cost(awards[1][0], awards[1][1]).tostring(),
    thirdAwardPrize = Cost(awards[2][0], awards[2][1]).tostring(),
    gift = Cost(0, 50).tostring(),
    link = getLinkString() })
  return desc
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
