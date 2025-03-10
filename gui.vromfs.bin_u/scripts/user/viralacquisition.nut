from "%scripts/dagui_natives.nut" import copy_to_clipboard
from "%scripts/dagui_library.nut" import *

let { Cost } = require("%scripts/money.nut")
let regexp2 = require("regexp2")
let { format } = require("string")
let { rnd } = require("dagor.random")
let { GUI } = require("%scripts/utils/configs.nut")
let { userIdStr, isGuestLogin } = require("%scripts/user/profileStates.nut")
let { showUnlockWnd } = require("%scripts/unlocks/showUnlockWnd.nut")

let awardRanks = [3, 4, 7]
let awardVesselsRanks = [3, 4, 5]
let awards = [[70000, 0], [300000, 100], [0, 2500]]

let getLinkString = @() format(loc("msgBox/viralAcquisition"), userIdStr.value)

function getViralAcquisitionDesc(locId = "msgbox/linkCopied") {
  locId = "/".concat(locId, "disabledThirdStageForVessels") 
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
  if (!hasFeature("Invites") || isGuestLogin.value)
    return

  copy_to_clipboard(getLinkString())

  let formatImg = "ui/images/%s?P1"
  local image = format(formatImg, "facebook_invite")
  local height = 400
  let guiBlk = GUI.get()

  if (guiBlk?.invites_notification_window_images
      && guiBlk.invites_notification_window_images.paramCount() > 0) {
    let paramNum = rnd() % guiBlk.invites_notification_window_images.paramCount()
    let newHeight = guiBlk.invites_notification_window_images.getParamName(paramNum)
    let newImage = format(formatImg, guiBlk.invites_notification_window_images.getParamValue(paramNum))
    if (!regexp2(@"\D+").match(newHeight)) {
      height = newHeight
      image = newImage
    }
  }

  let config = {
    name = loc("mainmenu/getLinkTitle")
    desc = getViralAcquisitionDesc()
    descAlign = "center"
    popupImage = $"#{image}"
    ratioHeight = (height.tofloat() / 800).tostring()
    showSendEmail = true
    showPostLink = true
  }
  showUnlockWnd(config)
}

return {
  getViralAcquisitionDesc
  showViralAcquisitionWnd
}
