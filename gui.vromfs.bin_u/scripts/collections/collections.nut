import "DataBlock" as DataBlock
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv, broadcastEvent
from "%appGlobals/login/loginState.nut" import isProfileReceived
from "%scripts/dagui_library.nut" import *

let CollectionSet = require("%scripts/collections/collectionSet.nut")

let collectionsList = []
local isInited = false

function initOnce() {
  if (isInited || !isProfileReceived.get())
    return
  isInited = true
  collectionsList.clear()

  let cBlk = DataBlock()
  cBlk.load("config/collections.blk")
  for (local i = 0; i < cBlk.blockCount(); i++) {
    let set = CollectionSet(cBlk.getBlock(i))
    if (!set.isValid())
      continue

    set.uid = collectionsList.len()
    collectionsList.append(set)
  }
}

function invalidateCache() {
  collectionsList.clear()
  isInited = false
  broadcastEvent("CollectionsCacheInvalidate")
}

function getCollectionsList() {
  initOnce()
  return collectionsList
}

function isCollectionPrize(decorator) {
  return getCollectionsList().findindex(@(c) c.prize == decorator) != null
}

function isCollectionItem(decorator) {
  return decorator != null
    ? getCollectionsList().findindex(@(c) c.findDecoratorById(decorator.id).decorator != null) != null
    : false
}

let hasAvailableCollections = @() hasFeature("Collection") && getCollectionsList().len() > 0

addListenersWithoutEnv({
  DecorCacheInvalidate = @(_) invalidateCache()
})

return {
  getCollectionsList = getCollectionsList
  isCollectionPrize = isCollectionPrize
  isCollectionItem = isCollectionItem
  hasAvailableCollections
}