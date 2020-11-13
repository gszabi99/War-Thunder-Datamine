local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")

local unlocksArray = []
local isArrayValid = false

local function reset() {
  unlocksArray.clear()
}

local function update() {
  if (!::g_login.isLoggedIn())
    return

  reset()

  foreach(unlockBlk in ::g_unlocks.getAllUnlocksWithBlkOrder())
    if (unlockBlk?.showAsBattleTask ?? false) {
      unlocksArray.append(unlockBlk)
    }
  isArrayValid = true
}

local function getUnlocksArray() {
  if(!isArrayValid)
    update()

  return unlocksArray
}

local function invalidateArray() {
  isArrayValid = false
}

subscriptions.addListenersWithoutEnv({
  SignOut = @(p) invalidateArray()
  LoginComplete = @(p) invalidateArray()
  UnlocksCacheInvalidate = @(p) invalidateArray()
}, ::g_listener_priority.CONFIG_VALIDATION)


return {
  getPersonalUnlocks =  getUnlocksArray
}