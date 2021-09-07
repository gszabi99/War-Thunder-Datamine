local shopCountriesList = persist("shopCountriesList", @() [])

local function updateShopCountriesList() {
  local shopBlk = ::get_shop_blk()
  shopCountriesList.clear()
  for (local tree = 0; tree < shopBlk.blockCount(); tree++)
    shopCountriesList.append(shopBlk.getBlock(tree).getBlockName())
}

return {
  shopCountriesList
  updateShopCountriesList
}
