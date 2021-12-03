local { GUI } = require("scripts/utils/configs.nut")

local awardRanks = [3, 4, 7]
local awardVesselsRanks = [3, 4, 5]
local awards = [[70000, 0], [300000, 100], [0, 2500]]

local getLinkString = @() ::format(::loc("msgBox/viralAcquisition"), ::my_user_id_str)

local function getViralAcquisitionDesc(locId = "msgbox/linkCopied") {
  locId = "/".concat(locId, "separatedVessels") // add separatedVessels postfix when vessels ranks are not equal to other ranks
  local desc = ::loc(locId, {
    firstAwardRank = ::get_roman_numeral(awardRanks[0]),
    secondAwardRank = ::get_roman_numeral(awardRanks[1]),
    thirdAwardRank = ::get_roman_numeral(awardRanks[2]),
    firstAwardVesselsRank = ::get_roman_numeral(awardVesselsRanks[0]),
    secondAwardVesselsRank = ::get_roman_numeral(awardVesselsRanks[1]),
    thirdAwardVesselsRank = ::get_roman_numeral(awardVesselsRanks[2]),
    firstAwardPrize = ::Cost(awards[0][0], awards[0][1]).tostring(),
    secondAwardPrize = ::Cost(awards[1][0], awards[1][1]).tostring(),
    thirdAwardPrize = ::Cost(awards[2][0], awards[2][1]).tostring(),
    gift = ::Cost(0, 50).tostring(),
    link = getLinkString() })
  return desc
}

local function showViralAcquisitionWnd() {
  if (!::has_feature("Invites"))
    return

  ::copy_to_clipboard(getLinkString())

  local formatImg = "ui/images/%s.jpg?P1"
  local image = ::format(formatImg, "facebook_invite")
  local height = 400
  local guiBlk = GUI.get()

  if (guiBlk?.invites_notification_window_images
      && guiBlk.invites_notification_window_images.paramCount() > 0) {
    local paramNum = ::math.rnd() % guiBlk.invites_notification_window_images.paramCount()
    local newHeight = guiBlk.invites_notification_window_images.getParamName(paramNum)
    local newImage = ::format(formatImg, guiBlk.invites_notification_window_images.getParamValue(paramNum))
    if (!regexp2(@"\D+").match(newHeight))
    {
      height = newHeight
      image = newImage
    }
  }

  local config = {
    name = ::loc("mainmenu/getLinkTitle")
    desc = getViralAcquisitionDesc()
    descAlign = "center"
    popupImage = "#"+image
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
