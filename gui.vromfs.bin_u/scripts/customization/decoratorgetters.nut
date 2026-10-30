import "%scripts/g_listener_priority.nut" as g_listener_priority
import "%scripts/guidParser.nut" as guidParser
from "%scripts/customization/addDecorToCache.nut" import cacheDecor, addDecorToCache, getSingleDecor
from "%scripts/customization/decoratorBaseType.nut" import getTypeByResourceType
from "%scripts/customization/decorator.nut" import Decorator, DecoratorProbe
from "%scripts/customization/decoratorTypeUtils.nut" import getDecorTypeBlk
from "%scripts/items/itemsManagerModule.nut" import findItemById
from "%scripts/customization/skinUtils.nut" import getSkinId, getSkinNameBySkinId
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv, broadcastEvent
from "%sqStdLibs/helpers/u.nut" import isEmpty
from "eventbus" import eventbus_subscribe
from "%scripts/dagui_natives.nut" import add_rta_localization
from "%scripts/dagui_library.nut" import *

let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { decoratorCache, liveDecoratorsCache, waitingItemdefs } = require("%scripts/customization/decoratorCache.nut")
let { decoratorTypes } = require("%scripts/customization/decoratorBaseType.nut")


function getDecorCacheByType(typeName) {
  if (decoratorCache?[typeName] == null)
    decoratorCache[typeName] <- {}
  return decoratorCache[typeName]
}

function getCacheId(decType, unitTypeTag = null) {
  let decorClass = decType?.categoryPathPrefix ? "VIEW" : "BASE"
  return unitTypeTag != null
    ? $"proceedData_{decorClass}_{unitTypeTag}"
    : $"proceedData_{decorClass}"
}

function getSingleDecorators(decType) {
  let cachedData = getDecorCacheByType(decType.name)
  let singleId = decType?.categoryPathPrefix ? "single_VIEW" : "single_BASE"
  if (singleId not in cachedData)
    cachedData[singleId] <- {}
  return cachedData[singleId]
}

function getCanReceiveByBlkIdx(decType) {
  let cachedData = getDecorCacheByType(decType.name)
  if ("canReceiveByBlkIdx" not in cachedData)
    cachedData.canReceiveByBlkIdx <- array(getDecorTypeBlk(decType.name).blockCount(), null)
  return cachedData.canReceiveByBlkIdx
}

function getCachedDataByType(decType, unitTypeTag = null) {
  let id = getCacheId(decType, unitTypeTag)
  let dCache = getDecorCacheByType(decType.name)
  if (dCache?[id] == null)
    dCache[id] <- cacheDecor(decType, unitTypeTag, getSingleDecorators(decType), getCanReceiveByBlkIdx)

  return dCache[id]
}

function getCachedOrderByType(decType, unitTypeTag = null) {
  return getCachedDataByType(decType, unitTypeTag).categories
}

function getCachedDecorator(decId, decType) {
  let singleDecorators = getSingleDecorators(decType)
  let cachedDecorator = singleDecorators?[decId]
  if (cachedDecorator != null)
    return cachedDecorator

  let decorator = getSingleDecor(decId, decType)
  if (decorator)
    singleDecorators[decId] <- decorator
  return decorator
}

function getVisibleDecoratorsByType(decType) {
  let res = []
  let singleDecorators = getSingleDecorators(decType)
  let canReceiveByBlkIdx = getCanReceiveByBlkIdx(decType)
  let blk = getDecorTypeBlk(decType.name)
  for (local i = 0; i < blk.blockCount(); ++i) {
    let dblk = blk.getBlock(i)
    let decorator = singleDecorators?[dblk.getBlockName()]
      ?? DecoratorProbe(dblk, decType, i, canReceiveByBlkIdx)
    if (decorator.isVisible())
      res.append(getCachedDecorator(decorator.id, decType))
  }
  return res.filter(@(d) d != null)
}

function getSkinsDefaultDecorator(decorId, decType) {
  if (decType != decoratorTypes.SKINS)
    return null
  if (getSkinNameBySkinId(decorId) == "default")
    return Decorator(decorId, decType)
  return null
}

function getSkinsLiveDecorator(decorId, decType) {
  if (decType != decoratorTypes.SKINS)
    return null
  if (decorId in liveDecoratorsCache)
    return liveDecoratorsCache[decorId]

  let isLiveDownloaded = guidParser.isGuid(getSkinNameBySkinId(decorId))
  let isLiveItemContent = !isLiveDownloaded && guidParser.isGuid(decorId)
  if (!isLiveDownloaded && !isLiveItemContent)
    return null

  liveDecoratorsCache[decorId] <- Decorator(getDecorTypeBlk("SKINS")?[decorId] ?? decorId, decType)
  return liveDecoratorsCache[decorId]
}

function getDecorator(decorId, decType) {
  if (isEmpty(decorId))
    return null
  let res = getSkinsDefaultDecorator(decorId, decType)
    ?? getSkinsLiveDecorator(decorId, decType)
    ?? getCachedDecorator(decorId, decType)
  if (!res)
    log($"Decorators Manager: {decorId} was not found in the cache, try updating the cache.")
  return res
}

function getDecoratorByResource(resource, resourceType) {
  return getDecorator(resource, getTypeByResourceType(resourceType))
}

function getDecoratorById(decorId) {
  if (isEmpty(decorId))
    return null

  foreach (decType in decoratorTypes.types) {
    let res = getDecorator(decorId, decType)
    if (res)
      return res
  }

  return null
}

function buildLiveDecoratorFromResource(resource, resourceType, itemDef, unitId = null) {
  if (!resource || !resourceType)
    return

  let decoratorId = (unitId != null && resourceType == "skin")
    ? getSkinId(unitId, resource)
    : resource
  if (decoratorId in liveDecoratorsCache)
    return

  let decorator = Decorator(decoratorId, getTypeByResourceType(resourceType))
  decorator.updateFromItemdef(itemDef)
  add_rta_localization($"{decoratorId}", itemDef.name)
  add_rta_localization($"{decoratorId}/desc", itemDef?.description ?? "")

  liveDecoratorsCache[decoratorId] <- decorator

  
  if (resource != decoratorId)
    liveDecoratorsCache[resource] <- decorator
}

function updateDecorVisible(decorId, decType) {
  let decorator = getCachedDecorator(decorId, decType)
  if (!decorator || !decorator.isVisible())
    return

  let builtCaches = getDecorCacheByType(decType.name)
  let fullCache = builtCaches?[getCacheId(decType)]
  if (fullCache != null)
    addDecorToCache(decorator, fullCache)
  foreach (unitType in unitTypes.types) {
    let cacheByUnitType = builtCaches?[getCacheId(decType, unitType.tag)]
    if (cacheByUnitType != null && decorator.isAllowedByUnitTypes(unitType.tag))
      addDecorToCache(decorator, cacheByUnitType)
  }
}

function onEventDecalReceived(params) {
  if (params?.id != null)
    updateDecorVisible(params.id, decoratorTypes.DECALS)
}

function onEventAttachableReceived(params) {
  if (params?.id != null)
    updateDecorVisible(params.id, decoratorTypes.ATTACHABLES)
}

function onEventItemsShopUpdate(_) {
  let idemDefIdsToDel = []
  foreach (itemDefId, decorator in waitingItemdefs) {
    let couponItem = findItemById(itemDefId)
    if (couponItem) {
      decorator.updateFromItemdef(couponItem.itemDef)
      idemDefIdsToDel.append(itemDefId)
    }
  }
  foreach(itemDefId in idemDefIdsToDel)
    waitingItemdefs.$rawdelete(itemDefId)
}

function invalidateCache() {
  decoratorCache.clear()
  liveDecoratorsCache.clear()
  waitingItemdefs.clear()
  broadcastEvent("DecorCacheInvalidate")
}

function invalidateFlagCache() {
  if (decoratorTypes.FLAGS.name in decoratorCache)
    decoratorCache.$rawdelete(decoratorTypes.FLAGS.name)
}

addListenersWithoutEnv({
  DecalReceived = onEventDecalReceived
  AttachableReceived = onEventAttachableReceived
  ItemsShopUpdate = onEventItemsShopUpdate
  LoginComplete = @(_) invalidateCache()
  SignOut = @(_) invalidateCache()
  BlksDataStorageLoaded = @(_) invalidateCache()
  HangarModelLoaded = @(_) invalidateFlagCache()
}, g_listener_priority.CONFIG_VALIDATION)


eventbus_subscribe("on_dl_content_skins_invalidate", @(_) invalidateCache())

return freeze({
  getCachedDataByType
  getCachedOrderByType
  getVisibleDecoratorsByType
  getDecorator
  getDecoratorByResource
  getDecoratorById
  buildLiveDecoratorFromResource
})