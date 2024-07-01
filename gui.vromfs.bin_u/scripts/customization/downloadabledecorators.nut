from "%scripts/dagui_library.nut" import *

let guidParser = require("%scripts/guidParser.nut")
let DataBlock = require("DataBlock")
let { getDecorator } = require("%scripts/customization/decorCache.nut")
let { getSkinId } = require("%scripts/customization/skinUtils.nut")

let downloadableSkins = {} // { unitName = { skinIds = [], suggestedSkinIds = {} } }

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

return {
  getDownloadableSkins
  getSuggestedSkins
  updateDownloadableSkins
}