//-file:plus-string
from "%scripts/dagui_library.nut" import *
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isEmpty } = require("%sqStdLibs/helpers/u.nut")
let { getSkinId } = require("%scripts/customization/skinUtils.nut")

let cache = {} // todo: consider adding persist
let liveDecoratorsCache = {}
local waitingItemdefs = {}

let function cacheDecor(decType, unitTypeTag) {
  let curCache = {
    categories      = []
    decoratorsList  = {}
    fullBlk         = null
    catToGroupNames = {} // { [catName]: string[] }
    catToGroups     = {} // { [catName]: { [groupName]: Decorator[] } }
  }

  let blk = decType.getBlk()
  if (isEmpty(blk))
    return curCache

  curCache.fullBlk = blk // do we need to keep the reference here?

  let prevCategory = ""
  let numDecors = blk.blockCount()
  for (local i = 0; i < numDecors; ++i) {
    let dblk = blk.getBlock(i)

    let decorator = ::Decorator(dblk, decType) // todo: consider using already created instances
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

let function getCachedDataByType(decType, unitTypeTag = null) {
  let id = unitTypeTag != null
    ? $"proceedData_{decType.name}_{unitTypeTag}"
    : $"proceedData_{decType.name}"

  if (id in cache)
    return cache[id]

  let curCache = cacheDecor(decType, unitTypeTag)
  cache[id] <- curCache
  return curCache
}

let function getCachedOrderByType(decType, unitTypeTag = null) {
  return getCachedDataByType(decType, unitTypeTag).categories
}

let function getCachedDecoratorsListByType(decType) {
  return getCachedDataByType(decType).decoratorsList
}

let function getDecorator(decorId, decType) {
  if (isEmpty(decorId))
    return null

  let res = decType.getSpecialDecorator(decorId)
    ?? getCachedDecoratorsListByType(decType)?[decorId]
    ?? decType.getLiveDecorator(decorId, liveDecoratorsCache)
  if (!res)
    log($"Decorators Manager: {decorId} was not found in the cache, try updating the cache.")
  return res
}

let function getDecoratorById(decorId) {
  if (isEmpty(decorId))
    return null

  foreach (decType in ::g_decorator_type.types) {
    let res = getDecorator(decorId, decType)
    if (res)
      return res
  }

  return null
}

let function getDecoratorByResource(resource, resourceType) {
  return getDecorator(resource, ::g_decorator_type.getTypeByResourceType(resourceType))
}

let function addDecorToCache(decorator, decCache) {
  let category = decorator.category
  if (category not in decCache.catToGroups) {
    decCache.categories.append(category)
    decCache.catToGroups[category] <- {}
    decCache.catToGroupNames[category] <- []
  }

  let group = decorator.group != "" ? decorator.group : "other"
  if (group not in decCache.catToGroups[category]) {
    decCache.catToGroups[category][group] <- []
    decCache.catToGroupNames[category].append(group) // FIXME: ensure that 'other' goes in the end of the list
  }

  let groupArr = decCache.catToGroups[category][group]
  if (groupArr.findindex(@(d) d.id == decorator.id) == null) {
    decorator.catIndex = groupArr.len()
    groupArr.append(decorator)
  }
}

// todo get rid of 'params'
let function buildLiveDecoratorFromResource(resource, resourceType, itemDef, params) {
  if (!resource || !resourceType)
    return

  let decoratorId = (params?.unitId != null && resourceType == "skin")
    ? getSkinId(params.unitId, resource)
    : resource
  if (decoratorId in liveDecoratorsCache)
    return

  let decorator = ::Decorator(decoratorId, ::g_decorator_type.getTypeByResourceType(resourceType))
  decorator.updateFromItemdef(itemDef)
  ::add_rta_localization($"{decoratorId}", itemDef.name)
  ::add_rta_localization($"{decoratorId}/desc", itemDef.description)

  liveDecoratorsCache[decoratorId] <- decorator

  // replace a fake skin decorator created by item constructor
  if (resource != decoratorId)
    liveDecoratorsCache[resource] <- decorator
}

let function invalidateCache() {
  cache.clear()
  broadcastEvent("DecorCacheInvalidate")
}

let function invalidateFlagCache() {
  let id = $"proceedData_{::g_decorator_type.FLAGS.name}"
  if (id in cache)
    cache.$rawdelete(id)
}

let function updateDecorVisible(decorId, decType) {
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

let function onEventDecalReceived(params) {
  if (params?.id != null)
    updateDecorVisible(params.id, ::g_decorator_type.DECALS)
}

let function onEventAttachableReceived(params) {
  if (params?.id != null)
    updateDecorVisible(params.id, ::g_decorator_type.ATTACHABLES)
}

let function onEventItemsShopUpdate(_) {
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
}, ::g_listener_priority.CONFIG_VALIDATION)

// native code callback
::on_dl_content_skins_invalidate <- function on_dl_content_skins_invalidate() {
  invalidateCache()
}

// native code callback
::update_unit_skins_list <- function update_unit_skins_list(unitName) {
  getAircraftByName(unitName)?.resetSkins()
}

return {
  getDecorator
  getDecoratorById
  getDecoratorByResource
  getCachedDataByType
  getCachedOrderByType
  getCachedDecoratorsListByType
  buildLiveDecoratorFromResource
}