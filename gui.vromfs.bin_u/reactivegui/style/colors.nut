local colors = {
  transparent = Color(0, 0, 0, 0)
  white = Color(255, 255, 255)
  green = Color(0, 255, 0)
}

colors.menu <- {
  chatTextBlockedColor =  Color(128, 128, 128)
  commonTextColor = Color(192, 192, 192)
  unlockActiveColor = Color(255, 255, 255)
  userlogColoredText = Color(249, 219, 120)
  streakTextColor = Color(255, 229, 82)
  activeTextColor = Color(255, 255, 255)
  linkTextColor           = Color(23, 192, 252)
  linkTextHoverColorLight = Color(132, 224, 250)

  tabBackgroundColor = Color(3, 7, 12, 204)
  listboxSelOptionColor = Color(40, 51, 60)
  headerOptionHoverColor = Color(106, 34, 17, 153) //buttonCloseColorPushed
  headerOptionSelectedColor = Color(178, 57, 29) //buttonCloseColorHover
  headerOptionTextColor = Color(144, 143, 143) //buttonFontColorPushed, scrollbarSliderColor
  headerOptionSelectedTextColor = Color(224, 224, 224) //buttonFontColor, buttonHeaderTextColor, menuButtonTextColorHover, listboxSelTextColor

  scrollbarBgColor = Color(44, 44, 44, 51)
  scrollbarSliderColor = Color(144, 143, 143)
  scrollbarSliderColorHover = Color(224, 224, 224)

  silver = Color(170, 170, 170)

  textInputBorderColor = Color(62, 75, 82)
  textInputBgColor = Color(2, 5, 9, 145)

  voiceChatIconActiveColor = Color(134, 216, 8)

  modalShadeColor = Color(2, 6, 11, 178)
  frameBackgroundColor = Color(17, 20, 26, 242)
  frameBorderColor = Color(32, 38, 44, 178)
  frameHeaderColor = Color(42, 48, 55, 204)
  higlightFrameBgColor = Color(8, 8, 8, 17) //evenTrColor

  buttonCloseColorHover = Color(178, 57, 29)
  buttonCloseColorPushed = Color(106, 34, 17, 153)
  menuButtonColorHover = Color(45, 56, 65)
  menuButtonTextColorHover = Color(224, 224, 224)
}

colors.hud <- {
  spectatorColor = Color(128, 128, 128)
  chatActiveInfoColor = Color(255, 255, 5)
  mainPlayerColor = Color(221, 163, 57)
  componentFill = Color(0, 0, 0, 192)
  componentBorder = Color(255, 255, 255)
  chatTextAllColor = colors.menu.commonTextColor
  hudLogBgColor = Color(0, 0, 0, 102)
  chatTextPrivateColor = Color(222, 187, 255)
}

local inactiveDMColor = Color(45, 55, 63, 80)
local alertDMColor = Color(221, 17, 17)
colors.hud.damageModule <- {
  active = Color(255, 255, 255)
  alert = alertDMColor
  alertHighlight = Color(255, 255, 255) //for flashing animations
  inactive = inactiveDMColor
  aiSwitchHighlight = colors.green

  dmModuleDamaged = Color(255, 176, 37)
  dmModuleNormal = inactiveDMColor
  dmModuleDestroyed = alertDMColor
}


colors.hud.shipSteeringGauge <- {
  mark = Color(235, 235, 60, 200)
  serif = Color(135, 163, 160, 100)
  background = Color(0, 0, 0, 50)
}


return colors
