let guidParser = require("%scripts/guidParser.nut")

let downloadableSkins = {} // { unitName = [] }

let function updateDownloadableSkins(unit) {
  if (downloadableSkins?[unit.name] != null)
    return

  let res = []
  local shouldCache = true

  if (::has_feature("MarketplaceSkinsInCustomization") && ::has_feature("Marketplace")
    && ::has_feature("EnableLiveSkins"))
  {
    let marketSkinsBlk = ::DataBlock()
    marketSkinsBlk.load("config/skins_market.blk")
    let blkList = marketSkinsBlk % unit.name
    let itemdefIdsList = blkList.filter(function(blk) {
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
      let item = ::ItemsManager.findItemById(itemdefId)
      shouldCache = shouldCache && item != null
      if (item == null)
        continue

      let resource = item.getMetaResource()
      if (!resource || !item.hasLink())
        continue

      let isLive = guidParser.isGuid(resource)
      if (isLive)
        item.addResourcesByUnitId(unit.name)
      let skinId = isLive ? ::g_unlocks.getSkinId(unit.name, resource) : resource
      ::g_decorator.getDecorator(skinId, ::g_decorator_type.SKINS)?.setCouponItemdefId(itemdefId)

      res.append(itemdefId)
    }
  }

  if (shouldCache)
    downloadableSkins[unit.name] <- res
}

let function getDownloadableSkins(unit) {
  updateDownloadableSkins(unit)
  return downloadableSkins?[unit.name] ?? []
}

return {
  getDownloadableSkins = getDownloadableSkins
  updateDownloadableSkins = updateDownloadableSkins
}