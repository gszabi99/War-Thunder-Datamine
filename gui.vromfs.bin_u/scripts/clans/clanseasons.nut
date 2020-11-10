local { get_blk_value_by_path } = require("sqStdLibs/helpers/datablockUtils.nut")
local { unixtime_to_utc_timetbl } = ::require_native("dagor.time")
local time = require("scripts/time.nut")

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
  function onEventLoginComplete(p) { rewardsBlk = null }
  function onEventSignOut(p) { rewardsBlk = null }


  function isEnabled()
  {
    if (!::has_feature("ClanSeasons_3_0"))
      return false
    return ::getTblValue("seasonsEnable", getRewardsBlk(), true)
  }


  function getTopPlayersRewarded()
  {
    local blk = getRewardsBlk()
    return get_blk_value_by_path(blk, "reward/topPlayersRewarded", 10)
  }


  /**
   * Return array of rewards for places from 1 to @till.
   * Retrun empty array if can't get any rewards.
   * @till - should pe greater than 1 and less than result of
   * @difficulty - item from ::g_difficulty
   */
  function getFirstPrizePlacesRewards(till, difficulty)
  {
    local rewards = []
    local blk = getRewardsBlk()
    local currentPlace = 0
    if (!blk?.reward.subRewards)
      return rewards

    foreach (rewardBlockName, rewardBlock in blk.reward.subRewards)
    {
      local rewardsData = get_blk_value_by_path(rewardBlock, difficulty.egdLowercaseName + "/era5")
      if (!rewardsData)
        continue
      local maxPlaceForBlock = getMaxPlaceForBlock(rewardBlockName)
      if (isLeprRewards(rewardsData))
      {
        local place = currentPlace
        for (; place < ::min(maxPlaceForBlock, till); ++place)
        {
          local gold = getGoldRewardLerp(rewardsData, place + 1, currentPlace)
          local regalia = getRagalia(rewardsData, place + 1)
          local hasAnyRewards = gold > 0 || getRegaliaPrizes(regalia).len() > 0
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
        for (; place < ::min(maxPlaceForBlock, till); ++place)
        {
          local gold = ::getTblValue("place" + (place + 1) + "Gold", rewardsData, 0)
          local regalia = getRagalia(rewardsData, place + 1)
          local hasAnyRewards = gold > 0 || getRegaliaPrizes(regalia).len() > 0
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
    local prizes = []
    if (regalia == "")
      return prizes
    local blk = getRewardsBlk()
    local pBlk = get_blk_value_by_path(blk, "reward/templates/" + regalia)
    if (!pBlk)
      return prizes
    foreach (prizeType in [ "clanTag", "decal" ])
    {
      local list = pBlk % prizeType
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
    local limits = {}
    local blk = getRewardsBlk()
    local lBlk = blk?["uiUniqueAwardCount"]
    if (!lBlk)
      return limits
    for (local i = 0; i < lBlk.blockCount(); i++)
    {
      local block = lBlk.getBlock(i)
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
    local rewards = []
    local blk = getRewardsBlk()
    if (!blk?.reward.subRewards)
      return rewards

    local rewardTemplate = {
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
    foreach (rewardBlockName, rewardBlock in blk.reward.subRewards)
    {
      local rewardsData = get_blk_value_by_path(rewardBlock, difficulty.egdLowercaseName + "/era5")
      if (!rewardsData)
        continue
      local maxPlaceForBlock = getMaxPlaceForBlock(rewardBlockName)
      local isSinglePlaceReward = !isLeprRewards(rewardsData)

      if (isSinglePlaceReward)
      {
        for (local place = 1; place <= maxPlaceForBlock; place++)
        {
          local regalia = getRagalia(rewardsData, place)
          local isNewItem = regalia == "" || regalia != prevRegalia
          if (isNewItem)
          {
            local gold = rewardsData?["place" + place + "Gold"] ?? 0

            local hasAnyRewards = gold > 0 || getRegaliaPrizes(regalia).len() > 0
            if (hasAnyRewards)
            {
              local reward = clone rewardTemplate
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
            local reward = rewards.len() ? rewards[rewards.len() - 1] : { place = 0 }
            local placeMin = reward.place
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
        local place = maxPlaceForBlock
        local regalia = getRagalia(rewardsData, place)
        local goldMin = rewardsData?["lerpRewardLowPlace"] ?? 0
        local goldMax = rewardsData?["lerpRewardHiPlace"] ?? 0
        local isGoldRange = goldMin != goldMax

        local hasAnyRewards = goldMin > 0 || getRegaliaPrizes(regalia).len() > 0
        if (hasAnyRewards)
        {
          local reward = clone rewardTemplate
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

    local rewardForRating = blk.reward % "rewardForRating"
    foreach (rewardBlock in rewardForRating)
    {
      local regalia = get_blk_value_by_path(rewardBlock, difficulty.egdLowercaseName + "/era5")
      if (!regalia)
        continue
      local reward = clone rewardTemplate
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
    local info = ::clan_get_current_season_info()
    local year = unixtime_to_utc_timetbl(info.startDay).year.tostring()
    local num  = ::get_roman_numeral(info.numberInYear + CLAN_SEASON_NUM_IN_YEAR_SHIFT)
    return ::loc("clan/battle_season/name", { year = year, num = num })
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
    local placeRegaliaId = "place" + place + "Regalia"
    if (place != 0 && (placeRegaliaId in rewardsData))
      return rewardsData[placeRegaliaId]

    return ::getTblValue("regalia", rewardsData, "")
  }


  function getGoldRewardLerp(rewardData, place, lerpStartPlace)
  {
    if (rewardData.lerpRewardLowPlace == rewardData.lerpRewardHiPlace)
      return rewardData.lerpRewardHiPlace

    if (place == lerpStartPlace)
      return rewardData.lerpRewardLowPlace

    if (place == rewardData.tillPlace)
      return rewardData.lerpRewardHiPlace

    local percent = (place - lerpStartPlace) / (rewardData.lerpRewardHiPlace - lerpStartPlace)
    return percent * (rewardData.lerpRewardHiPlace - rewardData.lerpRewardLowPlace) + rewardData.lerpRewardLowPlace
  }
}


::g_clan_seasons.init()
