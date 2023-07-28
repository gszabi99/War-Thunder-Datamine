from "%scripts/dagui_library.nut" import *
let { Cost } = require("%scripts/money.nut")
let { getBattleRewardDetails } = require("%scripts/userLog/userlogUtils.nut")
let { USER_LOG_REWARD } = require("%scripts/utils/genericTooltipTypes.nut")

let visibleRewards = [
  {
    id = "eventKill"
    locId = "expEventScore/kill"
  }
  {
    id = "eventKillGround"
    locId = "expEventScore/killGround"
  }
  {
    id = "eventAssist"
    locId = "expEventScore/assist"
  }
  {
    id = "eventCriticalHit"
    locId = "expEventScore/criticalHit"
  }
  {
    id = "eventHit"
    locId = "expEventScore/kill"
  }
  {
    id = "eventTakeoff"
    locId = "debriefing/Takeoffs"
  }
  {
    id = "eventLanding"
    locId = "debriefing/Landings"
  }
  {
    id = "eventCaptureZone"
    locId = "expEventScore/captureZone"
  }
  {
    id = "eventDestroyZone"
    locId = "expEventScore/destroyZone"
  }
  {
    id = "eventDamageZone"
    locId = "expEventScore/damageZone"
  }
  {
    id = "eventScout"
    locId = "expEventScore/scout"
  }
  {
    id = "eventScoutCriticalHit"
    locId = "expEventScore/scoutCriticalHit"
  }
  {
    id = "eventScoutKill"
    locId = "expEventScore/scoutKillAny"
  }
  {
    id = "eventTimedAward"
    locId = "exp_reasons/timed_award"
  }
  {
    id = "eventStreak"
    locId = "profile/awards"
  }
  {
    id = "eventBattletime"
    locId = "debriefing/activityTime"
  }
  {
    id = "unitSessionAward"
    locId = "debriefing/timePlayed"
  }
]

return function(logObj) {
  let rewards = visibleRewards
    .map(@(reward) logObj.container?[reward.id]?.__merge({
      name = loc(reward.locId)
      locId = reward.locId
      id = reward.id
    }))
    .reduce(function(acc, reward) {
      let rewardDetails = getBattleRewardDetails(reward)
      if (rewardDetails.len() == 0)
        return acc
      let totalRewardWp = rewardDetails
        .reduce(@(total, e) total + (e?.wpNoBonus ?? 0) + (e?.wpPremAcc ?? 0) + (e?.wpBooster ?? 0), 0)
      let totalRewardExp = rewardDetails
        .reduce(@(total, e) total + (e?.expNoBonus ?? 0)  + (e?.expPremAcc ?? 0) + (e?.expBooster ?? 0) + (e?.expPremMod ?? 0), 0)

      return acc.append({  // -unwanted-modification
        battleRewardTooltipId = USER_LOG_REWARD.getTooltipId(logObj.idx, reward.id)
        count = rewardDetails.len()
        wp = Cost(totalRewardWp)
        exp = Cost().setRp(totalRewardExp)
        totalRewardWp
        totalRewardExp
        name = reward.name
        id = reward.id
        battleRewardDetails = rewardDetails
      })
    }, [])

  let allRewardsWp = rewards.reduce(@(total, reward) total + reward.totalRewardWp, 0)
  let allRewardsExp = rewards.reduce(@(total, reward) total + reward.totalRewardExp, 0)
  let { wpEarned = 0, xpEarned = 0 } = logObj
  let totalRewardWp = wpEarned - allRewardsWp
  let totalRewardExp = xpEarned - allRewardsExp
  if (rewards.len() > 0 && (totalRewardWp > 0 || totalRewardExp > 0)) {
    rewards.append({
      name = loc("userlog/other_awards")
      wp = Cost(totalRewardWp)
      exp = Cost().setRp(totalRewardExp)
      totalRewardWp
      totalRewardExp
    })
  }

  return rewards
}