from "%scripts/dagui_library.nut" import *
let { Cost } = require("%scripts/money.nut")
let { getBattleRewardDetails, getBattleRewardTable } = require("%scripts/userLog/userlogUtils.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { isArray } = require("%sqStdLibs/helpers/u.nut")
let { secondsToString } = require("%scripts/time.nut")
let { getRomanNumeralRankByUnitName } = require("%scripts/unit/unitInfo.nut")

let visibleRewards = [
  {
    id = "eventKill"
    locId = "expEventScore/kill"
  }
  {
    id = "eventKillGround"
    getLocId = function(rewardTable) {
      if(!("event" in rewardTable))
        return ""
      let victimUnitCount = rewardTable.event.len()
      let victimShipsCount = rewardTable.event.map(@(e)e?.victimUnitFileName).filter(
        @(u) u != null && u.indexof("ships/") == 0).len()
      if (victimShipsCount == victimUnitCount)
        return "expEventScore/killOnlyShips"
      else if (victimShipsCount == 0)
        return "expEventScore/killOnlyGround"
      return "expEventScore/killGround"
    }
  }
  {
    id = "eventKillHuman"
    locId = "expEventScore/killHuman"
  }
  {
    id = "eventAssist"
    locId = "expEventScore/assist"
  }
  {
    id = "eventSevereDamage"
    locId = "expEventScore/severeDamage"
  }
  {
    id = "eventCriticalHit"
    locId = "expEventScore/criticalHit"
  }
  {
    id = "eventHit"
    locId = "expEventScore/hit"
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
    id = "eventMissileEvade"
    locId = "expEventScore/missileEvade"
  }
  {
    id = "eventShellInterception"
    locId = "expEventScore/shellInterception"
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
    id = "eventReturnSpawnCost"
    locId = "exp_reasons/return_spawn_cost"
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
    .map(function(reward) {
      let rewardTable = getBattleRewardTable(logObj?.container[reward.id])
      let locId = reward?.getLocId(rewardTable) ?? reward.locId
      return rewardTable.__merge({
        name = loc(locId)
        locId
        id = reward.id
      })
    })
    .reduce(function(acc, reward) {
      let rewardDetails = getBattleRewardDetails(reward)
      if (rewardDetails.len() == 0)
        return acc
      let totalRewardWp = rewardDetails
        .reduce(@(total, e) total + (e?.wpNoBonus ?? 0) + (e?.wpPremAcc ?? 0) + (e?.wpBooster ?? 0), 0)
      let totalRewardExp = rewardDetails
        .reduce(@(total, e) total + (e?.expNoBonus ?? 0) + (e?.expPremAcc ?? 0) + (e?.expBooster ?? 0) + (e?.expPremMod ?? 0), 0)
      local count = rewardDetails.len()
      if (reward.id == "unitSessionAward")
        count = secondsToString(rewardDetails.reduce(@(total, e) total + (e?.lifetime ?? 0), 0), false, false)
      else if (reward.id == "eventBattletime")
        count = ""

      return acc.append({  
        battleRewardTooltipId = getTooltipType("USER_LOG_REWARD").getTooltipId(logObj.idx, reward.id)
        count
        wp = Cost(totalRewardWp)
        exp = Cost().setRp(totalRewardExp)
        totalRewardWp
        totalRewardExp
        name = reward.name
        id = reward.id
        battleRewardDetails = rewardDetails
      })
    }, [])

  let wpMissionEndAward = logObj?.container.wpMissionEndAward ?? 0
  if(wpMissionEndAward > 0)
    rewards.append({
      name = loc(logObj.win ? "debriefing/MissionWinReward" : "debriefing/MissionLoseReward")
      wp = Cost(wpMissionEndAward)
      totalRewardWp = wpMissionEndAward
      totalRewardExp = 0
    })

  if (logObj?.container.expSkillBonus.unit) {
    let skillBonusUnits = isArray(logObj.container.expSkillBonus.unit)
      ? logObj.container.expSkillBonus.unit
      : [logObj.container.expSkillBonus.unit]

    if (skillBonusUnits.len() > 0) {
      local totalSkillBonus = 0
      local battleRewardDetails = []

      foreach (bonus in skillBonusUnits) {
        totalSkillBonus += bonus.exp
        battleRewardDetails.append({
          offenderUnit = bonus.unit
          bonusLevel = bonus.bonusLevel
          exp = bonus.exp
        })
      }

      rewards.append({
        battleRewardTooltipId = getTooltipType("USER_LOG_REWARD").getTooltipId(logObj.idx, "expSkillBonus")
        totalRewardWp = 0
        id = "expSkillBonus"
        totalRewardExp = totalSkillBonus
        name = loc("expSkillBonus")
        battleRewardDetails = battleRewardDetails
        exp = Cost().setRp(totalSkillBonus)
        wp = Cost(0)
      })
    }
  }

  let researchPointsUnits = logObj?.container.researchPoints.unit ?? []
  let newNationUnitBonuses = (isArray(researchPointsUnits) ? researchPointsUnits : [researchPointsUnits])
    .filter(@(unit) unit?.newNationBonusExp)
    .map(@(unit) unit.__merge({
      exp = null  
      invUnitRank = getRomanNumeralRankByUnitName(unit?.invUnitName) ?? loc("ui/hyphen")
    }))

  if (newNationUnitBonuses.len() > 0) {
    let exp = newNationUnitBonuses
      .reduce(@(total, unit) total + unit.newNationBonusExp, 0)
    let battleRewardTooltipId = getTooltipType("USER_LOG_REWARD").getTooltipId(logObj.idx, "researchPoints")
    rewards.append({
      id = "nationResearchBonus"
      name = loc("debriefing/nationResearchBonus")
      battleRewardTooltipId
      battleRewardDetails = newNationUnitBonuses
      totalRewardExp = exp
      exp = Cost().setRp(exp)
      totalRewardWp = 0
      wp = Cost(0)
    })
  }

  let allRewardsWp = rewards.reduce(@(total, reward) total + reward.totalRewardWp, 0)
  let allRewardsExp = rewards.filter(@(reward) reward?.id != "nationResearchBonus").reduce(@(total, reward) total + reward.totalRewardExp, 0)
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