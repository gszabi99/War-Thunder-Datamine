import "%scripts/guidParser.nut" as guidParser
import "DataBlock" as DataBlock
from "%scripts/customization/decoratorGetters.nut" import getDecorator
from "%scripts/customization/skinUtils.nut" import getSkinId
from "%scripts/items/itemsManagerModule.nut" import findItemById
from "eventbus" import eventbus_subscribe
from "%scripts/dagui_library.nut" import *
from "types" import Integer

let downloadableSkins = {} 

function updateDownloadableSkins(unitName, skinType) {
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
    let skinBlks = blkList.filter(@(blk) (blk?.marketplaceItemdefId instanceof Integer)
      && (blk?.reqFeature == null || hasFeature(blk.reqFeature))
      && (blk?.hideFeature == null || !hasFeature(blk.hideFeature)))

    foreach (blk in skinBlks) {
      let itemdefId = blk?.marketplaceItemdefId
      let item = findItemById(itemdefId)
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
      getDecorator(skinId, skinType)?.setCouponItemdefId(itemdefId)

      res.skinIds.append(itemdefId)
      if (blk?.needShowPreviewSuggestion)
        res.suggestedSkinIds[resource] <- skinId
    }
  }

  if (shouldCache)
    downloadableSkins[unitName] <- res
}

function getDownloadableSkins(unitName, skinType) {
  updateDownloadableSkins(unitName, skinType)
  return downloadableSkins?[unitName].skinIds ?? []
}

function getSuggestedSkins(unitName, skinType) {
  updateDownloadableSkins(unitName, skinType)
  return downloadableSkins?[unitName].suggestedSkinIds ?? {}
}

eventbus_subscribe("updateDownloadableDecoratorsInfo", @(p) updateDownloadableSkins(p.unitName, p.skinType))

return freeze({
  getDownloadableSkins
  getSuggestedSkins
})