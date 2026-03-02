from "%scripts/dagui_library.nut" import *

let { waitingItemdefs } = require("%scripts/customization/decoratorCache.nut")

let { isEmpty } = require("%sqStdLibs/helpers/u.nut")
let { findItemById } = require("%scripts/items/itemsManagerModule.nut")
let { getDecorTypeBlk, needCacheDecorTypeByCategories
} = require("%scripts/customization/decoratorTypeUtils.nut")

function cacheDecor(decType, unitTypeTag) {
  let curCache = {
    categories      = []
    decoratorsList  = {}
    fullBlk         = null
    catToGroupNames = {} 
    catToGroups     = {} 
  }

  let blk = getDecorTypeBlk(decType.name)
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
        && !findItemById(decorator.getCouponItemdefId()))
      waitingItemdefs[decorator.getCouponItemdefId()] <- decorator

    curCache.decoratorsList[decorator.id] <- decorator
    if (!needCacheDecorTypeByCategories(decType.name) || !decorator.isVisible())
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

return {
  cacheDecor
  addDecorToCache
}