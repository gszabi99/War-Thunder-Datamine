local guidParser = require("scripts/guidParser.nut")

local downloadableSkins = {} // { unitName = [] }

local function updateDownloadableSkins(unit) {
  if (downloadableSkins?[unit.name] != null)
    return

  local res = []
  local shouldCache = true

  if (::has_feature("MarketplaceSkinsInCustomization") && ::has_feature("Marketplace")
    && ::has_feature("EnableLiveSkins"))
  {
    local marketSkinsBlk = ::DataBlock()
    marketSkinsBlk.load("config/skins_market.blk")
    local blkList = marketSkinsBlk % unit.name
    local itemdefIdsList = blkList.filter(function(blk) {
      if (type(blk?.marketplaceItemdefId) != "integer")
        return false
      if (blk?.reqFeature != null && !::has_feature(blk.reqFeature))
        return false
      if (blk?.hideFeature != null && ::has_feature(blk.hideFeature))
        return false
      return true
    }).map(@(blk) blk?.marketplaceItemdefId)

    foreach (itemdefId in itemdefIdsList)
    {
      local item = ::ItemsManager.findItemById(itemdefId)
      shouldCache = shouldCache && item != null
      if (item == null)
        continue

      local resource = item.getMetaResource()
      if (!resource || !item.hasLink())
        continue

      local isLive = guidParser.isGuid(resource)
      if (isLive)
        item.addResourcesByUnitId(unit.name)
      local skinId = isLive ? ::g_unlocks.getSkinId(unit.name, resource) : resource
      ::g_decorator.getDecorator(skinId, ::g_decorator_type.SKINS)?.setCouponItemdefId(itemdefId)

      res.append(itemdefId)
    }
  }

  if (shouldCache)
    downloadableSkins[unit.name] <- res
}

local function getDownloadableSkins(unit) {
  updateDownloadableSkins(unit)
  return downloadableSkins?[unit.name] ?? []
}

return {
  getDownloadableSkins = getDownloadableSkins
  updateDownloadableSkins = updateDownloadableSkins
}