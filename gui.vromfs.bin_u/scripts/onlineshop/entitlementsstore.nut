//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { isPlatformSony,
        isPlatformXboxOne,
        isPlatformPC,
        canSpendRealMoney } = require("%scripts/clientState/platform.nut")

let {
  getEntStoreLocId = @() "#msgbox/btn_onlineShop",
  getEntStoreIcon = @() "#ui/gameuiskin#store_icon.svg",
  isEntStoreTopMenuItemHidden = @(...) !isPlatformPC || !hasFeature("SpendGold") || !::isInMenu() || !canSpendRealMoney(),
  getEntStoreUnseenIcon = @() null,
  openEntStoreTopMenuFunc = @(_obj, handler) handler.startOnlineShop(null, null, "topmenu"),
  needEntStoreDiscountIcon = false,
  getShopItem = @(_id) null,
  getShopItemsTable = @() {},
  haveDiscount = @() false,
  openIngameStore = @(...) false,
  canUseIngameShop = @(...) false
} = isPlatformSony ? require("%scripts/onlineShop/ps4Shop.nut")
  : isPlatformXboxOne ? require("%scripts/onlineShop/xboxShop.nut")
  : ::epic_is_running() ? require("%scripts/onlineShop/epicShop.nut")
  : null

return {
  getEntStoreLocId = getEntStoreLocId
  getEntStoreIcon = getEntStoreIcon
  isEntStoreTopMenuItemHidden = isEntStoreTopMenuItemHidden
  getEntStoreUnseenIcon = getEntStoreUnseenIcon
  openEntStoreTopMenuFunc = openEntStoreTopMenuFunc
  needEntStoreDiscountIcon = needEntStoreDiscountIcon
  getShopItem = getShopItem
  getShopItemsTable = getShopItemsTable
  haveDiscount = haveDiscount
  openIngameStore = openIngameStore
  canUseIngameShop = canUseIngameShop
}