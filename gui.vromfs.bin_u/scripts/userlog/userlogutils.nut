from "%scripts/dagui_natives.nut" import save_online_single_job, disable_user_log_entry, disable_user_log_entry_by_id, get_user_log_blk_body, get_user_logs_count
from "%scripts/dagui_library.nut" import *

let DataBlock = require("DataBlock")
let { isTable, isEmpty, isString, appendOnce } = require("%sqStdLibs/helpers/u.nut")
let DataBlockAdapter = require("%scripts/dataBlockAdapter.nut")
let { isArray } = require("%sqstd/underscore.nut")

let shownUserlogNotifications = mkWatched(persist, "shownUserlogNotifications", [])

let logNameByType = {
  [EULT_SESSION_START]                 = "session_start",
  [EULT_EARLY_SESSION_LEAVE]           = "early_session_leave",
  [EULT_SESSION_RESULT]                = "session_result",
  [EULT_AWARD_FOR_PVE_MODE]            = "award_for_pve_mode",
  [EULT_BUYING_AIRCRAFT]               = "buy_aircraft",
  [EULT_BUYING_WEAPON]                 = "buy_weapon",
  [EULT_BUYING_WEAPONS_MULTI]          = "buy_weapons_auto",
  [EULT_BUYING_WEAPON_FAIL]            = "buy_weapon_failed",
  [EULT_REPAIR_AIRCRAFT]               = "repair_aircraft",
  [EULT_REPAIR_AIRCRAFT_MULTI]         = "repair_aircraft_multi",
  [EULT_NEW_RANK]                      = "new_rank",
  [EULT_NEW_UNLOCK]                    = "new_unlock",
  [EULT_BUYING_SLOT]                   = "buy_slot",
  [EULT_TRAINING_AIRCRAFT]             = "train_aircraft",
  [EULT_UPGRADING_CREW]                = "upgrade_crew",
  [EULT_SPECIALIZING_CREW]             = "specialize_crew",
  [EULT_PURCHASINGSKILLPOINTS]         = "purchase_skillpoints",
  [EULT_BUYENTITLEMENT]                = "buy_entitlement",
  [EULT_BUYING_MODIFICATION]           = "buy_modification",
  [EULT_BUYING_SPARE_AIRCRAFT]         = "buy_spare",
  [EULT_CLAN_ACTION]                   = "clan_action",
  [EULT_BUYING_UNLOCK]                 = "buy_unlock",
  [EULT_CHARD_AWARD]                   = "chard_award",
  [EULT_ADMIN_ADD_GOLD]                = "admin_add_gold",
  [EULT_ADMIN_REVERT_GOLD]             = "admin_revert_gold",
  [EULT_BUYING_SCHEME]                 = "buying_scheme",
  [EULT_BUYING_MODIFICATION_MULTI]     = "buy_modification_multi",
  [EULT_BUYING_MODIFICATION_FAIL]      = "buy_modification_fail",
  [EULT_OPEN_ALL_IN_TIER]              = "open_all_in_tier",
  [EULT_OPEN_TROPHY]                   = "open_trophy",
  [EULT_BUY_ITEM]                      = "buy_item",
  [EULT_NEW_ITEM]                      = "new_item",
  [EULT_ACTIVATE_ITEM]                 = "activate_item",
  [EULT_REMOVE_ITEM]                   = "remove_item",
  [EULT_INVENTORY_ADD_ITEM]            = "inventory_add_item",
  [EULT_INVENTORY_FAIL_ITEM]           = "inventory_fail_item",
  [EULT_TICKETS_REMINDER]              = "ticket_reminder",
  [EULT_BUY_BATTLE]                    = "buy_battle",
  [EULT_CONVERT_EXPERIENCE]            = "convert_exp",
  [EULT_SELL_BLUEPRINT]                = "sell_blueprint",
  [EULT_PUNLOCK_NEW_PROPOSAL]          = "battle_tasks_new_proposal",
  [EULT_PUNLOCK_EXPIRED]               = "battle_tasks_expired",
  [EULT_PUNLOCK_ACCEPT]                = "battle_tasks_accept",
  [EULT_PUNLOCK_CANCELED]              = "battle_tasks_cancel",
  [EULT_PUNLOCK_REROLL_PROPOSAL]       = "battle_tasks_reroll",
  [EULT_PUNLOCK_ACCEPT_MULTI]          = "battle_tasks_multi_accept",
  [EULT_CONVERT_BLUEPRINTS]            = "convert_blueprint",
  [EULT_RENT_UNIT]                     = "rent_unit",
  [EULT_RENT_UNIT_EXPIRED]             = "rent_unit_expired",
  [EULT_BUYING_RESOURCE]               = "buy_resource",
  [EULT_EXCHANGE_WARBONDS]             = "exchange_warbonds",
  [EULT_INVITE_TO_TOURNAMENT]          = "invite_to_tournament",
  [EULT_TOURNAMENT_AWARD]              = "tournament_award",
  [EULT_WW_START_OPERATION]            = "ww_start_operation",
  [EULT_WW_END_OPERATION]              = "ww_end_operation",
  [EULT_WW_CREATE_OPERATION]           = "ww_create_operation",
  [EULT_CLAN_UNITS]                    = "clan_units",
  [EULT_WW_AWARD]                      = "ww_award",
  [EULT_COMPLAINT_UPHELD]              = "complaints",
}

let popupUserlogs = [
  EULT_SESSION_RESULT
  {
    type = EULT_CHARD_AWARD
    rewardType = [
      "WagerWin"
      "WagerFail"
      "WagerStageWin"
      "WagerStageFail"
    ]
  }
  EULT_EXCHANGE_WARBONDS
]

function checkPopupUserLog(user_log_blk) {
  if (user_log_blk == null)
    return false
  foreach (popupItem in popupUserlogs) {
    if (isTable(popupItem)) {
      if (popupItem.type != user_log_blk?.type)
        continue
      let rewardType = user_log_blk?.body.rewardType
      let rewardTypeFilter = popupItem.rewardType
      if (type(rewardTypeFilter) == "string" && rewardTypeFilter == rewardType)
        return true
      if (type(rewardTypeFilter) == "array" && isInArray(rewardType, rewardTypeFilter))
        return true
    }
    else if (popupItem == user_log_blk?.type)
      return true
  }
  return false
}

let saveOnlineJob = @() save_online_single_job(223) //super secure digit for job tag :)

function disableSeenUserlogs(idsList) {
  if (isEmpty(idsList))
    return

  local needSave = false
  foreach (id in idsList) {
    if (!id)
      continue

    let disableFunc = isString(id) ? disable_user_log_entry_by_id : disable_user_log_entry
    if (disableFunc(id)) {
      needSave = true
      let addId = id
      shownUserlogNotifications.mutate(@(arr) appendOnce(addId, arr))
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

function collectOldNotifications() {
  let total = get_user_logs_count()
  for (local i = 0; i < total; i++) {
    let blk = DataBlock()
    get_user_log_blk_body(i, blk)
    if (!blk?.disabled && checkPopupUserLog(blk)
        && !isInArray(blk.id, shownUserlogNotifications.get()))
      shownUserlogNotifications.mutate(@(v) v.append(blk.id))
  }
}

let getLogNameByType = @(logType) logNameByType?[logType] ?? "unknown"

function updateRepairCost(units, repairCost) {
  local idx = 0
  while (($"cost{idx}") in units) {
    let cost = units?[$"cost{idx}"] ?? 0
    if (cost > 0)
      repairCost.rCost += cost
    else
      repairCost.notEnoughCost -= cost
    idx++
  }
}

return {
  disableSeenUserlogs
  saveOnlineJob
  getTournamentRewardData
  getBattleRewardDetails
  getBattleRewardTable
  shownUserlogNotifications
  collectOldNotifications
  checkPopupUserLog
  getLogNameByType
  updateRepairCost
}