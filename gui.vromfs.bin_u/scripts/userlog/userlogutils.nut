from "%scripts/dagui_natives.nut" import is_user_log_for_current_room, get_user_log_time_sec, save_online_single_job, disable_user_log_entry, disable_user_log_entry_by_id, get_user_log_blk_body, get_user_logs_count
from "%scripts/dagui_library.nut" import *

let DataBlock = require("DataBlock")
let { isTable, isEmpty, isString, appendOnce } = require("%sqStdLibs/helpers/u.nut")
let DataBlockAdapter = require("%scripts/dataBlockAdapter.nut")
let { isArray } = require("%sqstd/underscore.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { isPrizeMultiAward } = require("%scripts/items/trophyMultiAward.nut")
let { convertBlk } = require("%sqstd/datablock.nut")
let { isUnlockVisible } = require("%scripts/unlocks/unlocksModule.nut")
let { hasKnowPrize } = require("%scripts/items/prizesUtils.nut")
let { findItemById } = require("%scripts/items/itemsManagerModule.nut")
let { hiddenUserlogs } = require("%scripts/userLog/userlogConsts.nut")
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")

let haveHiddenItem = @(itemDefId) findItemById(itemDefId)?.isHiddenItem()

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

let saveOnlineJob = @() save_online_single_job(223) 

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

  return rewards.filter(@(r) !!r?.expNoBonus || !!r?.wpNoBonus || !!r?.exp || !!r?.score
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

function isUserlogVisible(blk, filter, idx) {
  if (blk?.type == null)
    return false
  if (("show" in filter) && !isInArray(blk.type, filter.show))
    return false
  if (("hide" in filter) && isInArray(blk.type, filter.hide))
    return false
  if (("checkFunc" in filter) && !filter.checkFunc(blk))
    return false
  if (getTblValue("currentRoomOnly", filter, false) && !is_user_log_for_current_room(idx))
    return false
  if (haveHiddenItem(blk?.body.itemDefId ?? blk?.itemDefId))
    return false
  if (blk.type == EULT_OPEN_TROPHY && !hasKnowPrize(blk?.body ?? blk))
    return false
  return true
}
















function getUserLogsList(filter) {
  let logs = [];
  let total = get_user_logs_count()
  local needSave = false

  


  let grabStatickReward = function (reward, logObj) {
    if (reward.awardType == "base_win_award") {
      logObj.baseTournamentWp <- getTblValue("wp", reward, 0)
      logObj.baseTournamentGold <- getTblValue("gold", reward, 0)
      return true
    }
    return false
  }

  for (local i = total - 1; i >= 0; i--) {
    let blk = DataBlock()
    get_user_log_blk_body(i, blk)

    if (!isUserlogVisible(blk, filter, i))
      continue

    let isUnlockTypeNotSuitable = ("unlockType" in blk.body)
      && (blk.body.unlockType == UNLOCKABLE_TROPHY_PSN
        || blk.body.unlockType == UNLOCKABLE_TROPHY_XBOXONE
        || (("unlocks" in filter) && !isInArray(blk.body.unlockType, filter.unlocks)))

    let unlock = getUnlockById(getTblValue("unlockId", blk.body))
    let hideUnlockById = unlock != null && !isUnlockVisible(unlock)

    if (isUnlockTypeNotSuitable || (hideUnlockById && blk?.type != EULT_BUYING_UNLOCK))
      continue

    let logObj = {
      idx = i
      type = blk?.type
      time = get_user_log_time_sec(i)
      enabled = !blk?.disabled
      roomId = blk?.roomId
      isAerobaticSmoke = unlock?.isAerobaticSmoke ?? false
    }

    for (local j = 0, c = blk.body.paramCount(); j < c; j++) {
      local key = blk.body.getParamName(j)
      if (key in logObj)
        key = $"body_{key}"
      logObj[key] <- blk.body.getParamValue(j)
    }
    local hasVisibleItem = false
    for (local j = 0, c = blk.body.blockCount(); j < c; j++) {
      let block = blk.body.getBlock(j)
      let name = block.getBlockName()

      
      
      if (name == "aircrafts"
          || (name == "spare" && !isPrizeMultiAward(blk.body))) {
        if (!(name in logObj))
          logObj[name] <- []

        for (local k = 0; k < block.paramCount(); k++)
          logObj[name].append({ name = block.getParamName(k), value = block.getParamValue(k) })
      }
      else if (name == "rewardTS") {
        let reward = convertBlk(block)
        if (!grabStatickReward(reward, logObj)) {
          if (!(name in logObj))
            logObj[name] <- []
          logObj[name].append(reward)
        }
      }
      else if (block instanceof DataBlock) {
        if (haveHiddenItem(block?.itemDefId))
          continue
        hasVisibleItem = hasVisibleItem || block?.itemDefId != null
        logObj[name] <- convertBlk(block)
      }
    }

    if (!hasVisibleItem
        && (logObj.type == EULT_INVENTORY_ADD_ITEM || logObj.type == EULT_INVENTORY_FAIL_ITEM))
      continue

    local skip = false
    if ("filters" in filter)
      foreach (f, values in filter.filters)
        if (!isInArray((f in logObj) ? logObj[f] : null, values)) {
          skip = true
          break
        }

    if (skip)
      continue

    let { disableVisible = false, needStackItems = true } = filter
    let dubIdx = (needStackItems && logObj.type == EULT_OPEN_TROPHY && logObj?.parentTrophyRandId)
      ? logs.findindex(@(inst) inst.type == EULT_OPEN_TROPHY
        && inst?.parentTrophyRandId == logObj.parentTrophyRandId
          && inst?.id == logObj?.id && inst.time == logObj.time)
      : null
    if (dubIdx != null) {
      let curLog = logs[dubIdx]
      
      if (curLog?.item && logObj?.item)
        curLog.item = type(curLog.item) == "array" ? curLog.item.append(logObj.item)
          : [curLog.item].append(logObj.item)
      
      if (!curLog?.item && !logObj?.item)
        curLog.count <- (curLog?.count ?? 1) + (logObj?.count ?? 1)
    }
    
    
    logs.append(dubIdx != null ? logObj.__merge({ isDubTrophy = true }) : logObj)

    if (disableVisible) {
      if (disable_user_log_entry(i))
        needSave = true
    }
  }

  if (needSave) {
    log("getUserLogsList - needSave")
    saveOnlineJob()
  }
  return logs
}

function check_new_user_logs() {
  let total = get_user_logs_count()
  let newUserlogsArray = []
  for (local i = 0; i < total; i++) {
    let blk = DataBlock()
    get_user_log_blk_body(i, blk)
    if (blk?.disabled || hiddenUserlogs.contains(blk?.type))
      continue

    let unlockId = blk?.body.unlockId
    if (unlockId != null && !isUnlockVisible(getUnlockById(unlockId))) {
      disable_user_log_entry(i)
      continue
    }

    newUserlogsArray.append(blk)
  }
  return newUserlogsArray
}

function collectUserlogItemdefs() {
  let res = []
  for (local i = 0; i < get_user_logs_count(); ++i) {
    let blk = DataBlock()
    get_user_log_blk_body(i, blk)
    let itemDefId = blk?.body.itemDefId
    if (itemDefId)
      res.append(itemDefId)
  }
  inventoryClient.requestItemdefsByIds(res)
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
  getUserLogsList
  isUserlogVisible
  check_new_user_logs
  collectUserlogItemdefs
}