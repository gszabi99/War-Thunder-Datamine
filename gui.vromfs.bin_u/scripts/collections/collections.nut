//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let CollectionSet = require("collectionSet.nut")
let DataBlock = require("DataBlock")

let collectionsList = []
local isInited = false

let function initOnce() {
  if (isInited || !::g_login.isProfileReceived())
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

let function invalidateCache() {
  collectionsList.clear()
  isInited = false
}

let function getCollectionsList() {
  initOnce()
  return collectionsList
}

let function isCollectionPrize(decorator) {
  return getCollectionsList().findindex(@(c) c.prize == decorator) != null
}

let function isCollectionItem(decorator) {
  return decorator != null
    ? getCollectionsList().findindex(@(c) c.findDecoratorById(decorator.id).decorator != null) != null
    : false
}

subscriptions.addListenersWithoutEnv({
  SignOut = @(_p) invalidateCache()
})

return {
  getCollectionsList = getCollectionsList
  isCollectionPrize = isCollectionPrize
  isCollectionItem = isCollectionItem
}