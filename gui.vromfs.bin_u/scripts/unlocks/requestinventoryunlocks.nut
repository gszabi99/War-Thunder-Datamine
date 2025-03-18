from "%scripts/dagui_library.nut" import *

let { getUnlocksByTypeInBlkOrder } = require("%scripts/unlocks/unlocksCache.nut")
let { isUnlockVisible } = require("%scripts/unlocks/unlocksModule.nut")
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

function requestInventoryUnlocks() {
  let itemsToRequest = getUnlocksByTypeInBlkOrder("inventory")
    .filter(@(v) isUnlockVisible(v))
    .map(@(v) v.userLogId)
  inventoryClient.requestItemdefsByIds(itemsToRequest)
}

addListenersWithoutEnv({
  UnlocksCacheInvalidate = @(_p) requestInventoryUnlocks()
})