//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

local shouldCheckAutoConsume = false

let failedAutoConsumeItems = {}

local isAutoConsumeInProgress = false

local autoConsumeItems = @() null
autoConsumeItems = function() {
  if (isAutoConsumeInProgress)
    return

  let onConsumeFinish = function(p = {}) {
    if (!(p?.success ?? true) && p?.itemId != null)
      failedAutoConsumeItems[p.itemId] <- true
    isAutoConsumeInProgress = false
    autoConsumeItems()
  }

  foreach (item in ::ItemsManager.getInventoryList())
    if (item.shouldAutoConsume && !(item.id in failedAutoConsumeItems)
      && item.consume(onConsumeFinish, {})) {
      isAutoConsumeInProgress = true
      break
    }
}

let function checkAutoConsume() {
  if (!shouldCheckAutoConsume)
    return
  shouldCheckAutoConsume = false
  autoConsumeItems()
}

addListenersWithoutEnv({
  SignOut = @(_p) failedAutoConsumeItems.clear()
})

return {
  setShouldCheckAutoConsume = @(value) shouldCheckAutoConsume = value
  checkAutoConsume
  autoConsumeItems
}



