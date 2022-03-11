local inventoryClient = require("scripts/inventory/inventoryClient.nut")
local { openUrl } = require("scripts/onlineShop/url.nut")

local isMarketplaceEnabled = @() ::has_feature("Marketplace")
  && ::has_feature("AllowExternalLink") && inventoryClient.getMarketplaceBaseUrl() != null

local function goToMarketplace()
{
  if (isMarketplaceEnabled())
    openUrl(inventoryClient.getMarketplaceBaseUrl(), false, false, "marketplace")
}

return {
  isMarketplaceEnabled     = isMarketplaceEnabled
  goToMarketplace          = goToMarketplace
}