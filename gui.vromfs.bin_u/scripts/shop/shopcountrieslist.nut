//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let getShopBlkData = require("%scripts/shop/getShopBlkData.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

let shopCountriesList = persist("shopCountriesList", @() [])

local shopVisibleCountries = null

let function invalidateVisibleCountriesCache() {
  shopVisibleCountries = null
  ::broadcastEvent("VisibleCountriesCacheInvalidate")
}

let function getShopVisibleCountries() {
  if (shopVisibleCountries != null)
    return shopVisibleCountries

  shopVisibleCountries = getShopBlkData().shopData.map(@(c) c.name)
  return shopVisibleCountries
}

let function updateShopCountriesList() {
  invalidateVisibleCountriesCache()
  let shopBlk = ::get_shop_blk()
  shopCountriesList.clear()
  for (local tree = 0; tree < shopBlk.blockCount(); tree++)
    shopCountriesList.append(shopBlk.getBlock(tree).getBlockName())
}

addListenersWithoutEnv({
  DebugUnlockEnabled = @(_p) invalidateVisibleCountriesCache()
})

return {
  shopCountriesList
  updateShopCountriesList
  getShopVisibleCountries
}
