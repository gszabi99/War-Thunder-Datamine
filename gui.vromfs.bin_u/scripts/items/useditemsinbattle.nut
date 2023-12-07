from "%scripts/dagui_library.nut" import *

let { isInFlight } = require("gameplayBinding")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

let usedItemsInBattle = persist("usedItemsInBattle", @() {})

function markUsedItemCount(iType, itemId, count = 1) {
  if (iType not in usedItemsInBattle)
    usedItemsInBattle[iType] <- {}

  usedItemsInBattle[iType][itemId] <- (usedItemsInBattle[iType]?[itemId] ?? 0) + count
}

let getUsedItemCount = @(iType, itemId) usedItemsInBattle?[iType][itemId] ?? 0

addListenersWithoutEnv({
  function LoadingStateChange(_) {
    if (!isInFlight())
      usedItemsInBattle.clear()
  }
})

return {
  markUsedItemCount
  getUsedItemCount
}
