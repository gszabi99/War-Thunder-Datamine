from "%scripts/dagui_natives.nut" import epic_is_running
from "%scripts/dagui_library.nut" import *

let { isPlatformSony, isPlatformXboxOne
} = require("%scripts/clientState/platform.nut")

let {
  needEntStoreDiscountIcon = false,
  getShopItem = @(_id) null,
  getShopItemsTable = @() {},
  haveDiscount = @() false,
  canUseIngameShop = @(...) false
} = isPlatformSony ? require("%scripts/onlineShop/ps4ShopData.nut")
  : isPlatformXboxOne ? require("%scripts/onlineShop/xboxShopData.nut")
  : epic_is_running() ? require("%scripts/onlineShop/epicShopData.nut")
  : null

return {
  needEntStoreDiscountIcon
  getShopItem
  getShopItemsTable
  haveDiscount
  canUseIngameShop
}