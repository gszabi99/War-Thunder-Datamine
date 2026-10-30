from "%scripts/onlineShop/url.nut" import openUrl
from "%scripts/user/suggestionEmailRegistration.nut" import showGuestEmailRegistration, needShowGuestEmailRegistration
from "%scripts/items/itemsMarketplaceStatus.nut" import isMarketplaceEnabled
from "%scripts/dagui_library.nut" import *

let inventoryClient = require("%scripts/inventory/inventoryClient.nut")

function goToMarketplace() {
  if (!isMarketplaceEnabled())
    return

  if (needShowGuestEmailRegistration()) {
    showGuestEmailRegistration()
    return
  }

  openUrl(inventoryClient.getMarketplaceBaseUrl(), false, false, "marketplace")
}

return freeze({
  goToMarketplace
})