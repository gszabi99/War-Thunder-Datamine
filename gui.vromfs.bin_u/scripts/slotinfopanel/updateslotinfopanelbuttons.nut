from "%scripts/dagui_library.nut" import *

let { slotInfoPanelButtons } = require("%scripts/slotInfoPanel/slotInfoPanelButtons.nut")

slotInfoPanelButtons.set([
  {
    id = "dmviewer_protection_analysis_btn"
    onClick = "onProtectionAnalysis"
    text = "#mainmenu/btnProtectionAnalysis"
    actionParamsMarkup = "margin-bottom:t='1@blockInterval'; showConsoleImage:t='no'; width:t='@airInfoPanelDmSwitcherWidth'"
    delayed = true
    isHidden = true
  }
  {
    id = "btnAirInfoWeaponry"
    onClick = "onAirInfoWeapons"
    text = "#mainmenu/btnWeapons"
    tooltip = "#mainmenu/btnWeaponsDesc"
    actionParamsMarkup = "showConsoleImage:t='no'; width:t='@airInfoPanelDmSwitcherWidth'"
    needDiscountIcon = true
    discountType = "lineText"
    newIconWidget = @"newIconWidget {
      newIconWidgetImg {
        background-image:t='#ui/gameuiskin#new_icon.svg'
      }
    }"
  }
])