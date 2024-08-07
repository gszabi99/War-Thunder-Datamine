from "%scripts/dagui_library.nut" import *

function canShowUnitContextMenu(obj) {
  if (obj == null || obj.tag != "shopItem")
    return false

  if (obj.getFinalProp("refuseOpenHoverMenu") == "yes")
    return false
  return true
}

return {
  canShowUnitContextMenu
}