from "%scripts/dagui_natives.nut" import epic_is_running
from "%scripts/dagui_library.nut" import *

let { is_gdk } = require("%sqstd/platform.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { isPlatformSony, isPlatformPC, canSpendRealMoney
} = require("%scripts/clientState/platform.nut")

let {
  getEntStoreLocId = @() "#msgbox/btn_onlineShop",
  getEntStoreIcon = @() "#ui/gameuiskin#store_icon.svg",
  isEntStoreTopMenuItemHidden = @(...) !isPlatformPC || !hasFeature("SpendGold") || !isInMenu.get() || !canSpendRealMoney(),
  getEntStoreUnseenIcon = @() null,
  openEntStoreTopMenuFunc = @(_obj, handler) handler.startOnlineShop(null, null, "topmenu"),
  openIngameStore = @(...) false,
} = isPlatformSony ? require("%scripts/onlineShop/ps4Shop.nut")
  : is_gdk ? require("%scripts/onlineShop/xboxShop.nut")
  : epic_is_running() ? require("%scripts/onlineShop/epicShop.nut")
  : null

return {
  getEntStoreLocId
  getEntStoreIcon
  isEntStoreTopMenuItemHidden
  getEntStoreUnseenIcon
  openEntStoreTopMenuFunc
  openIngameStore
}
