from "%scripts/dagui_library.nut" import *

let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let CollectionSet = require("collectionSet.nut")
let DataBlock = require("DataBlock")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")

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

subscriptions.addListenersWithoutEnv({
  SignOut = @(_p) invalidateCache()
})

return {
  getCollectionsList = getCollectionsList
  isCollectionPrize = isCollectionPrize
  isCollectionItem = isCollectionItem
}