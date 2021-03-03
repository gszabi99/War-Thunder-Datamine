local { warbondsShopLevelByStages, hasBattlePass, seasonLevel
} = require("scripts/battlePass/seasonState.nut")
local { basicUnlock, basicUnlockId, premiumUnlock, premiumUnlockId
} = require("scripts/battlePass/unlocksRewardsState.nut")
local { curSeasonChallengesByStage } = require("scripts/battlePass/challenges.nut")
local { getStageByIndex } = require("scripts/unlocks/userstatUnlocksState.nut")
local { BATTLE_PASS_CHALLENGE } = require("scripts/utils/genericTooltipTypes.nut")

const COUNT_OF_VISIBLE_INCOMPLETED_LOOP_STAGES = 5

local overrideStagesIcon = ::Computed(@() basicUnlock.value?.meta.overrideStageIcon ?? {})

local getStageStatus = @(stageIdx) (stageIdx + 1) < seasonLevel.value ? "past"
  : (stageIdx + 1) == seasonLevel.value ? "current"
  : "future"

local function getPrizeStatus(unlock, stageIdx) {
  local stage = stageIdx + 1
  local lastRewardedStage = unlock.lastRewardedStage
  if (stage <= lastRewardedStage)
    return "received"

  if (unlock.name == premiumUnlockId.value && !hasBattlePass.value)
    return "notAvailable"

  return unlock.stage >= stage ? "available"
   : "notAvailable"
}

local function addStageConfigWithRewardToList(stagesArray, unlock, stageIdx, stageChallenge = null) {
  if (unlock == null)
    return
  local curStage = getStageByIndex(unlock, stageIdx)
  local unlockId = unlock?.name
  local isChallengeStage = stageChallenge != null
  if (((curStage?.rewards.len() ?? 0) > 0) || isChallengeStage) {
    local stage = stageIdx + 1
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

local seasonStages = ::Computed(function() {
  local stagesCount = ::max(basicUnlock.value?.stages?.len() ?? 0,
    premiumUnlock.value?.stages?.len() ?? 0,
    seasonLevel.value + COUNT_OF_VISIBLE_INCOMPLETED_LOOP_STAGES)
  local res = []
  for(local i=0; i < stagesCount; i++) {
    local stageChallenge = curSeasonChallengesByStage.value?[i+1]
    addStageConfigWithRewardToList(res, basicUnlock.value, i, stageChallenge)
    addStageConfigWithRewardToList(res, premiumUnlock.value, i)
  }
  return res
})

local function getChallengeTooltipId(stage, stageChallenge) {
  if (stageChallenge == null)
    return null

  local challenge = curSeasonChallengesByStage.value?[stage]
  if (challenge == null)
    return null

  return BATTLE_PASS_CHALLENGE.getTooltipId(challenge.id)
}

local function getStageViewData(stageData, idxOnPage) {
  local { unlockId, stageStatus, prizeStatus, stage, isFree, rewards = null, warbondsShopLevel, stageChallenge } = stageData
  local overrideStageIcon = overrideStagesIcon.value?[stage.tostring()]
  local itemId = rewards?.keys()[0]
  local currentWarbond = ::g_warbonds.getCurrentWarbond()
  local isChallengeStage = stageChallenge != null
  return {
    holderId = unlockId
    rewardId = itemId
    stageStatus = stageStatus
    prizeStatus = prizeStatus
    stage = stage
    isFree = isFree
    isFirst = idxOnPage == 0
    warbondShopLevelImage = currentWarbond != null && warbondsShopLevel != null
      ? ::g_warbonds_view.getLevelItemMarkUp(currentWarbond, warbondsShopLevel, "0", {
        hasOverlayIcon = false })
      : ""
    items = itemId != null ? [::ItemsManager.findItemById(itemId.tointeger())?.getViewData({
        overrideLayeredImage = overrideStageIcon != null ? ::LayersIcon.getIconData(null, overrideStageIcon) : null
        enableBackground = false
        showAction = false
        showPrice = false
        contentIcon = false
        hasFocusBorder = false
        showRarity = false
        count = rewards[itemId]
      })]
    : null
    stageIcon = overrideStageIcon ?? (isChallengeStage ? "#ui/gameuiskin#item_challenge" : null)
    stageTooltipId = isChallengeStage
      ? getChallengeTooltipId(stage, stageChallenge)
      : null
  }
}

return {
  seasonStages
  getStageViewData
}
