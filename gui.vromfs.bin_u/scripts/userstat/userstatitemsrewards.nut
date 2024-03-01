from "%scripts/dagui_library.nut" import *

let { eventbus_send } = require("eventbus")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

let userstatItemsListLocId = "mainmenu/rewardsList"

let waitingToShowRewardsArray = persist("waitingToShowRewardsArray", @() [])

function showRewardWnd(params) {
  let { rewards, rewardTitleLocId } = params
  if ((rewards?.len() ?? 0) == 0)
    return

  let rewardsToShow = []
  local firstItemId = null
  foreach (itemIdSrc, count in rewards) {
    let itemId = itemIdSrc.tointeger()
    let item = ::ItemsManager.findItemById(itemId)
    if (item == null)
      continue
    if (item.shouldAutoConsume) //show recived rewards after auto consume
      waitingToShowRewardsArray.append({ itemId, rewardTitleLocId })
    else {
      rewardsToShow.append({ itemDefId = itemId
        item = itemId
        count = count
      })
      firstItemId = firstItemId ?? itemId
    }
  }

  if (firstItemId != null)
    eventbus_send("guiStartOpenTrophy", {
      [firstItemId] = rewardsToShow,
      rewardTitle = loc(rewardTitleLocId),
      rewardListLocId = userstatItemsListLocId
    })
}

let getUserstatItemRewardData = @(itemId) waitingToShowRewardsArray.findvalue(
  @(itemData) itemData.itemId == itemId)

function removeUserstatItemRewardToShow(itemId) {
  let rewardIdx = waitingToShowRewardsArray.findindex(@(itemData) itemData.itemId == itemId)
  if (rewardIdx == null)
    return

  waitingToShowRewardsArray.remove(rewardIdx)
}

function canGetRewards(onAcceptFn, params) {
  if ((params.rewards?.len() ?? 0) == 0)
    return true

  local waitingWarbondsToReciveAmount = waitingToShowRewardsArray.reduce(
    @(res, a) res + (::ItemsManager.findItemById(a.itemId)?.getWarbondsAmount() ?? 0), 0)
  foreach (itemId, count in params.rewards) {
    let item = ::ItemsManager.findItemById(itemId.tointeger())
    if (item == null)
      continue
    let warbondsAmount = item?.getWarbondsAmount() ?? 0
    if (warbondsAmount == 0)
      continue

    waitingWarbondsToReciveAmount += warbondsAmount * count
    if (!::g_warbonds.checkOverLimit(waitingWarbondsToReciveAmount, onAcceptFn, params))
      return false
  }

  return true
}

addListenersWithoutEnv({
  SignOut = @(_p) waitingToShowRewardsArray.clear()
})

return {
  showRewardWnd
  getUserstatItemRewardData
  removeUserstatItemRewardToShow
  userstatItemsListLocId
  canGetRewards
}