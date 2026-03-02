from "%scripts/dagui_natives.nut" import add_rta_localization
from "%scripts/dagui_library.nut" import *

let { eventbus_subscribe } = require("eventbus")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isEmpty } = require("%sqStdLibs/helpers/u.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { cacheDecor, addDecorToCache } = require("%scripts/customization/addDecorToCache.nut")
let { decoratorCache, liveDecoratorsCache, waitingItemdefs
} = require("%scripts/customization/decoratorCache.nut")
let { decoratorTypes, getTypeByResourceType } = require("%scripts/customization/decoratorBaseType.nut")
let { findItemById } = require("%scripts/items/itemsManagerModule.nut")
let { getSkinId } = require("%scripts/customization/skinUtils.nut")

function getCachedDataByType(decType, unitTypeTag = null) {
  let decorClass = decType?.categoryPathPrefix ? "VIEW" : "BASE"
  let id = unitTypeTag != null
    ? $"proceedData_{decorClass}_{decType.name}_{unitTypeTag}"
    : $"proceedData_{decorClass}_{decType.name}"

  let dCache = decoratorCache?[id]
  if (dCache)
    return dCache

  let curCache = cacheDecor(decType, unitTypeTag)
  decoratorCache[id] <- curCache
  return curCache
}

function getCachedOrderByType(decType, unitTypeTag = null) {
  return getCachedDataByType(decType, unitTypeTag).categories
}

function getCachedDecoratorsListByType(decType) {
  return getCachedDataByType(decType).decoratorsList
}

function getDecorator(decorId, decType) {
  if (isEmpty(decorId))
    return null
  let res = decType?.getSpecialDecorator(decorId)
    ?? getCachedDecoratorsListByType(decType)?[decorId]
    ?? decType?.getLiveDecorator(decorId, liveDecoratorsCache)
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

  let decorator = ::Decorator(decoratorId, getTypeByResourceType(resourceType))
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
  let id = $"proceedData_{decoratorTypes.FLAGS.name}"
  if (id in decoratorCache)
    decoratorCache.$rawdelete(id)
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