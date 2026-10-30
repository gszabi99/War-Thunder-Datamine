from "%scripts/clientState/clientStates.nut" import isInMenu
from "%sqstd/platform.nut" import is_gdk, isSony, isPC
from "%appGlobals/clientState/platform.nut" import canSpendRealMoney
from "%scripts/dagui_natives.nut" import epic_is_running
from "%globalScripts/loc_helpers.nut" import getVendorLocId
from "%scripts/dagui_library.nut" import *

let {
  getEntStoreLocId = @() $"#{getVendorLocId("msgbox/btn_onlineShop")}",
  getEntStoreIcon = @() "#ui/gameuiskin#store_icon.svg",
  isEntStoreTopMenuItemHidden = @(...) !isPC || !hasFeature("SpendGold") || !isInMenu.get() || !canSpendRealMoney(),
  getEntStoreUnseenIcon = @() null,
  openEntStoreTopMenuFunc = @(_obj, handler) handler.startOnlineShop(null, null, "topmenu"),
  openIngameStore = @(...) false,
} = isSony ? require("%scripts/onlineShop/ps4ShopApi.nut")
  : is_gdk ? require("%scripts/onlineShop/xboxShopApi.nut")
  : epic_is_running() ? require("%scripts/onlineShop/epicShopApi.nut")
  : null

return freeze({
  getEntStoreLocId
  getEntStoreIcon
  isEntStoreTopMenuItemHidden
  getEntStoreUnseenIcon
  openEntStoreTopMenuFunc
  openIngameStore
})
