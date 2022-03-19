local subscriptions = require("sqStdLibs/helpers/subscriptions.nut")
local CollectionSet = require("collectionSet.nut")

local collectionsList = []
local isInited = false

local function initOnce() {
  if (isInited || !::g_login.isProfileReceived())
    return
  isInited = true
  collectionsList.clear()

  local cBlk = ::DataBlock()
  cBlk.load("config/collections.blk")
  for(local i = 0; i < cBlk.blockCount(); i++) {
    local set = CollectionSet(cBlk.getBlock(i))
    if (!set.isValid())
      continue

    set.uid = collectionsList.len()
    collectionsList.append(set)
  }
}

local function invalidateCache() {
  collectionsList.clear()
  isInited = false
}

local function getCollectionsList() {
  initOnce()
  return collectionsList
}

local function isCollectionPrize(decorator) {
  return getCollectionsList().findindex(@(c) c.prize == decorator) != null
}

local function isCollectionItem(decorator) {
  return decorator != null
    ? getCollectionsList().findindex(@(c) c.findDecoratorById(decorator.id).decorator != null) != null
    : false
}

subscriptions.addListenersWithoutEnv({
  SignOut = @(p) invalidateCache()
})

return {
  getCollectionsList = getCollectionsList
  isCollectionPrize = isCollectionPrize
  isCollectionItem = isCollectionItem
}