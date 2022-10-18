from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { get_blk_value_by_path } = require("%sqStdLibs/helpers/datablockUtils.nut")
let { unixtime_to_utc_timetbl } = require("dagor.time")
let time = require("%scripts/time.nut")

global enum CLAN_SEASON_MEDAL_TYPE
{
  PLACE
  TOP
  RATING
  UNKNOWN
}

::g_clan_seasons <- {
  rewardsBlk = null //cache of ::get_clan_rewards_blk()
  _inited = false


  function init()
  {
    if (_inited)
      return

    _inited = true
    ::subscribe_handler(this)
  }


  function getRewardsBlk()
  {
    if (!rewardsBlk)
      rewardsBlk = ::get_clan_rewards_blk()

    return rewardsBlk
  }


  //invalidate cache
  function onEventLoginComplete(_p) { rewardsBlk = null }
  function onEventSignOut(_p) { rewardsBlk = null }


  function isEnabled()
  {
    if (!hasFeature("ClanSeasons_3_0"))
      return false
    return getTblValue("seasonsEnable", getRewardsBlk(), true)
  }


  function getTopPlayersRewarded()
  {
    let blk = getRewardsBlk()
    return get_blk_value_by_path(blk, "reward/topPlayersRewarded", 10)
  }


  function hasPrizePlacesRewards(difficulty)
  {
    let subRewards = ::g_clan_seasons.getRewardsBlk()?.reward.subRewards
    if (!subRewards)
      return false

    let path = $"{difficulty.egdLowercaseName}/era5"
    let subRewardsCount = subRewards.blockCount()
    for (local i = 0; i < subRewardsCount; i++)
      if (get_blk_value_by_path(subRewards.getBlock(i), path))
        return true

    return false
  }


  /**
   * Return array of rewards for places from 1 to @till.
   * Retrun empty array if can't get any rewards.
   * @till - should pe greater than 1 and less than result of
   * @difficulty - item from ::g_difficulty
   */
  function getFirstPrizePlacesRewards(till, difficulty)
  {
    let rewards = []
    let blk = getRewardsBlk()
    local currentPlace = 0
    let subRewards = blk?.reward.subRewards
    if (!subRewards)
      return rewards

    let subRewardsCount = subRewards.blockCount()
    for (local i = 0; i < subRewardsCount; i++)
    {
      let rewardBlock = subRewards.getBlock(i)
      let rewardsData = get_blk_value_by_path(rewardBlock, difficulty.egdLowercaseName + "/era5")
      if (!rewardsData)
        continue
      let maxPlaceForBlock = getMaxPlaceForBlock(rewardBlock.getBlockName())
      if (isLeprRewards(rewardsData))
      {
        local place = currentPlace
        for (; place < min(maxPlaceForBlock, till); ++place)
        {
          let gold = getGoldRewardLerp(rewardsData, place + 1, currentPlace)
          let regalia = getRagalia(rewardsData, place + 1)
          let hasAnyRewards = gold > 0 || getRegaliaPrizes(regalia).len() > 0
          if (hasAnyRewards)
            rewards.append({
              place = place + 1
              gold = gold
              regalia = regalia
            })
        }
        currentPlace = place
      }
      else
      {
        local place = currentPlace
        for (; place < min(maxPlaceForBlock, till); ++place)
        {
          let gold = getTblValue("place" + (place + 1) + "Gold", rewardsData, 0)
          let regalia = getRagalia(rewardsData, place + 1)
          let hasAnyRewards = gold > 0 || getRegaliaPrizes(regalia).len() > 0
          if (hasAnyRewards)
            rewards.append({
              place = place + 1
              gold = gold
              regalia = regalia
            })
        }
        currentPlace = place
      }
      if (currentPlace == till)
        break
    }

    return rewards
  }


  function getRegaliaPrizes(regalia)
  {
    let prizes = []
    if (regalia == "")
      return prizes
    let blk = getRewardsBlk()
    let pBlk = get_blk_value_by_path(blk, "reward/templates/" + regalia)
    if (!pBlk)
      return prizes
    foreach (prizeType in [ "clanTag", "decal" ])
    {
      let list = pBlk % prizeType
      if (list.len())
        prizes.append({
          type = prizeType
          list = list
        })
    }
    return prizes
  }


  function getUniquePrizesCounts(regalia)
  {
    let limits = {}
    let blk = getRewardsBlk()
    let lBlk = blk?["uiUniqueAwardCount"]
    if (!lBlk)
      return limits
    for (local i = 0; i < lBlk.blockCount(); i++)
    {
      let block = lBlk.getBlock(i)
      limits[block.getBlockName()] <- block?[regalia] ?? 0
    }
    return limits
  }


  function mergeTbl(destTbl, srcTbl, canCreateKeys = false)
  {
    foreach (i, v in srcTbl)
      if (canCreateKeys || (i in destTbl))
        destTbl[i] <- v
  }


  /**
   * Return array of all current season rewards.
   * Retrun empty array if can't get any rewards.
   * @difficulty - item from ::g_difficulty
   */
  function getSeasonRewardsList(difficulty)
  {
    let rewards = []
    let blk = getRewardsBlk()
    let subRewards = blk?.reward.subRewards
    if (!subRewards)
      return rewards

    let rewardTemplate = {
      rType = CLAN_SEASON_MEDAL_TYPE.UNKNOWN
      regalia = ""
      place = 0
      placeMin = 0
      placeMax = 0
      rating = 0
      gold = 0
      goldMin = 0
      goldMax = 0
    }

    local prevRegalia = ""
    local prevPlace = 0
    let subRewardsCount = subRewards.blockCount()
    for (local i = 0; i < subRewardsCount; i++)
    {
      let rewardBlock = subRewards.getBlock(i)
      let rewardsData = get_blk_value_by_path(rewardBlock, difficulty.egdLowercaseName + "/era5")
      if (!rewardsData)
        continue
      let maxPlaceForBlock = getMaxPlaceForBlock(rewardBlock.getBlockName())
      let isSinglePlaceReward = !isLeprRewards(rewardsData)

      if (isSinglePlaceReward)
      {
        for (local place = 1; place <= maxPlaceForBlock; place++)
        {
          let regalia = getRagalia(rewardsData, place)
          let isNewItem = regalia == "" || regalia != prevRegalia
          if (isNewItem)
          {
            let gold = rewardsData?["place" + place + "Gold"] ?? 0

            let hasAnyRewards = gold > 0 || getRegaliaPrizes(regalia).len() > 0
            if (hasAnyRewards)
            {
              let reward = clone rewardTemplate
              mergeTbl(reward, {
                rType   = CLAN_SEASON_MEDAL_TYPE.PLACE
                regalia = regalia
                place   = place
                gold    = gold
              })
              rewards.append(reward)
            }
          }
          else
          {
            let reward = rewards.len() ? rewards[rewards.len() - 1] : { place = 0 }
            let placeMin = reward.place
            mergeTbl(reward, {
              rType   = CLAN_SEASON_MEDAL_TYPE.TOP
              place   = place
              placeMin = placeMin
              placeMax = place
            })
          }
          prevRegalia = regalia
          prevPlace = place
        }
      }
      else
      {
        let place = maxPlaceForBlock
        let regalia = getRagalia(rewardsData, place)
        let goldMin = rewardsData?["lerpRewardLowPlace"] ?? 0
        let goldMax = rewardsData?["lerpRewardHiPlace"] ?? 0
        let isGoldRange = goldMin != goldMax

        let hasAnyRewards = goldMin > 0 || getRegaliaPrizes(regalia).len() > 0
        if (hasAnyRewards)
        {
          let reward = clone rewardTemplate
          mergeTbl(reward, {
            rType   = CLAN_SEASON_MEDAL_TYPE.TOP
            regalia = regalia
            place   = place
            placeMin = prevPlace + 1
            placeMax = place
            gold    = goldMin
            goldMin = isGoldRange ? goldMin : 0
            goldMax = isGoldRange ? goldMax : 0
          })
          rewards.append(reward)
        }
        prevPlace = place
      }
    }

    let rewardForRating = blk.reward % "rewardForRating"
    foreach (rewardBlock in rewardForRating)
    {
      let regalia = get_blk_value_by_path(rewardBlock, difficulty.egdLowercaseName + "/era5")
      if (!regalia)
        continue
      let reward = clone rewardTemplate
      mergeTbl(reward, {
        rType   = CLAN_SEASON_MEDAL_TYPE.RATING
        regalia = regalia
        rating  = rewardBlock?.rating ?? 0
      })
      rewards.append(reward)
    }

    return rewards
  }


  /**
   * Retrun string with current season name.
   */
  function getSeasonName()
  {
    let info = ::clan_get_current_season_info()
    let year = unixtime_to_utc_timetbl(info.startDay).year.tostring()
    let num  = ::get_roman_numeral(info.numberInYear + CLAN_SEASON_NUM_IN_YEAR_SHIFT)
    return loc("clan/battle_season/name", { year = year, num = num })
  }


  function getSeasonEndDate()
  {
    return time.buildDateTimeStr(::clan_get_current_season_info()?.rewardDay, false, false)
  }


  function isLeprRewards(rewardsDataBlk)
  {
    return rewardsDataBlk?.tillPlace
  }


  /**
   * Parse block name ("till<N> or "top<N>") for N.
   * Retrun 0 if blockName doesn't match pattern.
   */
  function getMaxPlaceForBlock(blockName)
  {
    foreach (prefix in ["top", "till"])
      if (::g_string.startsWith(blockName, prefix))
        return ::g_string.slice(blockName, prefix.len()).tointeger()

    return 0
  }


  function getRagalia(rewardsData, place = 0)
  {
    let placeRegaliaId = "place" + place + "Regalia"
    if (place != 0 && (placeRegaliaId in rewardsData))
      return rewardsData[placeRegaliaId]

    return getTblValue("regalia", rewardsData, "")
  }


  function getGoldRewardLerp(rewardData, place, lerpStartPlace)
  {
    if (rewardData.lerpRewardLowPlace == rewardData.lerpRewardHiPlace)
      return rewardData.lerpRewardHiPlace

    if (place == lerpStartPlace)
      return rewardData.lerpRewardLowPlace

    if (place == rewardData.tillPlace)
      return rewardData.lerpRewardHiPlace

    let percent = (place - lerpStartPlace) / (rewardData.lerpRewardHiPlace - lerpStartPlace)
    return percent * (rewardData.lerpRewardHiPlace - rewardData.lerpRewardLowPlace) + rewardData.lerpRewardLowPlace
  }
}


::g_clan_seasons.init()
