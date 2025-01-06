from "%scripts/dagui_natives.nut" import is_user_log_for_current_room, get_user_log_time_sec, get_user_logs_count, warbonds_has_active_battle_task, get_user_log_blk_body, disable_user_log_entry
from "%scripts/dagui_library.nut" import *
from "%scripts/userLog/userlogConsts.nut" import USERLOG_POPUP
from "%scripts/items/itemsConsts.nut" import itemsTab, itemType

let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { isHandlerInScene } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { convertBlk } = require("%sqstd/datablock.nut")
let { loadLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")
let DataBlock = require("DataBlock")
let { format } = require("string")
let { isInMenu, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let time = require("%scripts/time.nut")
let workshop = require("%scripts/items/workshop/workshop.nut")
let workshopPreview = require("%scripts/items/workshop/workshopPreview.nut")
let { disableSeenUserlogs, saveOnlineJob, shownUserlogNotifications, checkPopupUserLog,
  getLogNameByType
} = require("%scripts/userLog/userlogUtils.nut")
let { showEntitlement } = require("%scripts/onlineShop/entitlementRewardWnd.nut")
let { showUnlocks } = require("%scripts/unlocks/unlockRewardWnd.nut")
let { showUnlockWnd } = require("%scripts/unlocks/showUnlock.nut")
let { getUserstatItemRewardData, removeUserstatItemRewardToShow,
  userstatItemsListLocId } = require("%scripts/userstat/userstatItemsRewards.nut")
let { getMissionLocName } = require("%scripts/missions/missionsUtilsModule.nut")
let { SKIP_CLAN_FLUSH_EXP_INFO_SAVE_ID, showClanFlushExpInfo
} = require("%scripts/clans/clanFlushExpInfoModal.nut")
let { needChooseClanUnitResearch } = require("%scripts/unit/squadronUnitAction.nut")
let { isUnlockVisible } = require("%scripts/unlocks/unlocksModule.nut")
let { showEveryDayLoginAwardWnd } = require("%scripts/items/everyDayLoginAward.nut")
let { checkShowExternalTrophyRewardWnd } = require("%scripts/items/showExternalTrophyRewardWnd.nut")
let { isUnlockNeedPopup, isUnlockNeedPopupInMenu } = require("unlocks")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getFromSettingsBlk } = require("%scripts/clientState/clientStates.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { isNewbieInited, isMeNewbie, markStatsReset } = require("%scripts/myStats.nut")
let { findItemByUid } = require("%scripts/items/itemsManager.nut")
let { gui_start_items_list } = require("%scripts/items/startItemsShop.nut")
let { guiStartModTierResearched } = require("%scripts/modificationsTierResearched.nut")
let { guiStartOpenTrophy } = require("%scripts/items/trophyRewardWnd.nut")
let { addPopup } = require("%scripts/popups/popups.nut")
let { isMissionExtrByName } = require("%scripts/missions/missionsUtils.nut")
let { isPrizeMultiAward }= require("%scripts/items/trophyMultiAward.nut")
let { hasKnowPrize } = require("%scripts/items/prizesView.nut")
let { isLoggedIn } = require("%scripts/login/loginStates.nut")
let { openOperationRewardPopup } = require("%scripts/globalWorldwarUtils.nut")

function combineUserLogs(currentData, newUserLog, combineKey = null, sumParamsArray = []) {
  let body = newUserLog?.body
  if (!body)
    return

  if (combineKey)
    combineKey = body?[combineKey]

  if (!combineKey)
    combineKey = newUserLog?.id

  if (!(combineKey in currentData))
    currentData[combineKey] <- {}

  foreach (param, value in body) {
    let haveParam = getTblValue(param, currentData[combineKey])
    if (!haveParam)
      currentData[combineKey][param] <- [value]
    else if (isInArray(param, sumParamsArray))
      currentData[combineKey][param][0] += value
    else if (!isInArray(value, currentData[combineKey][param]))
      currentData[combineKey][param].append(value)
  }
}

::check_new_user_logs <- function check_new_user_logs() {
  let total = get_user_logs_count()
  let newUserlogsArray = []
  for (local i = 0; i < total; i++) {
    let blk = DataBlock()
    get_user_log_blk_body(i, blk)
    if (blk?.disabled || isInArray(blk?.type, ::hidden_userlogs))
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

::checkAwardsOnStartFrom <- function checkAwardsOnStartFrom() {
  ::checkNewNotificationUserlogs(true)
}

::checkNewNotificationUserlogs <- function checkNewNotificationUserlogs(onStartAwards = false) {
  if (getFromSettingsBlk("debug/skipPopups"))
    return
  if (!isLoggedIn.get())
    return
  let handler = handlersManager.getActiveBaseHandler()
  if (!handler)
    return //no need to try do something when no one base handler loaded

  if (!onStartAwards)
    checkShowExternalTrophyRewardWnd()

  let seenIdsArray = []

  let combinedUnitTiersUserLogs = {}
  let trophyRewardsTable = {}
  let entitlementRewards = {}
  let unlocksRewards = {}
  let unlockUnits = {}
  let rentsTable = {}
  let specialOffers = {}
  let ignoreRentItems = []

  //Inventory reward logs will not be received in the same time,
  //so need to wait last reward and only then mark logs as seen
  let inventoryRewards = { cache = {} }

  let total = get_user_logs_count()
  local unlocksNeedsPopupWnd = false
  let popupMask = ("getUserlogsMask" in handler) ? handler.getUserlogsMask() : USERLOG_POPUP.ALL
  local complaintsCount = 0

  for (local i = 0; i < total; i++) {
    let blk = DataBlock()
    get_user_log_blk_body(i, blk)

    if (blk?.disabled || isInArray(blk?.id, shownUserlogNotifications.get()))
      continue

    //gamercard popups
    if (checkPopupUserLog(blk)) {
      if (onStartAwards)
        continue

      let title = ""
      local msg = ""
      let logTypeName = getLogNameByType(blk?.type)
      if (blk?.type == EULT_SESSION_RESULT) {
        local mission = ""
        if ((blk?.body.locName.len() ?? 0) > 0)
          mission = getMissionLocName(blk?.body, "locName")
        else
          mission = loc($"missions/{blk?.body.mission ?? ""}")
        let isMissionExtrLog = isMissionExtrByName(blk?.body.mission ?? "")
        let nameLoc = isMissionExtrLog ? "userLog/session_result_extr"
          : $"userlog/{logTypeName}{(blk?.body.win ? "/win" : "/lose")}"
        msg = format(loc(nameLoc), mission) //need more info in log, maybe title.
        markStatsReset()
        if (popupMask & USERLOG_POPUP.FINISHED_RESEARCHES)
          ::checkNonApprovedResearches(true)
        broadcastEvent("BattleEnded", { eventId = blk?.body.eventId })
      }
      else if (blk?.type == EULT_CHARD_AWARD) {
        let rewardType = blk?.body.rewardType
        if (rewardType == "WagerWin" ||
            rewardType == "WagerFail" ||
            rewardType == "WagerStageWin" ||
            rewardType == "WagerStageFail") {
          let itemId = blk?.body.id
          let item = ::ItemsManager.findItemById(itemId)
          if (item != null) {
            msg = isInArray(rewardType, ["WagerStageWin", "WagerStageFail"])
              ? loc("ui/colon").concat(loc($"userlog/{rewardType}"), colorize("userlogColoredText", item.getName()))
              : loc($"userlog/{rewardType}", { wagerName = colorize("userlogColoredText", item.getName()) })
          }
        }
        else
          continue
      }
      else if (blk?.type == EULT_EXCHANGE_WARBONDS) {
        let awardBlk = blk?.body.award
        if (awardBlk) {
          let priceText = ::g_warbonds.getWarbondPriceText(awardBlk?.cost ?? 0)
          let awardType = ::g_wb_award_type.getTypeByBlk(awardBlk)
          msg = awardType.getUserlogBuyText(awardBlk, priceText)
          if (awardType.id == EWBAT_BATTLE_TASK && !warbonds_has_active_battle_task(awardBlk?.name))
            broadcastEvent("BattleTasksIncomeUpdate")
        }
      }
      else
        msg = loc($"userlog/{logTypeName}")
      addPopup(title, msg, null, null, null, logTypeName)
      shownUserlogNotifications.mutate(@(v) v.append(blk?.id))
      /*---^^^^---show notifications---^^^^---*/
    }

    if (!isInMenu()) //other notifications only in the menu
      continue

    local markDisabled = false
    if (blk?.type == EULT_NEW_UNLOCK) {
      if (!blk?.body.unlockId)
        continue

      let unlockType = blk?.body.unlockType
      if (unlockType == UNLOCKABLE_TITLE && !onStartAwards)
        markStatsReset()

      if ((!isUnlockNeedPopup(blk.body.unlockId)
          && !isUnlockNeedPopupInMenu(blk.body.unlockId))
        || !(popupMask & USERLOG_POPUP.UNLOCK)) {
        if (!onStartAwards && (!blk?.body.popupInDebriefing
          || !isHandlerInScene(gui_handlers.DebriefingModal))) {
          if (unlockType == UNLOCKABLE_TITLE
            || unlockType == UNLOCKABLE_DECAL
            || unlockType == UNLOCKABLE_SKIN
            || unlockType == UNLOCKABLE_ATTACHABLE
            || unlockType == UNLOCKABLE_PILOT) {
              unlocksRewards[blk.body.unlockId] <- true
              seenIdsArray.append(blk?.id)
            }

          // Don't stack unlocked units together with other ones.
          // It should look uniform with unit unlock in debriefing
          // to provide correct crew select logic further.
          if (unlockType == UNLOCKABLE_AIRCRAFT) {
            let logObj = {}
            for (local n = 0, c = blk.body.paramCount(); n < c; n++)
              logObj[blk.body.getParamName(n)] <- blk.body.getParamValue(n)

            unlockUnits[blk.body.unlockId] <- logObj
            seenIdsArray.append(blk?.id)
          }
        }

        continue
      }

      if (isUnlockNeedPopupInMenu(blk.body.unlockId)) {
        // if new unlock passes 'isUnlockNeedPopupInMenu'
        // we need to check if there is Popup Dialog
        // needed to be shown by this unlock
        // (check is at verifyPopupBlk)
        shownUserlogNotifications.mutate(@(v) v.append(blk?.id))
        unlocksNeedsPopupWnd = true
        continue
      }

      let unlock = {}
      foreach (name, value in blk.body)
        unlock[name] <- value

      let config = ::build_log_unlock_data(unlock)
      config.disableLogId <- blk.id
      showUnlockWnd(config)
      shownUserlogNotifications.mutate(@(v) v.append(blk.id))
      continue
    }
    else if (blk?.type == EULT_RENT_UNIT || blk?.type == EULT_RENT_UNIT_EXPIRED) {
      let logTypeName = getLogNameByType(blk.type)
      let logName = getTblValue("rentContinue", blk.body, false) ? "rent_unit_extended" : logTypeName
      let unitName = getTblValue("unit", blk.body)
      let unit = getAircraftByName(unitName)
      let config = {
        unitName = unitName
        name = loc($"mainmenu/rent/{logName}")
        desc = loc($"userlog/{logName}", { unitName = getUnitName(unit, false) })
        descAlign = "center"
        popupImage = ""
        disableLogId = blk.id
      }

      if (blk?.type == EULT_RENT_UNIT) {
        config.desc = $"{config.desc}\n"

        let rentTimeHours = time.secondsToHours(getTblValue("rentTimeLeftSec", blk.body, 0))
        let timeText = colorize("userlogColoredText", time.hoursToString(rentTimeHours))
        config.desc = "".concat(config.desc, loc("mainmenu/rent/rentTimeSec", { time = timeText }))

        config.desc = colorize("activeTextColor", config.desc)
      }

      rentsTable[$"{unitName}_{logTypeName}"] <- config
      markDisabled = true
    }
    else if (blk?.type == EULT_OPEN_ALL_IN_TIER) {
      if (onStartAwards || !(popupMask & USERLOG_POPUP.FINISHED_RESEARCHES))
        continue
      combineUserLogs(combinedUnitTiersUserLogs, blk, "unit", ["expToInvUnit", "expToExcess"])
      markDisabled = true
    }
    else if (blk?.type == EULT_OPEN_TROPHY
             && !getTblValue("everyDayLoginAward", blk.body, false)) {
      if ("rentedUnit" in blk.body)
        ignoreRentItems.append("_".concat(blk.body.rentedUnit, getLogNameByType(EULT_RENT_UNIT)))

      if (onStartAwards || !(popupMask & USERLOG_POPUP.OPEN_TROPHY))
        continue

      if(handlersManager.findHandlerClassInScene(gui_handlers.trophyRewardWnd) != null)
        continue

      let itemId = blk?.body?.itemDefId || blk?.body?.trophyItemDefId || blk?.body?.id || ""
      let item = ::ItemsManager.findItemById(itemId)
      let userstatItemRewardData = getUserstatItemRewardData(itemId)
      let isUserstatRewards = userstatItemRewardData != null
      if (item != null && (!item?.shouldAutoConsume || isUserstatRewards) &&
        (item?.needShowRewardWnd?() || blk?.body?.id == "@external_inventory_trophy")) {
        let trophyRewardTable = convertBlk(blk.body)
        if (isUserstatRewards) {
          trophyRewardTable.__update({
            rewardTitle = loc(userstatItemRewardData.rewardTitleLocId)
            rewardListLocId = userstatItemsListLocId
          })
          removeUserstatItemRewardToShow(item.id)
        }

        let key = $"{blk.body.id}{blk.body?.parentTrophyRandId ?? ""}"
        if (!(key in trophyRewardsTable))
          trophyRewardsTable[key] <- []
        trophyRewardsTable[key].append(trophyRewardTable)
        markDisabled = true
      }

      //Check previously received bundle trophy
      //and check only items from trophies
      if (itemId in inventoryRewards && (
        (blk.body?.fromInventory && blk.body?.trophy == null)
        || blk?.body?.id == "@external_inventory_trophy")
      ) {
        local blkBody = convertBlk(blk.body)
        let itemDefId = inventoryRewards[itemId]
        inventoryRewards.cache[itemDefId].markSeenIds.append(blk.id)
        inventoryRewards.cache[itemDefId].rewardsCount--
        inventoryRewards.cache[itemDefId].rewardsData.append(blkBody)
      }
    }
    else if (blk?.type == EULT_CHARD_AWARD
             && getTblValue("rewardType", blk.body, "") == "EveryDayLoginAward"
             && isNewbieInited() && !isMeNewbie()
             && !isHandlerInScene(gui_handlers.DebriefingModal)) {
      handler.doWhenActive(@() showEveryDayLoginAwardWnd(blk))
    }
    else if (blk?.type == EULT_PUNLOCK_NEW_PROPOSAL) {
      broadcastEvent("BattleTasksIncomeUpdate")
      markDisabled = true
    }
    else if (blk?.type == EULT_INVENTORY_ADD_ITEM) {
      if (onStartAwards)
        continue

      let itemDefId = blk.body?.itemDefId
      let item = ::ItemsManager.getInventoryItemById(itemDefId)
      if (item && !item?.shouldAutoConsume && !(item?.isHiddenItem() ?? false)) {
        let logTypeName = getLogNameByType(blk.type)
        let locId = $"userlog/{logTypeName}"
        let numItems = blk.body?.quantity ?? blk.body?.amount ?? 1
        let name = loc(locId, {
          numItemsColored = numItems
          numItems = numItems
          numItemsAdd = numItems
          itemName = ""
        })

        local button = null
        let wSet = workshop.getSetByItemId(item.id)
        if (wSet && wSet.isVisible())
          button = [{
            id = "workshop_button",
            text = loc("items/workshop"),
            func = @() wSet.needShowPreview() ? workshopPreview.open(wSet)
              : gui_start_items_list(itemsTab.WORKSHOP, {
                  curSheet = { id = wSet.getShopTabId() },
                  initSubsetId = wSet.getSubsetIdByItemId(item.id)
                })
          }]

        addPopup(name, item && item.getName() ? item.getName() : "",
          null, button, null, logTypeName)
        markDisabled = true
      }
      else if (itemDefId != null) {
        let receipeItem = ::ItemsManager.getItemOrRecipeBundleById(itemDefId)
        if (receipeItem?.forceShowRewardReceiving) {
          if (itemDefId not in inventoryRewards.cache) {
            inventoryRewards.cache[itemDefId] <- { markSeenIds = [blk.id], rewardsCount = 0, rewardsData = [] }
            //markSeenIds - for disabling them if we will decide to show reward
            //rewardsCount - for check is all rewards we've got
          }
          for (local j = 0; j < blk.body.blockCount(); j++) {
            let rewardItemDefId = blk.body.getBlock(j)?.itemDefId
            if (rewardItemDefId) {
              inventoryRewards[rewardItemDefId] <- itemDefId //for fast search of original receipe
              inventoryRewards.cache[itemDefId].rewardsCount++
            }
          }
        }
      }
    }
    else if (blk?.type == EULT_TICKETS_REMINDER) {
      let logTypeName = getLogNameByType(blk.type)
      let logName = loc($"userlog/{logTypeName}")
      let { name = null, battleLimitReminder = null, defeatCountReminder = null, sequenceDefeatCountReminder = null } = blk?.body
      let desc = [colorize("userlogColoredText", events.getNameByEconomicName(name))]
      let colonTxt = loc("ui/colon")
      if (battleLimitReminder)
        desc.append(colonTxt.concat(loc("userlog/battleLimitReminder"), battleLimitReminder))
      if (defeatCountReminder)
        desc.append(colonTxt.concat(loc("userlog/defeatCountReminder"), defeatCountReminder))
      if (sequenceDefeatCountReminder)
        desc.append(colonTxt.concat(loc("userlog/sequenceDefeatCountReminder"), sequenceDefeatCountReminder))

      addPopup(logName, "\n".join(desc, true), null, null, null, logTypeName)
      markDisabled = true
    }
    else if (blk?.type == EULT_ACTIVATE_ITEM) {
      let uid = blk?.body.uid
      let item = findItemByUid(uid, itemType.DISCOUNT)
      if (item?.isSpecialOffer ?? false) {
        let locParams = item.getSpecialOfferLocParams()
        let unit = locParams?.unit
        if (unit != null) {
          let unitName = unit.name
          let desc = [loc("specialOffer/unitDiscount", {
            unitName = colorize("userlogColoredText", getUnitName(unit, false))
            discount = locParams.discount
          })]

          let expireTimeText = item.getExpireTimeTextShort()
          if (expireTimeText != "")
            desc.append(loc("specialOffer/TimeSec", {
              time = colorize("userlogColoredText", expireTimeText)
            }))

          specialOffers[$"special_offer_{unitName}"] <- {
            unitName = unitName
            name = loc("specialOffer")
            desc = "\n".join(desc)
            descAlign = "center"
            popupImage = item?.specialOfferImage ?? ""
            ratioHeight = item?.specialOfferImageRatio ?? "0.75w"
            disableLogId = blk.id
          }
        }
      }
      markDisabled = true
    }
    else if (blk?.type == EULT_REMOVE_ITEM) {
      let reason = getTblValue("reason", blk.body, "unknown")
      if (reason == "unknown" || reason == "consumed") {
        let logTypeName = getLogNameByType(blk.type)
        let locId = $"userlog/{logTypeName}/{reason}"
        let itemId = getTblValue("id", blk.body, "")
        let item = ::ItemsManager.findItemById(itemId)
        if (item && item.iType == itemType.TICKET)
          addPopup("",
            loc(locId, { itemName = colorize("userlogColoredText", item.getName()) }),
            null, null, null, logTypeName)
      }
      markDisabled = true
    }
    else if (blk?.type == EULT_BUYING_RESOURCE) {
      if (blk?.body?.entName != null && entitlementRewards?[blk.body.entName] == null)
        entitlementRewards[blk.body.entName] <- true
      markDisabled = true
    }
    else if (blk?.type == EULT_CLAN_UNITS && blk.body?.optype == "flush"
             && isNewbieInited() && !isMeNewbie()) {
      let needChoseResearch = (getAircraftByName(blk.body.unit)?.isResearched() ?? false)
        && needChooseClanUnitResearch()
      if (!needChoseResearch && loadLocalAccountSettings(SKIP_CLAN_FLUSH_EXP_INFO_SAVE_ID, false))
        markDisabled = true
      else
        handler.doWhenActive(function() {
          if (!shownUserlogNotifications.get().contains(blk.id))
            showClanFlushExpInfo({ userlog = blk, needChoseResearch })
        })
    }
    else if (blk?.type == EULT_WW_END_OPERATION && (blk.body?.wp ?? 0) > 0) {
      openOperationRewardPopup(blk)
    }
    else if (blk?.type == EULT_COMPLAINT_UPHELD) {
      complaintsCount++
      markDisabled = true
    }

    if (markDisabled)
      seenIdsArray.append(blk.id)
  }

  if (unlocksNeedsPopupWnd)
    handler.doWhenActive(function() { ::g_popup_msg.showPopupWndIfNeed(handler) })

  foreach (inventoryItemId, invData in inventoryRewards.cache)
    if (invData.rewardsCount <= 0) {
      let itemId = inventoryItemId
      let { markSeenIds, rewardsData } = invData
      seenIdsArray.extend(markSeenIds)
      handler.doWhenActive(@() guiStartOpenTrophy({
        [itemId] = rewardsData
        rewardTitle = "{0} {1}".subst(
          loc("mainmenu/you_received"),
          ::ItemsManager.getItemOrRecipeBundleById(itemId)?.getName() ?? "")
        rewardIcon = "small_gold_chest"
        isHidePrizeActionBtn = true
      }))
    }

  if (seenIdsArray.len())
    disableSeenUserlogs(seenIdsArray)

  guiStartOpenTrophy(trophyRewardsTable)

  entitlementRewards.each(
    @(_, entId) handler.doWhenActive(@() showEntitlement(entId, { ignoreAvailability = true })))
  unlockUnits.each(@(logObj) handler.doWhenActive(
    @() showUnlockWnd(::build_log_unlock_data(logObj))))
  handler.doWhenActive(@() showUnlocks(unlocksRewards))

  rentsTable.each(function(config, key) {
    if (!isInArray(key, ignoreRentItems)) {
      if (onStartAwards)
        handler.doWhenActive(@() showUnlockWnd(config))
      else
        showUnlockWnd(config)
    }
  })

  specialOffers.each(@(config) handler.doWhenActive(@() showUnlockWnd(config)))

  foreach (_name, table in combinedUnitTiersUserLogs) {
    guiStartModTierResearched(table)
  }

  if (complaintsCount > 0) {
    let locId = "userlog/complaints/popup_message"
    let config = {
      name = loc($"{locId}/title")
      desc = " ".concat(loc($"{locId}/{complaintsCount > 1 ? "several": "single"}"),
        loc($"{locId}/thank"))
      descAlign = "left"
      popupImage = "#ui/images/new_rank_usa?P1"
      ratioHeight = 0.5
    }
    showUnlockWnd(config)
  }
}

addListenersWithoutEnv({
  TrophyWndClose = @(_p) ::checkNewNotificationUserlogs()
})

/**
 * Function runs over all userlogs and collects all userLog items,
 * which satisfies filters conditions.
 *
 * @param filter (table) - filters. May contain conditions:
 *   show (array) - array of userlog type IDs (starts from EULT) which should
 *                  be included to result.
 *   hide (array) - array of userlog type IDs (starts from EULT) which should
 *                  be excluded from result.
 *   currentRoomOnly (boolean) - include only userlogs related to current
 *                               game session. Mainly for debriefing.
 *   unlocks (array) - array of unlock type IDs.
 *   filters (table) - any custom key -> value pairs to filter userlogs
 *   disableVisible (boolean) - marks all related userlogs as seen
 */
let haveHiddenItem = @(itemDefId) ::ItemsManager.findItemById(itemDefId)?.isHiddenItem()

::isUserlogVisible <- function isUserlogVisible(blk, filter, idx) {
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
  if (haveHiddenItem(blk?.body.itemDefId))
    return false
  if (blk.type == EULT_OPEN_TROPHY && !hasKnowPrize(blk.body))
    return false
  return true
}

::getUserLogsList <- function getUserLogsList(filter) {
  let logs = [];
  let total = get_user_logs_count()
  local needSave = false

  /**
   * If statick tournament reward exist in log, writes it to logs root
   */
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

    if (!::isUserlogVisible(blk, filter, i))
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

      //can be 2 aircrafts with the same name (cant foreach)
      //trophyMultiAward logs have spare in body too. they no need strange format hacks.
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
    let dubIdx = (needStackItems && logObj.type == EULT_OPEN_TROPHY  && logObj?.parentTrophyRandId)
      ? logs.findindex(@(inst) inst.type == EULT_OPEN_TROPHY
        && inst?.parentTrophyRandId == logObj.parentTrophyRandId
          && inst?.id == logObj?.id && inst.time == logObj.time)
      : null
    if (dubIdx != null) {
      let curLog = logs[dubIdx]
      // Stack all trophy rewards
      if (curLog?.item && logObj?.item)
        curLog.item = type(curLog.item) == "array" ? curLog.item.append(logObj.item)
          : [curLog.item].append(logObj.item)
      // Stack all identical trophies
      if (!curLog?.item && !logObj?.item)
        curLog.count <- (curLog?.count ?? 1) + (logObj?.count ?? 1)
    }
    // Changes of current logObj above will be used for logObj view only
    // so no need reduce logs array to avoid differences with blk
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