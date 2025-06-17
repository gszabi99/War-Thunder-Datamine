from "%scripts/dagui_library.nut" import *

let inventoryClient = require("%scripts/inventory/inventoryClient.nut")

let isMarketplaceEnabled = @() hasFeature("Marketplace")
  && hasFeature("AllowExternalLink") && inventoryClient.getMarketplaceBaseUrl() != null

return {
  isMarketplaceEnabled
}