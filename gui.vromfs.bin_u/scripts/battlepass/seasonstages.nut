import "%scripts/warbonds/warbondsView.nut" as g_warbonds_view
from "%scripts/battlePass/seasonState.nut" import warbondsShopLevelByStages, seasonLevel, getBPStageByShopLevel
from "%scripts/battlePass/unlocksRewardsState.nut" import basicUnlock, basicUnlockId, premiumUnlock, premiumUnlockId, hasBattlePass, basicUnlockMeta
from "%scripts/battlePass/challenges.nut" import curSeasonChallengesByStage
from "%scripts/unlocks/userstatUnlocksState.nut" import getStageByIndex
from "%scripts/utils/genericTooltipTypes.nut" import getTooltipType
from "%scripts/sqDagui/globalCallbacks/globalCallbacks.nut" import getGcbName, getGcbParamsMarkup
from "%scripts/items/itemsManagerModule.nut" import findItemById
from "%scripts/warbonds/warbondsManager.nut" import getCurrentWarbond
from "%scripts/dagui_library.nut" import *

const COUNT_OF_VISIBLE_INCOMPLETED_LOOP_STAGES = 10

let overrideStagesIcon = Computed(@() basicUnlockMeta.get()?.overrideStageIcon ?? {})
let doubleWidthStagesIcon = Computed(@() basicUnlockMeta.get()?.doubleWidthStageIcon ?? [])

let getStageStatus = @(stageIdx) (stageIdx + 1) < seasonLevel.get() ? "past"
  : (stageIdx + 1) == seasonLevel.get() ? "current"
  : "future"

function getPrizeStatus(unlock, stageIdx) { 
  let stage = stageIdx + 1
  let lastRewardedStage = unlock.lastRewardedStage
  if (stage <= lastRewardedStage)
    return "received"

  if (unlock.name == premiumUnlockId.get() && !hasBattlePass.get())
    return "notAvailable"

  return unlock.stage >= stage ? "available"
   : "notAvailable"
}

function addStageConfigWithRewardToList(stagesArray, unlock, stageIdx, stageChallenge = null) { 
  if (unlock == null)
    return
  let curStage = getStageByIndex(unlock, stageIdx)
  let unlockId = unlock?.name
  let isChallengeStage = stageChallenge != null
  if (((curStage?.rewards.len() ?? 0) > 0) || isChallengeStage) {
    let stage = stageIdx + 1
    stagesArray.append(curStage.__merge({
      unlockId = unlockId
      stage = stage
      isFree = unlockId == basicUnlockId.get()
      stageStatus = getStageStatus(stageIdx)
      prizeStatus = isChallengeStage && stage <= seasonLevel.get() ? "received"
        : getPrizeStatus(unlock, stageIdx)
      warbondsShopLevel = warbondsShopLevelByStages.get()?[stage.tostring()]
      stageChallenge = stageChallenge
    }))
  }
}

let seasonStages = Computed(function() {
  let stagesCount = max(basicUnlock.get()?.stages.len() ?? 0,
    premiumUnlock.get()?.stages.len() ?? 0,
    seasonLevel.get() + COUNT_OF_VISIBLE_INCOMPLETED_LOOP_STAGES)
  let res = []
  for (local i = 0; i < stagesCount; i++) {
    let stageChallenge = curSeasonChallengesByStage.get()?[i + 1]
    addStageConfigWithRewardToList(res, basicUnlock.get(), i, stageChallenge)
    addStageConfigWithRewardToList(res, premiumUnlock.get(), i)
  }
  return res
})

function getPreviewBtnView(item) {
  if (!item?.canPreview())
    return null

  return {
    image = "#ui/gameuiskin#btn_preview.svg"
    tooltip = "#mainmenu/btnPreview"
    funcName = getGcbName("ITEM_PREVIEW")
    actionParamsMarkup = getGcbParamsMarkup({ itemId = item.id })
  }
}

function getChallengeTooltipId(stage, stageChallenge) {
  if (stageChallenge == null)
    return null

  let challenge = curSeasonChallengesByStage.get()?[stage]
  if (challenge == null)
    return null

  return getTooltipType("BATTLE_PASS_CHALLENGE").getTooltipId(challenge.id)
}

function getStageViewData(stageData, idxOnPage) {
  let { unlockId, stageStatus, prizeStatus, stage, isFree, rewards = null, warbondsShopLevel, stageChallenge } = stageData
  let overrideStageIcon = overrideStagesIcon.get()?[stage.tostring()]
  let itemId = rewards?.keys()[0]
  let item = itemId != null ? findItemById(itemId.tointeger()) : null
  let currentWarbond = getCurrentWarbond()
  let isChallengeStage = stageChallenge != null
  return {
    holderId = unlockId
    rewardId = itemId
    stageStatus = stageStatus
    prizeStatus = prizeStatus
    doubleWidthStageIcon = doubleWidthStagesIcon.get().findvalue(@(v) v == stage) != null
    stage = stage
    previewButton = getPreviewBtnView(item)
    isFree = isFree
    isFirst = idxOnPage == 0
    warbondShopLevelImage = currentWarbond != null && (warbondsShopLevel ?? 0) > 0
      ? g_warbonds_view.getLevelItemMarkUp(currentWarbond, warbondsShopLevel,
          getBPStageByShopLevel, "0", { hasOverlayIcon = false })
      : ""
    items = overrideStageIcon == null && itemId != null ? [item?.getViewData({
        enableBackground = false
        showAction = false
        showPrice = false
        contentIcon = false
        hasFocusBorder = false
        hasTimer = false
        showRarity = false
        count = rewards[itemId]
      })]
    : null
    stageIcon = overrideStageIcon ?? (isChallengeStage ? "#ui/gameuiskin#item_challenge" : null)
    stageTooltipId = isChallengeStage ? getChallengeTooltipId(stage, stageChallenge)
      : itemId != null && overrideStageIcon != null ? getTooltipType("ITEM").getTooltipId(itemId.tointeger())
      : null
  }
}

return freeze({
  seasonStages
  getStageViewData
  doubleWidthStagesIcon
})
