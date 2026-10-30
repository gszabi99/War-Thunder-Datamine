from "%sqstd/platform.nut" import is_gdk, isSony
from "%scripts/dagui_natives.nut" import epic_is_running
from "%scripts/dagui_library.nut" import *

let {
  needEntStoreDiscountIcon = false,
  getShopItem = @(_id) null,
  getShopItemsTable = @() {},
  haveDiscount = @() false,
  canUseIngameShop = @(...) false
} = isSony ? require("%scripts/onlineShop/ps4ShopData.nut")
  : is_gdk ? require("%scripts/onlineShop/xboxShopData.nut")
  : epic_is_running() ? require("%scripts/onlineShop/epicShopData.nut")
  : null

return freeze({
  needEntStoreDiscountIcon
  getShopItem
  getShopItemsTable
  haveDiscount
  canUseIngameShop
})