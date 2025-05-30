from "%scripts/dagui_natives.nut" import add_rta_localization
from "%scripts/dagui_library.nut" import *

let { eventbus_subscribe } = require("eventbus")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isEmpty } = require("%sqStdLibs/helpers/u.nut")
let { getSkinId } = require("%scripts/customization/skinUtils.nut")

let cache = {} 
let liveDecoratorsCache = {}
local waitingItemdefs = {}

function cacheDecor(decType, unitTypeTag) {
  let curCache = {
    categories      = []
    decoratorsList  = {}
    fullBlk         = null
    catToGroupNames = {} 
    catToGroups     = {} 
  }

  let blk = decType.getBlk()
  if (isEmpty(blk))
    return curCache

  curCache.fullBlk = blk 

  let prevCategory = ""
  let numDecors = blk.blockCount()
  for (local i = 0; i < numDecors; ++i) {
    let dblk = blk.getBlock(i)

    let decorator = ::Decorator(dblk, decType) 
    if (unitTypeTag != null && !decorator.isAllowedByUnitTypes(unitTypeTag))
      continue

    let category = dblk?.category ?? prevCategory
    decorator.category = category

    if (decorator.getCouponItemdefId() != null
        && !::ItemsManager.findItemById(decorator.getCouponItemdefId()))
      waitingItemdefs[decorator.getCouponItemdefId()] <- decorator

    curCache.decoratorsList[decorator.id] <- decorator

    if (!decorator.isVisible())
      continue

    if (category not in curCache.catToGroups) {
      curCache.categories.append(category)
      curCache.catToGroups[category] <- {}
      curCache.catToGroupNames[category] <- []
    }

    let group = dblk?.group ?? "other"
    if (group not in curCache.catToGroups[category]) {
      curCache.catToGroups[category][group] <- []
      curCache.catToGroupNames[category].append(group)
    }

    decorator.catIndex = curCache.catToGroups[category][group].len()
    curCache.catToGroups[category][group].append(decorator)
  }

  foreach (groupNames in curCache.catToGroupNames) {
    let idx = groupNames.indexof("other")
    if (idx != null && idx != (groupNames.len() - 1))
      groupNames.append(groupNames.remove(idx))
  }

  return curCache
}

function getCachedDataByType(decType, unitTypeTag = null) {
  let id = unitTypeTag != null
    ? $"proceedData_{decType.name}_{unitTypeTag}"
    : $"proceedData_{decType.name}"

  if (id in cache)
    return cache[id]

  let curCache = cacheDecor(decType, unitTypeTag)
  cache[id] <- curCache
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

  let res = decType.getSpecialDecorator(decorId)
    ?? getCachedDecoratorsListByType(decType)?[decorId]
    ?? decType.getLiveDecorator(decorId, liveDecoratorsCache)
  if (!res)
    log($"Decorators Manager: {decorId} was not found in the cache, try updating the cache.")
  return res
}

function getDecoratorById(decorId) {
  if (isEmpty(decorId))
    return null

  foreach (decType in ::g_decorator_type.types) {
    let res = getDecorator(decorId, decType)
    if (res)
      return res
  }

  return null
}

function getDecoratorByResource(resource, resourceType) {
  return getDecorator(resource, ::g_decorator_type.getTypeByResourceType(resourceType))
}

function addDecorToCache(decorator, decCache) {
  let category = decorator.category
  if (category not in decCache.catToGroups) {
    decCache.categories.append(category)
    decCache.catToGroups[category] <- {}
    decCache.catToGroupNames[category] <- []
  }

  let group = decorator.group != "" ? decorator.group : "other"
  if (group not in decCache.catToGroups[category]) {
    decCache.catToGroups[category][group] <- []
    decCache.catToGroupNames[category].append(group) 
  }

  let groupArr = decCache.catToGroups[category][group]
  if (groupArr.findindex(@(d) d.id == decorator.id) == null) {
    decorator.catIndex = groupArr.len()
    groupArr.append(decorator)
  }
}


function buildLiveDecoratorFromResource(resource, resourceType, itemDef, params) {
  if (!resource || !resourceType)
    return

  let decoratorId = (params?.unitId != null && resourceType == "skin")
    ? getSkinId(params.unitId, resource)
    : resource
  if (decoratorId in liveDecoratorsCache)
    return

  let decorator = ::Decorator(decoratorId, ::g_decorator_type.getTypeByResourceType(resourceType))
  decorator.updateFromItemdef(itemDef)
  add_rta_localization($"{decoratorId}", itemDef.name)
  add_rta_localization($"{decoratorId}/desc", itemDef.description)

  liveDecoratorsCache[decoratorId] <- decorator

  
  if (resource != decoratorId)
    liveDecoratorsCache[resource] <- decorator
}

function invalidateCache() {
  cache.clear()
  broadcastEvent("DecorCacheInvalidate")
}

function invalidateFlagCache() {
  let id = $"proceedData_{::g_decorator_type.FLAGS.name}"
  if (id in cache)
    cache.$rawdelete(id)
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
    updateDecorVisible(params.id, ::g_decorator_type.DECALS)
}

function onEventAttachableReceived(params) {
  if (params?.id != null)
    updateDecorVisible(params.id, ::g_decorator_type.ATTACHABLES)
}

function onEventItemsShopUpdate(_) {
  foreach (itemDefId, decorator in waitingItemdefs) {
    let couponItem = ::ItemsManager.findItemById(itemDefId)
    if (couponItem) {
      decorator.updateFromItemdef(couponItem.itemDef)
      waitingItemdefs[itemDefId] = null
    }
  }
  waitingItemdefs = waitingItemdefs.filter(@(v) v != null)
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
  getDecorator
  getDecoratorById
  getDecoratorByResource
  getCachedDataByType
  getCachedOrderByType
  getCachedDecoratorsListByType
  buildLiveDecoratorFromResource
}