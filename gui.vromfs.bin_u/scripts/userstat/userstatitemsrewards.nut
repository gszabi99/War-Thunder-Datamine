local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")

local userstatRewardTitleLocId = "battlePass/rewardsTitle"
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
      waitingToShowRewardsArray.append({ itemId })
    else {
      rewardsToShow.append({ itemDefId = itemId
        item = itemId
        count = count
      })
      firstItemId = firstItemId ?? itemId
    }
  }

  if (firstItemId != null)
    ::gui_start_open_trophy({ [firstItemId] = rewardsToShow,
      rewardTitle = ::loc(userstatRewardTitleLocId),
      rewardListLocId = userstatItemsListLocId
    })
}

local getUserstatItemRewardData = @(itemId) waitingToShowRewardsArray.findvalue(
  @(itemData) itemData.itemId == itemId)

local function removeUserstatItemRewardToShow(itemId) {
  local rewardIdx = waitingToShowRewardsArray.findindex(@(itemData) itemData.itemId == itemId)
  if (rewardIdx == null)
    return

  waitingToShowRewardsArray.remove(rewardIdx)
}

local function canGetRewards(onAcceptFn, params) {
  if ((params.rewards?.len() ?? 0) == 0)
    return true

  local waitingWarbondsToReciveAmount = waitingToShowRewardsArray.reduce(
    @(res, a) res + (::ItemsManager.findItemById(a.itemId)?.getWarbondsAmount() ?? 0), 0)
  foreach (itemId, count in params.rewards) {
    local item = ::ItemsManager.findItemById(itemId.tointeger())
    if (item == null)
      continue
    local warbondsAmount = item?.getWarbondsAmount() ?? 0
    if (warbondsAmount == 0)
      continue

    waitingWarbondsToReciveAmount += warbondsAmount * count
    if (!::g_warbonds.checkOverLimit(waitingWarbondsToReciveAmount, onAcceptFn, params))
      return false
  }

  return true
}

addListenersWithoutEnv({
  SignOut = @(p) waitingToShowRewardsArray.clear()
})

return {
  showRewardWnd
  getUserstatItemRewardData
  removeUserstatItemRewardToShow
  userstatRewardTitleLocId
  userstatItemsListLocId
  canGetRewards
}