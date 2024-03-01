from "%scripts/dagui_library.nut" import *

let getShopBlkData = require("%scripts/shop/getShopBlkData.nut")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_shop_blk } = require("blkGetters")

let shopCountriesList = persist("shopCountriesList", @() [])

local shopVisibleCountries = null

function invalidateVisibleCountriesCache() {
  shopVisibleCountries = null
  broadcastEvent("VisibleCountriesCacheInvalidate")
}

function getShopVisibleCountries() {
  if (shopVisibleCountries != null)
    return shopVisibleCountries

  shopVisibleCountries = getShopBlkData().shopData.map(@(c) c.name)
  return shopVisibleCountries
}

function updateShopCountriesList() {
  invalidateVisibleCountriesCache()
  let shopBlk = get_shop_blk()
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
