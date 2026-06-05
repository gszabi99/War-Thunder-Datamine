from "%scripts/dagui_natives.nut" import add_rta_localization
from "%scripts/dagui_library.nut" import *

let { eventbus_subscribe } = require("eventbus")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isEmpty } = require("%sqStdLibs/helpers/u.nut")
let guidParser = require("%scripts/guidParser.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { cacheDecor, addDecorToCache, getSingleDecor } = require("%scripts/customization/addDecorToCache.nut")
let { decoratorCache, liveDecoratorsCache, waitingItemdefs
} = require("%scripts/customization/decoratorCache.nut")
let { decoratorTypes, getTypeByResourceType } = require("%scripts/customization/decoratorBaseType.nut")
let { Decorator } = require("%scripts/customization/decorator.nut")
let { getDecorTypeBlk } = require("%scripts/customization/decoratorTypeUtils.nut")
let { findItemById } = require("%scripts/items/itemsManagerModule.nut")
let { getSkinId, getSkinNameBySkinId } = require("%scripts/customization/skinUtils.nut")


function getDecorCacheByType(typeName) {
  if (decoratorCache?[typeName] == null)
    decoratorCache[typeName] <- {}
  return decoratorCache[typeName]
}

function getCachedDataByType(decType, unitTypeTag = null) {
  let decorClass = decType?.categoryPathPrefix ? "VIEW" : "BASE"
  let id = unitTypeTag != null
    ? $"proceedData_{decorClass}_{unitTypeTag}"
    : $"proceedData_{decorClass}"

  let dCache = getDecorCacheByType(decType.name)
  if (dCache?[id] == null)
    dCache[id] <- cacheDecor(decType, unitTypeTag)

  return dCache[id]
}

function getCachedOrderByType(decType, unitTypeTag = null) {
  return getCachedDataByType(decType, unitTypeTag).categories
}

function getCachedDecoratorsListByType(decType) {
  return getCachedDataByType(decType).decoratorsList
}

function getCachedDecorator(decId, decType, unitTypeTag = null) {
  let decorClass = decType?.categoryPathPrefix ? "VIEW" : "BASE"
  let cachedData = getDecorCacheByType(decType.name)

  let cacheId = unitTypeTag
    ? $"proceedData_{decorClass}_{unitTypeTag}"
    : $"proceedData_{decorClass}"
  let dCache = cachedData?[cacheId]
  if (dCache)
    return dCache.decoratorsList?[decId]

  
  let singleId = $"single_{decorClass}"
  if (decId in cachedData?[singleId])
    return cachedData[singleId][decId]

  let decorator = getSingleDecor(decId, decType)
  if (decorator) {
    if (singleId not in cachedData)
      cachedData[singleId] <- {}
    cachedData[singleId][decId] <- decorator
  }
  return decorator
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

function getDecorator(decorId, decType, unitTypeTag = null) {
  if (isEmpty(decorId))
    return null
  let res = getSkinsDefaultDecorator(decorId, decType)
    ?? getCachedDecorator(decorId, decType, unitTypeTag)
    ?? getSkinsLiveDecorator(decorId, decType)
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


function buildLiveDecoratorFromResource(resource, resourceType, itemDef, params) {
  if (!resource || !resourceType)
    return

  let decoratorId = (params?.unitId != null && resourceType == "skin")
    ? getSkinId(params.unitId, resource)
    : resource
  if (decoratorId in liveDecoratorsCache)
    return

  let decorator = Decorator(decoratorId, getTypeByResourceType(resourceType))
  decorator.updateFromItemdef(itemDef)
  add_rta_localization($"{decoratorId}", itemDef.name)
  add_rta_localization($"{decoratorId}/desc", itemDef.description)

  liveDecoratorsCache[decoratorId] <- decorator

  
  if (resource != decoratorId)
    liveDecoratorsCache[resource] <- decorator
}

function updateDecorVisible(decorId, decType) {
  let decCache = getCachedDataByType(decType)
  let decorator = decCache.decoratorsList?[decorId]
  if (!decorator || !decorator.isVisible())
    return

  addDecorToCache(decorator, decCache)
  foreach (unitType in unitTypes.types) {
    if (decorator.isAllowedByUnitTypes(unitType.tag)) {
      let cacheByUnitType = getCachedDataByType(decType, unitType.tag)
      addDecorToCache(decorator, cacheByUnitType)
    }
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
  HangarModelLoaded = @(_) invalidateFlagCache()
}, g_listener_priority.CONFIG_VALIDATION)


eventbus_subscribe("on_dl_content_skins_invalidate", @(_) invalidateCache())

return {
  getCachedDataByType
  getCachedOrderByType
  getCachedDecoratorsListByType
  getDecorator
  getDecoratorByResource
  getDecoratorById
  buildLiveDecoratorFromResource
}