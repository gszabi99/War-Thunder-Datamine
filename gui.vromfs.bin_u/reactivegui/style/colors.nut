import "%rGui/style/cssColor.nut" as cssColor
from "%rGui/globals/ui_library.nut" import *

const inactiveDMColor = Color(45, 55, 63, 80)
const alertDMColor = Color(221, 17, 17)

const colors = {
  transparent = cssColor("transparent")
  white = cssColor("white")
  green = cssColor("green")
  red = cssColor("red")
  orange = cssColor("orange")

  commonIconColor = 0xFFDCDCDC
  deadIconColor = 0x70707070

  hudSquadBgColor = Color(10, 10, 11, 154)

  allyColor = Color(40, 151, 255, 158)
  enemyColor = Color(255, 76, 40, 158)

  hpColor = 0xFFFFFFFF
  bleedingColor = 0xFFFB6A60
  staminaColor = 0xFF89A9D3

  actionBarHotkeyColor = cssColor("hotkeyColor")
  attackWarningColor = 0xFFD90000
  attackWarningColor2 = 0x00AA0000
  attackWarningColor3 = 0x00440000

  menu = {
    chatTextBlockedColor = cssColor("chatTextBlockedColor")
    commonTextColor = cssColor("commonTextColor")
    unlockActiveColor = cssColor("unlockActiveColor")
    userlogColoredText = cssColor("userlogColoredText")
    streakTextColor = cssColor("streakTextColor")
    activeTextColor = cssColor("activeTextColor")
    linkTextColor = cssColor("linkTextColor")
    linkTextHoverColorLight = cssColor("linkTextHoverColorLight")

    tabBackgroundColor = cssColor("listboxBgColor")
    listboxSelOptionColor = cssColor("listboxSelOptionColor")
    headerOptionHoverColor = cssColor("headerOptionHoverColor")
    headerOptionSelectedColor = cssColor("headerOptionSelectedColor")
    headerOptionTextColor = cssColor("headerOptionTextColor")
    headerOptionSelectedTextColor = cssColor("headerOptionSelectedTextColor")

    scrollbarBgColor = cssColor("scrollbarBgColor")
    scrollbarSliderColor = cssColor("scrollbarSliderColor")
    scrollbarSliderColorHover = cssColor("scrollbarSliderColorHover")

    silver = cssColor("silver")

    textInputBorderColor = cssColor("editboxBorderColorFocus")
    textInputBgColor = cssColor("editboxColor")

    voiceChatIconActiveColor = cssColor("voiceChatIconActiveColor")

    blurBgrColor = cssColor("blurBgrColor")
    frameDarkTransparentBgColor = cssColor("frameDarkTransparentBgColor")
    frameBorderColor = cssColor("frameBorderColor")
    frameHeaderBackgroundColor = cssColor("frameHeaderBackgroundColor")
    higlightFrameBgColor = cssColor("evenTrColor")

    buttonCloseColorHover = cssColor("buttonCloseColorHover")
    buttonCloseColorPushed = cssColor("buttonCloseColorPushed")
    menuButtonColorHover = cssColor("menuButtonColorHover")
    menuButtonTextColorHover = cssColor("menuButtonTextColorHover")
    separatorBlockColor = cssColor("separatorBlockColor")
  }

  hud = {
    spectatorColor = cssColor("spectatorColor")
    chatActiveInfoColor = cssColor("chatActiveInfoColor")
    componentFill = Color(0, 0, 0, 192)
    componentBorder = Color(255, 255, 255)
    chatTextAllColor = cssColor("chatTextAllColor")
    hudLogBgColor = cssColor("hudTextBgShade")
    chatTextPrivateColor = cssColor("chatTextPrivateColor")
    infantryShortcutCommonColor = cssColor("infantryShortcutColor")
    infantryShortcutDisableColor = cssColor("infantryShortcutDisabledColor")
    infantryShortcutCommonTextColor = cssColor("infantryShortcutTextColor")
    infantryShortcutDisableTextColor = cssColor("infantryShortcutDisabledTextColor")
    infantryHudCommonColor = 0xFFD2D2D1
    infantryHudActiveColor = 0xFFFFFFFF
    infantryHudInactiveColor = 0xB3B3B3B3
    infantryHudDisabledColor = 0x77777777

    damageModule = {
      active = Color(255, 255, 255)
      alert = alertDMColor
      alertHighlight = Color(255, 255, 255) 
      inactive = inactiveDMColor
      aiSwitchHighlight = cssColor("green")
      fire = Color(255, 115, 20)

      dmModuleDamaged = Color(255, 176, 37)
      dmModuleNormal = inactiveDMColor
      dmModuleDestroyed = alertDMColor
    }

    shipSteeringGauge = {
      mark = Color(235, 235, 60, 200)
      serif = Color(135, 163, 160, 100)
      background = Color(0, 0, 0, 50)
    }
  }
}

return colors
