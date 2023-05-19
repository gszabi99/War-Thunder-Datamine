//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { Cost } = require("%scripts/money.nut")
//checked for explicitness
#no-root-fallback
#explicit-this
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

let { get_game_mode } = require("mission")
let { setGuiOptionsMode } = require("guiOptions")
let { restart_mission } = require("guiMission")
let { getDecorator } = require("%scripts/customization/decorCache.nut")
let { getLocIdsArray } = require("%scripts/langUtils/localization.nut")

let MISSION_OBJECTIVE = {
  KILLS_AIR           = 0x0001
  KILLS_GROUND        = 0x0002
  KILLS_NAVAL         = 0x0004

  KILLS_AIR_AI        = 0x0010
  KILLS_GROUND_AI     = 0x0020
  KILLS_NAVAL_AI      = 0x0040

  KILLS_TOTAL_AI      = 0x0100

  ZONE_CAPTURE        = 0x0200
  ZONE_BOMBING        = 0x0400
  ALIVE_TIME          = 0x0800

  //masks
  NONE                = 0x0000
  ANY                 = 0xFFFF

  KILLS_ANY           = 0x0077
  KILLS_AIR_OR_TANK   = 0x0033
  KILLS_ANY_AI        = 0x0070
}

let getMissionLocIdsArray = function(missionInfo) {
  local res = []
  let misInfoName = missionInfo?.name ?? ""

  if ((missionInfo?["locNameTeamA"].len() ?? 0) > 0)
    res = getLocIdsArray(missionInfo.locNameTeamA)
  else if ((missionInfo?.locName.len() ?? 0) > 0)
    res = getLocIdsArray(missionInfo.locName)
  else
    res.append($"missions/{misInfoName}")

  if ("".join(res.filter(@(id) id.len() > 1).map(@(id) loc(id))) == "") {
    let misInfoPostfix = missionInfo?.postfix ?? ""
    if (misInfoPostfix != "" && misInfoName.indexof(misInfoPostfix)) {
      let name = misInfoName.slice(0, misInfoName.indexof(misInfoPostfix))
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

let function getRewardValue(dataBlk, misDataBlk, diff, key) {
  let pId = $"{key}EarnedWinDiff{diff}"
  return misDataBlk?[pId] ?? dataBlk?[pId] ?? 0
}

let function addRewardText(rewardTextArray, reward, titleLocId) {
  let isEmptyRewardText = rewardTextArray.findvalue(@(text) text != "") == null
  if (isEmptyRewardText)
    rewardTextArray.append($"{loc(titleLocId)}{loc("ui/colon")}{reward}")
  else
    rewardTextArray.append(reward)

  return rewardTextArray
}

let function getMissionRewardsMarkup(dataBlk, misName, rewardsConfig) {
  let misDataBlk = dataBlk?[misName]
  let rewards = rewardsConfig.map(function(reward) {
    local { locId = "reward", diff = DIFFICULTY_ARCADE, highlighted = false, isComplete = false,
      isAdditionalReward = false, hasRewardImage = true, rewardMoney = null, isBaseReward = false,
      needVerticalAlign = false, slotReward = "" } = reward

    if (rewardMoney == null) {
      let muls = ::get_player_multipliers()
      rewardMoney = Cost(getRewardValue(dataBlk, misDataBlk, diff, "wp") * muls.wpMultiplier,
        getRewardValue(dataBlk, misDataBlk, diff, "gold"), 0,
        getRewardValue(dataBlk, misDataBlk, diff, "xp") * muls.xpMultiplier)
    }

    local rewardTextArray = [::buildRewardText(loc(locId), rewardMoney, highlighted, true, isAdditionalReward)]
    if (slotReward != "")
      rewardTextArray = addRewardText(rewardTextArray, $"{loc("options/crewName")}{slotReward}", locId)

    local resourceImage = null
    local resourceImageSize = "0, 0"
    if (isBaseReward && misDataBlk?.decal != null) {
      let id = misDataBlk.decal
      let decoratorType = ::g_decorator_type.getTypeByResourceType("decal")
      let decorator = getDecorator(id, decoratorType)
      if (decorator != null) {
        resourceImage = decoratorType.getImage(decorator)
        resourceImageSize = decoratorType.getImageSize(decorator)
        rewardTextArray = addRewardText(rewardTextArray, decoratorType.getLocName(id), locId)
        isComplete = decorator.isUnlocked()
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
  return handyman.renderCached("%gui/missions/missionReward.tpl", { rewards = rewards })
}

let getMissionLocName = @(config, key = "locId") "".join(getLocIdsArray(config?[key])
  .map(@(locId) locId.len() == 1 ? locId : loc(locId)))

let function restartCurrentMission() {
  setGuiOptionsMode(::get_options_mode(get_game_mode()))
  restart_mission()
}

return {
  getMissionLocIdsArray
  getMissionRewardsMarkup
  getMissionLocName
  MISSION_OBJECTIVE
  restartCurrentMission
}