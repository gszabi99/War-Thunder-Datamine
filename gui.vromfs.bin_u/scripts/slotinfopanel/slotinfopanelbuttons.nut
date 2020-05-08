local buttons = ::Watched([
  {
    id = "dmviewer_protection_analysis_btn"
    onClick = "onProtectionAnalysis"
    text = "#mainmenu/btnProtectionAnalysis"
    actionParamsMarkup = "margin-bottom:t='3@dp'; showConsoleImage:t='no'; width:t='@airInfoPanelDmSwitcherWidth'"
  }
  {
    id = "btnAirInfoWeaponry"
    onClick = "onAirInfoWeapons"
    text = "#mainmenu/btnWeapons"
    tooltip = "#mainmenu/btnWeaponsDesc"
    actionParamsMarkup = "showConsoleImage:t='no'; width:t='@airInfoPanelDmSwitcherWidth'"
    needDiscountIcon = true
    discountType = "lineText"
  }
])

return {
  slotInfoPanelButtons = buttons
}