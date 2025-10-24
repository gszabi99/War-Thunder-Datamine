from "%scripts/dagui_natives.nut" import clan_get_clan_info, clan_get_membership_requirements
from "%scripts/dagui_library.nut" import *

let { g_clan_type } = require("%scripts/clans/clanType.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let DataBlock  = require("DataBlock")
let { round } = require("math")
let { convertBlk, copyParamsToTable, eachBlock } = require("%sqstd/datablock.nut")
let { get_charserver_time_sec } = require("chard")
let { contactPresence } = require("%scripts/contacts/contactPresence.nut")
let { getClanCreationDateText, getClanInfoChangeDateText,
  getClanMembersCountText, getRegionUpdateCooldownTime
} = require("%scripts/clans/clanTextInfo.nut")
let { createSeasonRewardFromClanReward } = require("%scripts/clans/clanSeasonPlaceTitle.nut")

const ranked_column_prefix = "dr_era5"  

let emptyRating = {
  [($"{ranked_column_prefix}_arc")]   = 0,
  [($"{ranked_column_prefix}_hist")]  = 0,
  [($"{ranked_column_prefix}_sim")]   = 0
}

let emptyActivity = {
  cur = 0
  total = 0
}

let clanInfoTemplate = {
  function isRegionChangeAvailable() {
    if (this.regionLastUpdate == 0) 
      return true

    return this.regionLastUpdate + getRegionUpdateCooldownTime() <= get_charserver_time_sec() 
  }

  function getRegionChangeAvailableTime() {
    return this.regionLastUpdate + getRegionUpdateCooldownTime() 
  }

  function getClanUpgradeCost() {
    let cost = this.clanType.getNextTypeUpgradeCost()
    local resultingCostGold = cost.gold - this.spentForMemberUpgrades 
    if (resultingCostGold < 0)
      resultingCostGold = 0
    cost.gold = resultingCostGold
    return cost
  }

  function getAllRegaliaTags() {
    let result = []
    foreach (rewards in ["seasonRewards", "seasonRatingRewards"]) {
      local regalias = getTblValue("regaliaTags", this[rewards], [])
      if (!u.isArray(regalias))
        regalias = [regalias]

      
      
      
      foreach (regalia in regalias)
        if (!isInArray(regalia, result))
          result.append(regalia)
    }

    return result
  }

  function memberCount() {
    return this.members.len()
  }

  function getTypeName() {
    return this.clanType.getTypeName()
  }

  function getCreationDateText() {
    return getClanCreationDateText(this)
  }

  function getInfoChangeDateText() {
    return getClanInfoChangeDateText(this)
  }

  function getMembersCountText() {
    return getClanMembersCountText(this)
  }

  function canShowActivity() {
    return hasFeature("ClanActivity")
  }

  function getActivity() {
    return this.astat?.activity ?? 0 
  }
}




function get_clan_info_table(isUgcAllowed, clanInfo = null) {
  if (!clanInfo)
    clanInfo = clan_get_clan_info()

  if (!clanInfo?._id)
    return null

  let clan = clone clanInfoTemplate
  clan.id     <- clanInfo._id
  clan.name   <- clanInfo?.name ?? ""
  clan.tag    <- clanInfo?.tag ?? ""
  clan.lastPaidTag <- clanInfo?.lastPaidTag ?? ""
  clan.slogan <- clanInfo?.slogan ?? ""
  clan.desc   <- clanInfo?.desc ?? ""
  clan.region <- clanInfo?.region ?? ""
  clan.announcement <- clanInfo?.announcement ?? ""
  clan.cdate  <- clanInfo?.cdate ?? 0
  clan.status <- clanInfo?.status ?? "open"
  clan.mlimit <- clanInfo?.mlimit ?? 0

  clan.changedByNick <- clanInfo?.changed_by_nick ?? ""
  clan.changedByUid <- clanInfo?.changed_by_uid ?? ""
  clan.changedTime <- clanInfo?.changed_time ?? 0

  clan.spentForMemberUpgrades <- clanInfo?.mspent ?? 0
  clan.regionLastUpdate <- clanInfo?.region_last_updated ?? 0
  clan.clanType   <- g_clan_type.getTypeByName(clanInfo?.type ?? "")
  clan.autoAcceptMembership <- clanInfo?.autoaccept ?? false
  clan.membershipRequirements <- DataBlock()
  let membReqs = clan_get_membership_requirements(clanInfo)
  if (membReqs)
    clan.membershipRequirements.setFrom(membReqs);

  clan.astat <- copyParamsToTable(clanInfo?.astat)

  let clanMembersInfo = clanInfo % "members"
  local clanActivityInfo = clanInfo?.activity
  if (!clanActivityInfo)
    clanActivityInfo = DataBlock()

  clan.members <- []

  let member_ratings = clanInfo?.member_ratings ?? {}
  let getTotalActivityPerPeriod = function(expActivity) {
    local res = 0
    eachBlock(expActivity, @(period) res += period.activity)
    return res
  }

  foreach (member in clanMembersInfo) {
    
    let memberItem = copyParamsToTable(member)

    
    let ratingTable = member_ratings?[memberItem.uid] ?? {}
    foreach (key, value in emptyRating)
      memberItem[key] <- round(getTblValue(key, ratingTable, value))
    memberItem.onlineStatus <- contactPresence.UNKNOWN

    
    let memberActivityInfo = clanActivityInfo.getBlockByName(memberItem.uid) || DataBlock()
    foreach (key, value in emptyActivity)
      memberItem[$"{key}Activity"] <- (memberActivityInfo?[key] ?? value)
    let history = memberActivityInfo.getBlockByName("history")
    memberItem["activityHistory"] <- u.isDataBlock(history) ? convertBlk(history) : {}
    memberItem["curPeriodActivity"] <- memberActivityInfo?.activity ?? 0
    let expActivity = memberActivityInfo.getBlockByName("expActivity")
    memberItem["expActivity"] <- u.isDataBlock(expActivity) ? convertBlk(expActivity) : {}
    memberItem["totalPeriodActivity"] <- getTotalActivityPerPeriod(expActivity)

    clan.members.append(memberItem)
  }

  let clanCandidatesInfo = clanInfo % "candidates";
  clan.candidates <- []

  foreach (candidate in clanCandidatesInfo) {
    let candidateTemp = {}
    foreach (info, value in candidate)
      candidateTemp[info] <- value
    clan.candidates.append(candidateTemp)
  }

  let clanBlacklist = clanInfo % "blacklist"
  clan.blacklist <- []

  foreach (person in clanBlacklist) {
    let blackTemp = {}
    foreach (info, value in person)
      blackTemp[info] <- value
    clan.blacklist.append(blackTemp)
  }

  let getRewardLog = function(clanInfo_, rewardBlockId) {
    if (!(rewardBlockId in clanInfo_))
      return []

    let logObj = []
    eachBlock(clanInfo_[rewardBlockId], function(season, idx) {
      foreach (title in season % "titles")
        logObj.append(createSeasonRewardFromClanReward(title, idx, season, clan))
    })
    return logObj
  }

  let sortRewardsInlog = @(a, b) b.seasonTime <=> a.seasonTime
  let getBestRewardLog = function() {
    let logObj = []
    foreach (reward in clanInfo % "clanBestRewards")
      logObj.append({ seasonName = reward.seasonName, title = reward.title })
    return logObj
  }

  clan.rewardLog <- getRewardLog(clanInfo, "clanRewardLog")
  clan.rewardLog.sort(sortRewardsInlog)
  clan.clanBestRewards <- getBestRewardLog()

  let clanSeasonRewards = clanInfo?.clanSeasonRewards
  clan.seasonRewards <- u.isDataBlock(clanSeasonRewards) ? convertBlk(clanSeasonRewards) : {}
  let clanSeasonRatingRewards = clanInfo?.clanSeasonRatingRewards
  clan.seasonRatingRewards <- u.isDataBlock(clanSeasonRatingRewards)
    ? convertBlk(clanSeasonRatingRewards) : {}

  clan.maxActivityPerPeriod <- clanInfo?.maxActivityPerPeriod ?? 0
  clan.maxClanActivity <- clanInfo?.maxClanActivity ?? 0
  clan.rewardPeriodDays <- clanInfo?.rewardPeriodDays ?? 0
  clan.expRewardEnabled <- clanInfo?.expRewardEnabled ?? false
  clan.historyDepth <- clanInfo?.historyDepth ?? 14
  clan.nextRewardDayId <- clanInfo?.nextRewardDayId

  
  
  return ::getFilteredClanData(clan, isUgcAllowed)
}

return {
  ranked_column_prefix
  get_clan_info_table
}