from "%rGui/globals/ui_library.nut" import *

let colors = {
  transparent = 0x00000000
  white = 0xFFFFFFFF
  green = Color(0, 255, 0)

  commonIconColor = 0xFFDCDCDC
  deadIconColor = 0xA0A0A0A0
  orderMarkerColor = 0x7896ffa0

  hudBlurBgColor = 0xDCDCDCDC
  hudIconColor = 0x3C808080

  playerColor = Color(0, 255, 102, 118)
  allyColor = Color(40, 151, 255, 158)
  enemyColor = Color(255, 76, 40, 158)

  zeroHpColor = 0xFFD6603C
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
  headerOptionHoverColor = Color(106, 34, 17, 153) 
  headerOptionSelectedColor = Color(178, 57, 29) 
  headerOptionTextColor = Color(144, 143, 143) 
  headerOptionSelectedTextColor = Color(224, 224, 224) 

  scrollbarBgColor = Color(44, 44, 44, 51)
  scrollbarSliderColor = Color(144, 143, 143)
  scrollbarSliderColorHover = Color(224, 224, 224)

  silver = Color(170, 170, 170)

  textInputBorderColor = Color(62, 75, 82)
  textInputBgColor = Color(2, 5, 9, 145)

  voiceChatIconActiveColor = Color(134, 216, 8)

  blurBgrColor = Color(8, 10, 13, 102)
  frameBackgroundColor = Color(17, 24, 33, 204)
  frameBorderColor = Color(32, 38, 44, 178)
  frameHeaderColor = Color(45, 52, 60)
  higlightFrameBgColor = Color(8, 8, 8, 17) 

  buttonCloseColorHover = Color(178, 57, 29)
  buttonCloseColorPushed = Color(106, 34, 17, 153)
  menuButtonColorHover = Color(45, 56, 65)
  menuButtonTextColorHover = Color(224, 224, 224)
  separatorBlockColor = Color(34, 34, 34, 34)
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

let inactiveDMColor = Color(45, 55, 63, 80)
let alertDMColor = Color(221, 17, 17)
colors.hud.damageModule <- {
  active = Color(255, 255, 255)
  alert = alertDMColor
  alertHighlight = Color(255, 255, 255) 
  inactive = inactiveDMColor
  aiSwitchHighlight = colors.green
  fire = Color(255, 115, 20)

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
