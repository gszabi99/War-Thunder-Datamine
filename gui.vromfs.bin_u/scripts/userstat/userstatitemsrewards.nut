from "%scripts/dagui_library.nut" import *

let { eventbus_send } = require("eventbus")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { userstatUnlocks, receiveUnlockRewards, waitingToShowRewardsArray
} = require("%scripts/userstat/userstat.nut")
let { activeUnlocks, getStageByIndex } = require("%scripts/unlocks/userstatUnlocksState.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { unclaimedUnlocks } = require("%scripts/unlocks/regionalUnlocks.nut")
let { checkWarbondsOverLimit } = require("%scripts/warbonds/warbondsManager.nut")
let { findItemById } = require("%scripts/items/itemsManagerModule.nut")


let userstatItemsListLocId = "mainmenu/rewardsList"

let rewardsInProgress = Watched({})
let servUnlockProgress = Computed(@() userstatUnlocks.get()?.unlocks ?? {})


function showRewardWnd(params) {
  let { rewards, rewardTitleLocId } = params
  if ((rewards?.len() ?? 0) == 0)
    return

  let rewardsToShow = []
  local firstItemId = null
  foreach (itemIdSrc, count in rewards) {
    let itemId = itemIdSrc.tointeger()
    let item = findItemById(itemId)
    if (item == null)
      continue
    if (item.shouldAutoConsume) 
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
      [firstItemId.tostring()] = rewardsToShow,
      rewardTitle = loc(rewardTitleLocId),
      rewardListLocId = userstatItemsListLocId
    })
}

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
    @(res, a) res + (findItemById(a.itemId)?.getWarbondsAmount() ?? 0), 0)
  foreach (itemId, count in params.rewards) {
    let item = findItemById(itemId.tointeger())
    if (item == null)
      continue
    let warbondsAmount = item?.getWarbondsAmount() ?? 0
    if (warbondsAmount == 0)
      continue

    waitingWarbondsToReciveAmount += warbondsAmount * count
    if (!checkWarbondsOverLimit(waitingWarbondsToReciveAmount, onAcceptFn, params))
      return false
  }

  return true
}


function sendReceiveRewardRequest(params) {
  let { stage, unlockName, taskOptions, needShowRewardWnd } = params
  let receiveRewardsCallback = function(res) {
    log($"Userstat: receive reward {unlockName}, stage: {stage}, results: {res}")
    rewardsInProgress.mutate(@(val) val.$rawdelete(unlockName))
  }
  rewardsInProgress.mutate(@(val) val[unlockName] <- stage)
  receiveUnlockRewards(unlockName, stage, function(_res) {
    receiveRewardsCallback("success")
    if (needShowRewardWnd)
      showRewardWnd(params)
  }, receiveRewardsCallback, taskOptions)
}


let RECEIVE_REWARD_DEFAULT_OPTIONS = {
  showProgressBox = true
}

function receiveRewards(unlockName, params = {}) {
  if (!unlockName || unlockName in rewardsInProgress.get())
    return

  let { needShowRewardWnd = true, rewardTitleLocId = "rewardReceived" } = params
  let taskOptions = RECEIVE_REWARD_DEFAULT_OPTIONS.__merge(params?.taskOptions ?? {})
  let progressData = servUnlockProgress.get()?[unlockName]
  let stage = progressData?.stage ?? 0
  let lastReward = progressData?.lastRewardedStage ?? 0
  params = {
    rewards = getStageByIndex(activeUnlocks.get()?[unlockName], stage - 1)?.rewards,
    stage, unlockName, taskOptions, needShowRewardWnd, rewardTitleLocId
  }
  if (lastReward < stage && canGetRewards(sendReceiveRewardRequest,
      params.__merge({ needShowRewardWnd = false })))
    sendReceiveRewardRequest(params)
}


function claimRegionalUnlockRewards() {
  let unlocks = unclaimedUnlocks.get().filter(@(u) !(u?.manualOpen ?? false))
  if (unlocks.len() == 0)
    return

  let handler = handlersManager.getActiveBaseHandler()
  let handlerClass = handler?.getclass()
  if (!handler?.isValid() || handlerClass != gui_handlers.MainMenu)
    return

  let unlockId = unlocks.findindex(@(_) true)
  if (unlockId != null)
    handler.doWhenActive(@() receiveRewards(unlockId))
}

unclaimedUnlocks.subscribe(@(_) claimRegionalUnlockRewards())

addListenersWithoutEnv({
  SignOut = @(_p) waitingToShowRewardsArray.clear()
})

return {
  showRewardWnd
  removeUserstatItemRewardToShow
  userstatItemsListLocId
  canGetRewards
  receiveRewards
  rewardsInProgress
  claimRegionalUnlockRewards
}
