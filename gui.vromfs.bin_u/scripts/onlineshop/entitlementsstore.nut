local { isPlatformSony,
        isPlatformXboxOne,
        isPlatformPC,
        canSpendRealMoney } = require("scripts/clientState/platform.nut")

local {
  getEntStoreLocId = @() "#msgbox/btn_onlineShop",
  getEntStoreIcon = @() "#ui/gameuiskin#store_icon.svg",
  isEntStoreTopMenuItemHidden = @(...) !isPlatformPC || !::has_feature("SpendGold") || !::isInMenu() || !canSpendRealMoney(),
  getEntStoreUnseenIcon = @() null,
  openEntStoreTopMenuFunc = @(obj, handler) handler.startOnlineShop(null, null, "topmenu"),
  needEntStoreDiscountIcon = false,
  getShopItem = @(id) null,
  getShopItemsTable = @() {},
  haveDiscount = @() false,
  openIngameStore = @(...) false,
  canUseIngameShop = @(...) false
} = isPlatformSony? require("scripts/onlineShop/ps4Shop.nut")
  : isPlatformXboxOne? require("scripts/onlineShop/xboxShop.nut")
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