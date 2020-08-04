local { slotInfoPanelButtons } = require("scripts/slotInfoPanel/slotInfoPanelButtons.nut")

slotInfoPanelButtons.update(@(value) value.append({
  id = "btnAirInfoWeaponry"
  onClick = "onAirInfoWeapons"
  text = "#mainmenu/btnWeapons"
  tooltip = "#mainmenu/btnWeaponsDesc"
  actionParamsMarkup = "showConsoleImage:t='no'; width:t='@airInfoPanelDmSwitcherWidth'"
  needDiscountIcon = true
  discountType = "lineText"
}))