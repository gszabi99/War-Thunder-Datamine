local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")

local userstatRewardTitleLocId = ""
//


local userstatItemsListLocId = "mainmenu/rewardsList"

local waitingToShowRewardsArray = persist("waitingToShowRewardsArray", @() [])

local function showRewardWnd(rewards) {
  if ((rewards?.len() ?? 0) == 0)
    return

  local rewardsToShow = []
  local firstItemId = null
  foreach (itemId, count in rewards) {
    itemId = itemId.tointeger()
    local item = ::ItemsManager.findItemById(itemId)
    if (item == null)
      continue
    if (item.shouldAutoConsume) //show recived rewards after auto consume
      waitingToShowRewardsArray.append(itemId)
    else {
      rewardsToShow.append({ itemDefId = itemId, item = itemId, count = count })
      firstItemId = firstItemId ?? itemId
    }
  }

  if (firstItemId != null)
    ::gui_start_open_trophy({ [firstItemId] = rewardsToShow,
      rewardTitle = ::loc(userstatRewardTitleLocId),
      rewardListLocId = userstatItemsListLocId
    })
}

local isUserstatItemRewards = @(itemId) waitingToShowRewardsArray.contains(itemId)

local function removeUserstatItemRewardToShow(itemId) {
  local rewardIdx = waitingToShowRewardsArray.findindex(@(item) item == itemId)
  if (rewardIdx == null)
    return

  waitingToShowRewardsArray.remove(rewardIdx)
}

local function canGetRewards(rewards) {
  if ((rewards?.len() ?? 0) == 0)
    return true

  foreach (itemId, count in rewards) {
    local item = ::ItemsManager.findItemById(itemId.tointeger())
    if (item == null)
      continue
    local warbondsAmount = item?.getWarbondsAmount() ?? 0
    if (warbondsAmount > 0
        && ::g_warbonds.isOverLimitForExchangeCoupon(warbondsAmount * count))
      return false
  }

  return true
}

addListenersWithoutEnv({
  SignOut = @(p) waitingToShowRewardsArray.clear()
})

return {
  showRewardWnd
  isUserstatItemRewards
  removeUserstatItemRewardToShow
  userstatRewardTitleLocId
  userstatItemsListLocId
  canGetRewards
}