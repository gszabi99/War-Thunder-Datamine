let { warbondsShopLevelByStages, seasonLevel } = require("%scripts/battlePass/seasonState.nut")
let { basicUnlock, basicUnlockId, premiumUnlock, premiumUnlockId, hasBattlePass
} = require("%scripts/battlePass/unlocksRewardsState.nut")
let { curSeasonChallengesByStage } = require("%scripts/battlePass/challenges.nut")
let { getStageByIndex } = require("%scripts/unlocks/userstatUnlocksState.nut")
let { BATTLE_PASS_CHALLENGE, ITEM } = require("%scripts/utils/genericTooltipTypes.nut")
let globalCallbacks = require("%sqDagui/globalCallbacks/globalCallbacks.nut")

const COUNT_OF_VISIBLE_INCOMPLETED_LOOP_STAGES = 5

let overrideStagesIcon = ::Computed(@() basicUnlock.value?.meta.overrideStageIcon ?? {})
let doubleWidthStagesIcon = ::Computed(@() basicUnlock.value?.meta.doubleWidthStageIcon ?? [])

let getStageStatus = @(stageIdx) (stageIdx + 1) < seasonLevel.value ? "past"
  : (stageIdx + 1) == seasonLevel.value ? "current"
  : "future"

let function getPrizeStatus(unlock, stageIdx) {
  let stage = stageIdx + 1
  let lastRewardedStage = unlock.lastRewardedStage
  if (stage <= lastRewardedStage)
    return "received"

  if (unlock.name == premiumUnlockId.value && !hasBattlePass.value)
    return "notAvailable"

  return unlock.stage >= stage ? "available"
   : "notAvailable"
}

let function addStageConfigWithRewardToList(stagesArray, unlock, stageIdx, stageChallenge = null) {
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
      isFree = unlockId == basicUnlockId.value
      stageStatus = getStageStatus(stageIdx)
      prizeStatus = isChallengeStage && stage <= seasonLevel.value ? "received"
        : getPrizeStatus(unlock, stageIdx)
      warbondsShopLevel = warbondsShopLevelByStages.value?[stage.tostring()]
      stageChallenge =stageChallenge
    }))
  }
}

let seasonStages = ::Computed(function() {
  let stagesCount = max(basicUnlock.value?.stages?.len() ?? 0,
    premiumUnlock.value?.stages?.len() ?? 0,
    seasonLevel.value + COUNT_OF_VISIBLE_INCOMPLETED_LOOP_STAGES)
  let res = []
  for(local i=0; i < stagesCount; i++) {
    let stageChallenge = curSeasonChallengesByStage.value?[i+1]
    addStageConfigWithRewardToList(res, basicUnlock.value, i, stageChallenge)
    addStageConfigWithRewardToList(res, premiumUnlock.value, i)
  }
  return res
})

let function getPreviewBtnView(item) {
  if (!item?.canPreview())
    return null

  let gcb = globalCallbacks.ITEM_PREVIEW
  return {
    image = "#ui/gameuiskin#btn_preview.svg"
    tooltip = "#mainmenu/btnPreview"
    funcName = gcb.cbName
    actionParamsMarkup = gcb.getParamsMarkup({ itemId = item.id })
  }
}

let function getChallengeTooltipId(stage, stageChallenge) {
  if (stageChallenge == null)
    return null

  let challenge = curSeasonChallengesByStage.value?[stage]
  if (challenge == null)
    return null

  return BATTLE_PASS_CHALLENGE.getTooltipId(challenge.id)
}

let function getStageViewData(stageData, idxOnPage) {
  let { unlockId, stageStatus, prizeStatus, stage, isFree, rewards = null, warbondsShopLevel, stageChallenge } = stageData
  let overrideStageIcon = overrideStagesIcon.value?[stage.tostring()]
  let itemId = rewards?.keys()[0]
  let item = itemId != null ? ::ItemsManager.findItemById(itemId.tointeger()) : null
  let currentWarbond = ::g_warbonds.getCurrentWarbond()
  let isChallengeStage = stageChallenge != null
  return {
    holderId = unlockId
    rewardId = itemId
    stageStatus = stageStatus
    prizeStatus = prizeStatus
    doubleWidthStageIcon = doubleWidthStagesIcon.value.findvalue(@(v) v == stage) != null
    stage = stage
    previewButton = getPreviewBtnView(item)
    isFree = isFree
    isFirst = idxOnPage == 0
    warbondShopLevelImage = currentWarbond != null && warbondsShopLevel != null
      ? ::g_warbonds_view.getLevelItemMarkUp(currentWarbond, warbondsShopLevel, "0", {
        hasOverlayIcon = false })
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
    stageIcon = overrideStageIcon ?? (isChallengeStage ? "#ui/gameuiskin#item_challenge.png" : null)
    stageTooltipId = isChallengeStage ? getChallengeTooltipId(stage, stageChallenge)
      : itemId != null && overrideStageIcon != null ? ITEM.getTooltipId(itemId.tointeger())
      : null
  }
}

return {
  seasonStages
  getStageViewData
  doubleWidthStagesIcon
}
