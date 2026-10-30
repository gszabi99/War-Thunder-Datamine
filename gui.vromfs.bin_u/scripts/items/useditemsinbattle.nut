from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "gameplayBinding" import isInFlight
from "%scripts/dagui_library.nut" import *

let usedItemsInBattle = mkHardPersist("items.usedItemsInBattle")("usedItemsInBattle", {})

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

return freeze({
  markUsedItemCount
  getUsedItemCount
})
