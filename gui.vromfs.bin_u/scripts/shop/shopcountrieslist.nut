local getShopBlkData = require("scripts/shop/getShopBlkData.nut")
local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")

local shopCountriesList = persist("shopCountriesList", @() [])

local shopVisibleCountries = null

local function invalidateVisibleCountriesCache() {
  shopVisibleCountries = null
  ::broadcastEvent("VisibleCountriesCacheInvalidate")
}

local function getShopVisibleCountries() {
  if (shopVisibleCountries != null)
    return shopVisibleCountries

  shopVisibleCountries = getShopBlkData().shopData.map(@(c) c.name)
  return shopVisibleCountries
}

local function updateShopCountriesList() {
  invalidateVisibleCountriesCache()
  local shopBlk = ::get_shop_blk()
  shopCountriesList.clear()
  for (local tree = 0; tree < shopBlk.blockCount(); tree++)
    shopCountriesList.append(shopBlk.getBlock(tree).getBlockName())
}

addListenersWithoutEnv({
  DebugUnlockEnabled = @(p) invalidateVisibleCountriesCache()
})

return {
  shopCountriesList
  updateShopCountriesList
  getShopVisibleCountries
}
