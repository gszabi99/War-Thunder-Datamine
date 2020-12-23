local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")

local shouldCheckAutoConsume = ::Watched(false)

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
  if (!shouldCheckAutoConsume.value)
    return
  shouldCheckAutoConsume(false)
  autoConsumeItems()
}

addListenersWithoutEnv({
  SignOut = @(p) failedAutoConsumeItems.clear()
})

return {
  shouldCheckAutoConsume
  checkAutoConsume
  autoConsumeItems
}



