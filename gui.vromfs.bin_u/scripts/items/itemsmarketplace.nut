from "%scripts/dagui_library.nut" import *

let inventoryClient = require("%scripts/inventory/inventoryClient.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { showGuestEmailRegistration, needShowGuestEmailRegistration
} = require("%scripts/user/suggestionEmailRegistration.nut")
let { isMarketplaceEnabled } = require("%scripts/items/itemsMarketplaceStatus.nut")

function goToMarketplace() {
  if (!isMarketplaceEnabled())
    return

  if (needShowGuestEmailRegistration()) {
    showGuestEmailRegistration()
    return
  }

  openUrl(inventoryClient.getMarketplaceBaseUrl(), false, false, "marketplace")
}

return {
  goToMarketplace
}