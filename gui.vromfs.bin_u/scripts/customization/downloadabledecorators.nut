let guidParser = require("%scripts/guidParser.nut")

let downloadableSkins = {} // { unitName = { skinIds = [], suggestedSkinIds = {} } }

let function updateDownloadableSkins(unitName) {
  if (downloadableSkins?[unitName] != null)
    return

  let res = {
    skinIds = []
    suggestedSkinIds = {}
  }

  local shouldCache = true

  if (::has_feature("MarketplaceSkinsInCustomization") && ::has_feature("Marketplace")
    && ::has_feature("EnableLiveSkins"))
  {
    let marketSkinsBlk = ::DataBlock()
    marketSkinsBlk.load("config/skins_market.blk")
    let blkList = marketSkinsBlk % unitName
    let skinBlks = blkList.filter(@(blk) (type(blk?.marketplaceItemdefId) == "integer")
      && (blk?.reqFeature == null || ::has_feature(blk.reqFeature))
      && (blk?.hideFeature == null || !::has_feature(blk.hideFeature)))

    foreach (blk in skinBlks)
    {
      let itemdefId = blk?.marketplaceItemdefId
      let item = ::ItemsManager.findItemById(itemdefId)
      shouldCache = shouldCache && item != null
      if (item == null)
        continue

      let resource = item.getMetaResource()
      if (!resource || !item.hasLink())
        continue

      let isLive = guidParser.isGuid(resource)
      if (isLive)
        item.addResourcesByUnitId(unitName)

      let skinId = isLive ? ::g_unlocks.getSkinId(unitName, resource) : resource
      ::g_decorator.getDecorator(skinId, ::g_decorator_type.SKINS)?.setCouponItemdefId(itemdefId)

      res.skinIds.append(itemdefId)
      if (blk?.needShowPreviewSuggestion)
        res.suggestedSkinIds[resource] <- skinId
    }
  }

  if (shouldCache)
    downloadableSkins[unitName] <- res
}

let function getDownloadableSkins(unitName) {
  updateDownloadableSkins(unitName)
  return downloadableSkins?[unitName].skinIds ?? []
}

let function getSuggestedSkins(unitName) {
  updateDownloadableSkins(unitName)
  return downloadableSkins?[unitName].suggestedSkinIds ?? {}
}

return {
  getDownloadableSkins
  getSuggestedSkins
  updateDownloadableSkins
}