from "%scripts/dagui_natives.nut" import save_online_single_job, disable_user_log_entry, disable_user_log_entry_by_id
from "%scripts/dagui_library.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let DataBlockAdapter = require("%scripts/dataBlockAdapter.nut")
let { isArray } = require("%sqstd/underscore.nut")

let saveOnlineJob = @() save_online_single_job(223) //super secure digit for job tag :)

function disableSeenUserlogs(idsList) {
  if (u.isEmpty(idsList))
    return

  local needSave = false
  foreach (id in idsList) {
    if (!id)
      continue

    let disableFunc = u.isString(id) ? ::disable_user_log_entry_by_id : disable_user_log_entry
    if (disableFunc(id)) {
      needSave = true
      u.appendOnce(id, ::shown_userlog_notifications)
    }
  }

  if (needSave) {
    log("Userlog: Disable seen logs: save online")
    saveOnlineJob()
  }
}


function getTournamentRewardData(logObj) {
  let res = []

  if (!logObj?.rewardTS)
    return []

  foreach (_idx, block in logObj.rewardTS) {
    let result = clone block

    result.type <- "TournamentReward"
    result.eventId <- logObj.name
    result.reason <- block?.awardType ?? ""
    let reasonNum = block?.fieldValue ?? 0
    result.reasonNum <- reasonNum
    result.value <- reasonNum
    result[block?.fieldName ?? result.reason] <- reasonNum

    res.append(DataBlockAdapter(result))
  }

  return res
}

function getBattleRewardDetails(reward) {
  let toArray = @(v) isArray(v) ? v : [v]
  let rewards = isArray(reward) ? reward.map(@(v) v?.event ? v.event : v)
    : toArray(reward?.event ?? reward?.unit ?? [])

  return rewards.filter(@(r) !!r?.expNoBonus || !!r?.wpNoBonus || !!r?.exp
    || (r?.finishingType == "converting") || (r?.finishingType == "mission_end")
    || r?.unit)
}

function getBattleRewardTable(containerValue) {
  if (typeof(containerValue) == "table")
    return containerValue

  local rewardTbl = {}
  if (typeof(containerValue) == "array") {
    rewardTbl.event <- []
    containerValue.each(@(nestedTbl) rewardTbl.event.extend(
      (typeof(nestedTbl.event) == "table") ? [nestedTbl.event] : nestedTbl.event
    ))
    rewardTbl.event.sort(@(a, b) (a?.timeFromMissionStart ?? 0) <=> (b?.timeFromMissionStart ?? 0))
  }

  return rewardTbl
}

return {
  disableSeenUserlogs
  saveOnlineJob
  getTournamentRewardData
  getBattleRewardDetails
  getBattleRewardTable
}