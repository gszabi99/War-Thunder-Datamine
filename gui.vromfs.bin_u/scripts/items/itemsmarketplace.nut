from "%scripts/dagui_library.nut" import *

let inventoryClient = require("%scripts/inventory/inventoryClient.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { showGuestEmailRegistration, needShowGuestEmailRegistration
} = require("%scripts/user/suggestionEmailRegistration.nut")


let isMarketplaceEnabled = @() hasFeature("Marketplace")
  && hasFeature("AllowExternalLink") && inventoryClient.getMarketplaceBaseUrl() != null

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
  isMarketplaceEnabled     = isMarketplaceEnabled
  goToMarketplace          = goToMarketplace
}