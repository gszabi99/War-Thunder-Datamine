from "%scripts/dagui_natives.nut" import clan_get_my_role, clan_get_my_clan_id, clan_get_role_rank, clan_get_role_rights, clan_get_admin_editor_mode
from "%scripts/dagui_library.nut" import *

let { get_time_msec } = require("dagor.time")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock  = require("DataBlock")
let { convertBlk } = require("%sqstd/datablock.nut")
let { charRequestBlk } = require("%scripts/tasker.nut")
let { is_in_clan, myClanInfo } = require("%scripts/clans/clanState.nut")

const REQUEST_TIME_OUT_MSEC  = 20000    
const VALID_INFO_TIME_OUT_MSEC = 1800000 

let cachedList = {}

let canRequestByTime = @(clanData) !(clanData?.isInUpdate ?? false)
  && (get_time_msec() - (clanData?.lastRequestTimeMsec ?? 0)) >= REQUEST_TIME_OUT_MSEC

let hasValidInfo = @(clanData) ("info" in clanData)
  && (get_time_msec() - clanData.lastUpdateTimeMsec < VALID_INFO_TIME_OUT_MSEC)

function needRequest(clanId) {
  let clanData = cachedList?[clanId] ?? {}
  return !hasValidInfo(clanData) && canRequestByTime(clanData)
}

function prepareListToRequest(clanIdsArray) {
  let blk = DataBlock()
  blk.addBlock("body")
  foreach (clanId in clanIdsArray) {
    let clanIdStr = clanId.tostring()
    if (clanIdStr == "" || !needRequest(clanIdStr))
      continue

    blk.body.addStr("clanId", clanIdStr)
    cachedList[clanIdStr] <- (cachedList?[clanIdStr] ?? {}).__update({
      isInUpdate = true
      lastRequestTimeMsec = get_time_msec()
    })
  }
  return blk
}

function updateClansInfoList(data) {
  let clansInfoList = {}
  foreach (info in data) {
    let id = info?._id
    if (id == null)
      continue
    cachedList[id] <- {
      info = convertBlk(info)
      lastUpdateTimeMsec = get_time_msec()
    }
    clansInfoList[id] <- cachedList[id].info
  }
  return clansInfoList
}

function requestListCb(data) {
  let clansInfoList = updateClansInfoList(data)
  broadcastEvent("UpdateClansInfoList", { clansInfoList = clansInfoList })
}

function requestError(requestBlk) {
  foreach (id in (requestBlk.body % "clanId"))
    cachedList[id].isInUpdate = false
}

function requestList(clanIdsArray) {
  let requestBlk = prepareListToRequest(clanIdsArray)
  if (!("clanId" in requestBlk.body))
    return

  let errorCb = @(_taskResult) requestError(requestBlk)
  charRequestBlk("cln_clans_list_get_short_info", requestBlk, null, requestListCb, errorCb)
  return
}

function getClansInfoByClanIds(clanIdsArray) {
  requestList(clanIdsArray)
  let res = {}
  foreach (clanId in clanIdsArray) {
    let info = cachedList?[clanId.tostring()].info
    if (info != null)
      res[clanId] <- info
  }
  return res
}

function getMyClanMembers() {
  return myClanInfo.get()?.members ?? []
}

function getMyClanRights() {
  return clan_get_role_rights(clan_get_admin_editor_mode() ? ECMR_CLANADMIN : clan_get_my_role())
}

function haveRankToChangeRoles(clanData) {
  if (clanData?.id != clan_get_my_clan_id())
    return false

  let myRank = clan_get_role_rank(clan_get_my_role())

  local rolesNumber = 0
  for (local role = 0; role < ECMR_MAX_TOTAL; role++) {
     let rank = clan_get_role_rank(role)
     if (rank != 0 && rank < myRank)
       rolesNumber++
  }

  return (rolesNumber > 1)
}

function hasRightsToQueueWWar() {
  if (!is_in_clan())
    return false
  if (!hasFeature("WorldWarClansQueue"))
    return false
  let myRights = clan_get_role_rights(clan_get_my_role())
  return isInArray("WW_REGISTER", myRights)
}

function getRewardLogData(clanData, rewardId, maxCount) {
  let list = []
  local count = 0

  foreach (seasonReward in clanData[rewardId]) {
    local params = {
      iconStyle  = seasonReward.iconStyle()
      iconConfig = seasonReward.iconConfig()
      iconParams = seasonReward.iconParams()
      name = seasonReward.name()
      desc = seasonReward.desc()
    }

    params = params.__merge({
      bestRewardsConfig = { seasonName = seasonReward.seasonIdx, title = seasonReward.seasonTitle }
    })
    list.append(params)

    if (maxCount != -1 && ++count == maxCount)
      break
  }
  return list
}

let getClanPlaceRewardLogData = @(clanData, maxCount = -1) getRewardLogData(clanData, "rewardLog", maxCount)

return {
  getClansInfoByClanIds
  getMyClanMembers
  getMyClanRights
  haveRankToChangeRoles
  hasRightsToQueueWWar
  getClanPlaceRewardLogData
}