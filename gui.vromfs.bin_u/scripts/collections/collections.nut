local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")
local CollectionSet = require("collectionSet.nut")

local collectionsList = []
local isInited = false

local function initOnce() {
  if (isInited || !::g_login.isProfileReceived())
    return
  isInited = true
  collectionsList.clear()

  local cBlk = ::DataBlock("config/collections.blk")
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

subscriptions.addListenersWithoutEnv({
  SignOut = @(p) invalidateCache()
})

return {
  getCollectionsList = getCollectionsList
}