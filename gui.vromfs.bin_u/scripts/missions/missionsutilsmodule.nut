local getMissionLocIdsArray = function(missionInfo) {
  local res = []
  local misInfoName = missionInfo?.name ?? ""

  if ((missionInfo?["locNameTeamA"].len() ?? 0) > 0)
    res = ::g_localization.getLocIdsArray(missionInfo, "locNameTeamA")
  else if ((missionInfo?.locName.len() ?? 0) > 0)
    res = ::g_localization.getLocIdsArray(missionInfo, "locName")
  else
    res.append($"missions/{misInfoName}")

  if ("".join(res.filter(@(id) id.len() > 1).map(@(id) ::loc(id))) == "") {
    local misInfoPostfix = missionInfo?.postfix ?? ""
    if (misInfoPostfix != "" && misInfoName.indexof(misInfoPostfix)) {
      local name = misInfoName.slice(0, misInfoName.indexof(misInfoPostfix))
      res.append(
        "[",
        $"missions/{misInfoPostfix}",
        "]",
        " ",
        $"missions/{name}"
      )
    }
    else
      res.append($"missions/{missionInfo?.name ?? ""}")
  }

  return res
}

local function getRewardValue(dataBlk, misDataBlk, diff, key) {
  local pId = $"{key}EarnedWinDiff{diff}"
  return misDataBlk?[pId] ?? dataBlk?[pId] ?? 0
}

local function addRewardText(rewardTextArray, reward, titleLocId) {
  local isEmptyRewardText = rewardTextArray.findvalue(@(text) text != "") == null
  if (isEmptyRewardText)
    rewardTextArray.append($"{::loc(titleLocId)}{::loc("ui/colon")}{reward}")
  else
    rewardTextArray.append(reward)

  return rewardTextArray
}

local function getMissionRewardsMarkup(dataBlk, misName, rewardsConfig) {
  local misDataBlk = dataBlk?[misName]
  local rewards = rewardsConfig.map(function(reward) {
    local { locId = "reward", diff = ::DIFFICULTY_ARCADE, highlighted = false, isComplete = false,
      isAdditionalReward = false, hasRewardImage = true, rewardMoney = null, isBaseReward = false,
      needVerticalAlign = false, slotReward = "" } = reward

    if (rewardMoney == null) {
      local muls = ::get_player_multipliers()
      rewardMoney = ::Cost(getRewardValue(dataBlk, misDataBlk, diff, "wp") * muls.wpMultiplier,
        getRewardValue(dataBlk, misDataBlk, diff, "gold"), 0,
        getRewardValue(dataBlk, misDataBlk, diff, "xp") * muls.xpMultiplier)
    }

    local rewardTextArray = [::buildRewardText(::loc(locId), rewardMoney, highlighted, true, isAdditionalReward)]
    if (slotReward != "")
      rewardTextArray = addRewardText(rewardTextArray, $"{::loc("options/crewName")}{slotReward}", locId)

    local resourceImage = null
    local resourceImageSize = "0, 0"
    if (isBaseReward && misDataBlk?.decal != null) {
      local id = misDataBlk.decal
      local decoratorType = ::g_decorator_type.getTypeByResourceType("decal")
      local decorator = ::g_decorator.getDecorator(id, decoratorType)
      if (decorator != null) {
        resourceImage = decoratorType.getImage(decorator)
        resourceImageSize = decoratorType.getImageSize(decorator)
        rewardTextArray = addRewardText(rewardTextArray, decoratorType.getLocName(id), locId)
      }
    }

    return {
      rewardText = ", ".join(rewardTextArray, true)
      rewardImage = hasRewardImage ? ::g_difficulty.getDifficultyByDiffCode(diff).icon : null
      isComplete
      needVerticalAlign
      resourceImage
      resourceImageSize
    }
  }).filter(@(reward) reward.rewardText != "")
  return ::handyman.renderCached("gui/missions/missionReward", { rewards = rewards })
}


return {
  getMissionLocIdsArray
  getMissionRewardsMarkup
}