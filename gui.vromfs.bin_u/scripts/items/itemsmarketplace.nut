let inventoryClient = require("scripts/inventory/inventoryClient.nut")
let { openUrl } = require("scripts/onlineShop/url.nut")

let isMarketplaceEnabled = @() ::has_feature("Marketplace")
  && ::has_feature("AllowExternalLink") && inventoryClient.getMarketplaceBaseUrl() != null

let function goToMarketplace()
{
  if (isMarketplaceEnabled())
    openUrl(inventoryClient.getMarketplaceBaseUrl(), false, false, "marketplace")
}

return {
  isMarketplaceEnabled     = isMarketplaceEnabled
  goToMarketplace          = goToMarketplace
}