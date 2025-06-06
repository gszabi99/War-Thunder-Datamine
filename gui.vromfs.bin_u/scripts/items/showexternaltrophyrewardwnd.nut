from "%scripts/dagui_library.nut" import *

let { get_time_msec } = require("dagor.time")
let { removeUserstatItemRewardToShow } = require("%scripts/userstat/userstatItemsRewards.nut")
let { broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { resetTimeout } = require("dagor.workcycle")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { getUserLogsList } = require("%scripts/userLog/userlogUtils.nut")



const MAX_DELAYED_TIME_SEC = 10
const PROGRESS_BOX_BUTTONS_DELAY_SEC = 15

let delayedTrophies = persist("delayedTrophies", @() [])

local currentProgressBox = null

function showWaitingProgressBox() {
  if (currentProgressBox?.isValid() ?? false)
    return

  let guiScene = get_cur_gui_scene()
  if (guiScene == null)
    return

  currentProgressBox = scene_msg_box(
    "wait_trophy_rewards_progress_box", guiScene, loc("charServer/purchase0"),
    [["cancel", @() null]], "cancel",
    {
      waitAnim = true
      delayedButtons = PROGRESS_BOX_BUTTONS_DELAY_SEC
    })
}

function hideWaitingProgressBox() {
  if (!(currentProgressBox?.isValid() ?? false))
    return

  let guiScene = currentProgressBox.getScene()
  guiScene.destroyElement(currentProgressBox)
  broadcastEvent("ModalWndDestroy")
  currentProgressBox = null
}

function showTrophyWnd(config) {
  hideWaitingProgressBox()
  let { trophyItemDefId, expectedPrizes, rewardWndConfig = {}, receivedPrizes = null } = config

  broadcastEvent("openChestWndOrTrophy", {
    rewardWndConfig, chestId = trophyItemDefId, receivedPrizes, expectedPrizes
  })
  removeUserstatItemRewardToShow(trophyItemDefId)
}

function checkRecivedAllPrizes(config) {
  let { trophyItemDefId, expectedPrizes, time = -1, } = config
  let receivedPrizes = "receivedPrizes" in config ? clone config.receivedPrizes : []
  let notReceivedPrizes = []
  let userLogs = getUserLogsList({
    show = [ EULT_OPEN_TROPHY ]
    needStackItems = false
    checkFunc = @(userLog) expectedPrizes.findvalue(
      @(p) p.itemId == (p.isInternalTrophy ? userLog?.body.trophyItemId : userLog?.body.itemId)
    ) != null
  })
  foreach (prize in expectedPrizes) {
    if (!prize.needCollectRewards) {
      receivedPrizes.append(prize)
      continue
    }

    let prizeUserlogs = userLogs.filter(@(userLog) prize.itemId
      == (prize.isInternalTrophy ? userLog?.trophyItemId : userLog?.itemId))
    if (prizeUserlogs.len() == 0) {
      notReceivedPrizes.append(prize)
      continue
    }

    foreach (userLog in prizeUserlogs)
      receivedPrizes.append(userLog.__merge({ itemDefId = trophyItemDefId }))
  }

  if (time != -1 && (time + ((MAX_DELAYED_TIME_SEC - 1) * 1000) < get_time_msec())) {
    receivedPrizes.extend(notReceivedPrizes)
    notReceivedPrizes.clear()
  }

  config = config.__merge({ expectedPrizes = notReceivedPrizes, receivedPrizes })
  if (notReceivedPrizes.len() > 0)
    return config

  config.needShowWnd <- true
  return config
}

function checkShowExternalTrophyRewardWnd() {
  if (!isInMenu.get())
    return

  foreach (idx, trophyConfig in delayedTrophies) {
    let config = checkRecivedAllPrizes(trophyConfig)
    if (config?.needShowWnd ?? false) {
      delayedTrophies.remove(idx)
      showTrophyWnd(config)
      return
    }

    delayedTrophies[idx] = config
  }
}

function showExternalTrophyRewardWnd(config) {
  if (config.expectedPrizes.findvalue(@(p) p.needCollectRewards) == null) {
    showTrophyWnd(config)
    return
  }
  config = checkRecivedAllPrizes(config)
  let {needShowWnd = false, showCollectRewardsWaitBox = true} = config
  if (needShowWnd) {
    showTrophyWnd(config)
    return
  }

  delayedTrophies.append(config.__merge({ time = get_time_msec() }))
  if (showCollectRewardsWaitBox)
    showWaitingProgressBox()
  resetTimeout(MAX_DELAYED_TIME_SEC, checkShowExternalTrophyRewardWnd)
}

addListenersWithoutEnv({
  SignOut = @(_p) delayedTrophies.clear()
})

return {
  showExternalTrophyRewardWnd
  checkShowExternalTrophyRewardWnd
}