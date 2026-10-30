from "%scripts/items/itemsManagerModule.nut" import findItemById
from "%scripts/customization/decoratorTypeUtils.nut" import getDecorTypeBlk, needCacheDecorTypeByCategories
from "%scripts/customization/decorator.nut" import Decorator, DecoratorProbe
from "%sqStdLibs/helpers/u.nut" import isEmpty
from "%scripts/dagui_library.nut" import *

let { waitingItemdefs } = require("%scripts/customization/decoratorCache.nut")


function getSingleDecor(decorId, decType) {
  let dblk = getDecorTypeBlk(decType.name)?[decorId]
  if (isEmpty(dblk))
    return null

  let decorator = Decorator(dblk, decType)

  if (decorator.getCouponItemdefId() != null
    && !findItemById(decorator.getCouponItemdefId()))
      waitingItemdefs[decorator.getCouponItemdefId()] <- decorator

  return decorator
}

function cacheDecor(decType, unitTypeTag, singleDecorators, getCanReceiveByBlkIdx) {
  let curCache = {
    categories      = []
    catToGroupNames = {} 
    catToGroups     = {} 
  }

  let blk = getDecorTypeBlk(decType.name)
  if (isEmpty(blk) || !needCacheDecorTypeByCategories(decType.name))
    return curCache

  let canReceiveByBlkIdx = getCanReceiveByBlkIdx(decType)
  let numDecors = blk.blockCount()
  for (local i = 0; i < numDecors; ++i) {
    let dblk = blk.getBlock(i)

    let decorator = singleDecorators?[dblk.getBlockName()]
      ?? DecoratorProbe(dblk, decType, i, canReceiveByBlkIdx)
    if (unitTypeTag != null && !decorator.isAllowedByUnitTypes(unitTypeTag))
      continue
    if (!decorator.isVisible())
      continue

    let category = dblk?.category ?? ""
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

    curCache.catToGroups[category][group].append(decorator.id)
  }

  foreach (groupNames in curCache.catToGroupNames) {
    let idx = groupNames.indexof("other")
    if (idx != null && idx != (groupNames.len() - 1))
      groupNames.append(groupNames.remove(idx))
  }

  return curCache
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
  if (!groupArr.contains(decorator.id))
    groupArr.append(decorator.id)
}

return freeze({
  cacheDecor
  addDecorToCache
  getSingleDecor
})
