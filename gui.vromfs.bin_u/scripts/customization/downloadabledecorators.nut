//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let guidParser = require("%scripts/guidParser.nut")
let DataBlock = require("DataBlock")
let { getDecorator, getSkinId } = require("%scripts/customization/decorCache.nut")

let downloadableSkins = {} // { unitName = { skinIds = [], suggestedSkinIds = {} } }

let function updateDownloadableSkins(unitName) {
  if (downloadableSkins?[unitName] != null)
    return

  let res = {
    skinIds = []
    suggestedSkinIds = {}
  }

  local shouldCache = true

  if (hasFeature("MarketplaceSkinsInCustomization") && hasFeature("Marketplace")
    && hasFeature("EnableLiveSkins")) {
    let marketSkinsBlk = DataBlock()
    marketSkinsBlk.load("config/skins_market.blk")
    let blkList = marketSkinsBlk % unitName
    let skinBlks = blkList.filter(@(blk) (type(blk?.marketplaceItemdefId) == "integer")
      && (blk?.reqFeature == null || hasFeature(blk.reqFeature))
      && (blk?.hideFeature == null || !hasFeature(blk.hideFeature)))

    foreach (blk in skinBlks) {
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

      let skinId = isLive ? getSkinId(unitName, resource) : resource
      getDecorator(skinId, ::g_decorator_type.SKINS)?.setCouponItemdefId(itemdefId)

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