from "%scripts/unlocks/unlocksCache.nut" import getUnlocksByTypeInBlkOrder
from "%scripts/unlocks/unlocksModule.nut" import isUnlockVisible
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "%scripts/dagui_library.nut" import *

let inventoryClient = require("%scripts/inventory/inventoryClient.nut")

function requestInventoryUnlocks() {
  let itemsToRequest = getUnlocksByTypeInBlkOrder("inventory")
    .filter(@(v) isUnlockVisible(v))
    .map(@(v) v.userLogId)
  inventoryClient.requestItemdefsByIds(itemsToRequest)
}

addListenersWithoutEnv({
  UnlocksCacheInvalidate = @(_p) requestInventoryUnlocks()
})

return freeze({
  requestInventoryUnlocks
})