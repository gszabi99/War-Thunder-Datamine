local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")

local shouldCheckAutoConsume = false

local failedAutoConsumeItems = {}

local isAutoConsumeInProgress = false

local autoConsumeItems = @() null
autoConsumeItems = function() {
  if (isAutoConsumeInProgress)
    return

  local onConsumeFinish = function(p = {}) {
    if (!(p?.success ?? true) && p?.itemId != null)
      failedAutoConsumeItems[p.itemId] <- true
    isAutoConsumeInProgress = false
    autoConsumeItems()
  }

  foreach(item in ::ItemsManager.getInventoryList())
    if (item.shouldAutoConsume && !(item.id in failedAutoConsumeItems)
      && item.consume(onConsumeFinish, {}))
    {
      isAutoConsumeInProgress = true
      break
    }
}

local function checkAutoConsume() {
  if (!shouldCheckAutoConsume)
    return
  shouldCheckAutoConsume = false
  autoConsumeItems()
}

addListenersWithoutEnv({
  SignOut = @(p) failedAutoConsumeItems.clear()
})

return {
  setShouldCheckAutoConsume = @(value) shouldCheckAutoConsume = value
  checkAutoConsume
  autoConsumeItems
}



