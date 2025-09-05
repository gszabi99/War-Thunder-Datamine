from "%scripts/dagui_natives.nut" import epic_is_running
from "%scripts/dagui_library.nut" import *

let { is_gdk } = require("%sqstd/platform.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")

let {
  needEntStoreDiscountIcon = false,
  getShopItem = @(_id) null,
  getShopItemsTable = @() {},
  haveDiscount = @() false,
  canUseIngameShop = @(...) false
} = isPlatformSony ? require("%scripts/onlineShop/ps4ShopData.nut")
  : is_gdk ? require("%scripts/onlineShop/xboxShopData.nut")
  : epic_is_running() ? require("%scripts/onlineShop/epicShopData.nut")
  : null

return {
  needEntStoreDiscountIcon
  getShopItem
  getShopItemsTable
  haveDiscount
  canUseIngameShop
}