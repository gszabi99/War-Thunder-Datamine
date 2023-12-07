from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let getUniversalSparesForUnit = @(unit) ::ItemsManager.getInventoryList(itemType.UNIVERSAL_SPARE)
  .filter(@(item) item.getAmount() > 0 && item.canActivateOnUnit(unit))

return {
  getUniversalSparesForUnit
}
