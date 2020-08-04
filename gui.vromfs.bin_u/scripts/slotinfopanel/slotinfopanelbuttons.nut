local buttons = ::Watched([
  {
    id = "dmviewer_protection_analysis_btn"
    onClick = "onProtectionAnalysis"
    text = "#mainmenu/btnProtectionAnalysis"
    actionParamsMarkup = "margin-bottom:t='3@dp'; showConsoleImage:t='no'; width:t='@airInfoPanelDmSwitcherWidth'"
  }
])

return {
  slotInfoPanelButtons = buttons
}