from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this


let { format } = require("string")
let time = require("%scripts/time.nut")
let workshop = require("%scripts/items/workshop/workshop.nut")
let workshopPreview = require("%scripts/items/workshop/workshopPreview.nut")
let { disableSeenUserlogs, saveOnlineJob } = require("%scripts/userLog/userlogUtils.nut")
let { showEntitlement } = require("%scripts/onlineShop/entitlementRewardWnd.nut")
let { showUnlock } = require("%scripts/unlocks/unlockRewardWnd.nut")
let { getUserstatItemRewardData, removeUserstatItemRewardToShow,
  userstatRewardTitleLocId, userstatItemsListLocId
} = require("%scripts/userstat/userstatItemsRewards.nut")
let { getMissionLocName } = require("%scripts/missions/missionsUtilsModule.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { SKIP_CLAN_FLUSH_EXP_INFO_SAVE_ID, showClanFlushExpInfo
} = require("%scripts/clans/clanFlushExpInfoModal.nut")
let { needChooseClanUnitResearch } = require("%scripts/unit/squadronUnitAction.nut")
let { isUnlockVisible } = require("%scripts/unlocks/unlocksModule.nut")
let { showEveryDayLoginAwardWnd } = require("%scripts/items/everyDayLoginAward.nut")

::shown_userlog_notifications <- []

::g_script_reloader.registerPersistentData("UserlogDataGlobals", getroottable(), ["shown_userlog_notifications"])

let function checkPopupUserLog(user_log_blk)
{
  if (user_log_blk == null)
    return false
  foreach (popupItem in ::popup_userlogs)
  {
    if (::u.isTable(popupItem))
    {
      if (popupItem.type != user_log_blk?.type)
        continue
      let rewardType = user_log_blk?.body.rewardType
      let rewardTypeFilter = popupItem.rewardType
      if (typeof(rewardTypeFilter) == "string" && rewardTypeFilter == rewardType)
        return true
      if (typeof(rewardTypeFilter) == "array" && isInArray(rewardType, rewardTypeFilter))
        return true
    }
    else if (popupItem == user_log_blk?.type)
      return true
  }
  return false
}

local function combineUserLogs(currentData, newUserLog, combineKey = null, sumParamsArray = [])
{
  let body = newUserLog?.body
  if (!body)
    return

  if (combineKey)
    combineKey = body?[combineKey]

  if (!combineKey)
    combineKey = newUserLog?.id

  if (!(combineKey in currentData))
    currentData[combineKey] <- {}

  foreach(param, value in body)
  {
    let haveParam = getTblValue(param, currentData[combineKey])
    if (!haveParam)
      currentData[combineKey][param] <- [value]
    else if (isInArray(param, sumParamsArray))
      currentData[combineKey][param][0] += value
    else if (!isInArray(value, currentData[combineKey][param]))
      currentData[combineKey][param].append(value)
  }
}

local logNameByType = {
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
}

::getLogNameByType <- @(logType) logNameByType?[logType] ?? "unknown"

::get_userlog_image_item <- function get_userlog_image_item(item, params = {})
{
  let defaultParams = {
    enableBackground = false,
    showAction = false,
    showPrice = false,
    showSellAmount = getTblValue("type", params, -1) == EULT_BUY_ITEM,
    bigPicture = false
    contentIcon = false
    interactive = true
  }

  params = defaultParams.__merge(params)
  return item ? ::handyman.renderCached(("%gui/items/item.tpl"), { items = item.getViewData(params)}) : ""
}

::check_new_user_logs <- function check_new_user_logs()
{
  let total = ::get_user_logs_count()
  let newUserlogsArray = []
  for(local i=0; i<total; i++)
  {
    let blk = ::DataBlock()
    ::get_user_log_blk_body(i, blk)
    if (blk?.disabled || isInArray(blk?.type, ::hidden_userlogs))
      continue

    let unlockId = blk?.body.unlockId
    if (unlockId != null && !isUnlockVisible(::g_unlocks.getUnlockById(unlockId)))
    {
      ::disable_user_log_entry(i)
      continue
    }

    newUserlogsArray.append(blk)
  }
  return newUserlogsArray
}

::collectOldNotifications <- function collectOldNotifications()
{
  let total = ::get_user_logs_count()
  for(local i = 0; i < total; i++)
  {
    let blk = ::DataBlock()
    ::get_user_log_blk_body(i, blk)
    if (!blk?.disabled && checkPopupUserLog(blk)
        && !isInArray(blk.id, ::shown_userlog_notifications))
      ::shown_userlog_notifications.append(blk.id)
  }
}

::checkAwardsOnStartFrom <- function checkAwardsOnStartFrom()
{
  ::checkNewNotificationUserlogs(true)
}

::checkNewNotificationUserlogs <- function checkNewNotificationUserlogs(onStartAwards = false)
{
  if (::getFromSettingsBlk("debug/skipPopups"))
    return
  if (!::g_login.isLoggedIn())
    return
  let handler = ::handlersManager.getActiveBaseHandler()
  if (!handler)
    return //no need to try do something when no one base handler loaded

  let seenIdsArray = []

  let combinedUnitTiersUserLogs = {}
  let trophyRewardsTable = {}
  let entitlementRewards = {}
  let unlocksRewards = {}
  let rentsTable = {}
  let specialOffers = {}
  let ignoreRentItems = []
  let total = ::get_user_logs_count()
  local unlocksNeedsPopupWnd = false
  let popupMask = ("getUserlogsMask" in handler) ? handler.getUserlogsMask() : USERLOG_POPUP.ALL

  for (local i = 0; i < total; i++)
  {
    let blk = ::DataBlock()
    ::get_user_log_blk_body(i, blk)

    if (blk?.disabled || isInArray(blk?.id, ::shown_userlog_notifications))
      continue

    //gamercard popups
    if (checkPopupUserLog(blk))
    {
      if (onStartAwards)
        continue

      let title = ""
      local msg = ""
      let logTypeName = ::getLogNameByType(blk?.type)
      if (blk?.type == EULT_SESSION_RESULT)
      {
        local mission = ""
        if ((blk?.body.locName.len() ?? 0) > 0)
          mission = getMissionLocName(blk?.body, "locName")
        else
          mission = loc("missions/" + (blk?.body.mission ?? ""))
        let nameLoc = "userlog/"+logTypeName + (blk?.body.win? "/win":"/lose")
        msg = format(loc(nameLoc), mission) //need more info in log, maybe title.
        ::my_stats.markStatsReset()
        if (popupMask & USERLOG_POPUP.FINISHED_RESEARCHES)
          ::checkNonApprovedResearches(true)
        ::broadcastEvent("BattleEnded", {eventId = blk?.body.eventId})
      }
      else if (blk?.type == EULT_CHARD_AWARD)
      {
        let rewardType = blk?.body.rewardType
        if (rewardType == "WagerWin" ||
            rewardType == "WagerFail" ||
            rewardType == "WagerStageWin" ||
            rewardType == "WagerStageFail")
        {
          let itemId = blk?.body.id
          let item = ::ItemsManager.findItemById(itemId)
          if (item != null)
          {
            msg = isInArray(rewardType, ["WagerStageWin", "WagerStageFail"])
              ? loc("userlog/" + rewardType) + loc("ui/colon") + colorize("userlogColoredText", item.getName())
              : loc("userlog/" + rewardType, {wagerName = colorize("userlogColoredText", item.getName())})
          }
        }
        else
          continue
      }
      else if (blk?.type == EULT_EXCHANGE_WARBONDS)
      {
        let awardBlk = blk?.body.award
        if (awardBlk)
        {
          let priceText = ::g_warbonds.getWarbondPriceText(awardBlk?.cost ?? 0)
          let awardType = ::g_wb_award_type.getTypeByBlk(awardBlk)
          msg = awardType.getUserlogBuyText(awardBlk, priceText)
          if (awardType.id == EWBAT_BATTLE_TASK && !::warbonds_has_active_battle_task(awardBlk?.name))
            ::broadcastEvent("BattleTasksIncomeUpdate")
        }
      }
      else
        msg = loc("userlog/" + logTypeName)
      ::g_popups.add(title, msg, null, null, null, logTypeName)
      ::shown_userlog_notifications.append(blk?.id)
      /*---^^^^---show notifications---^^^^---*/
    }

    if (!::isInMenu()) //other notifications only in the menu
      continue

    local markDisabled = false
    if (blk?.type == EULT_NEW_UNLOCK)
    {
      if (!blk?.body.unlockId)
        continue

      let unlockType = blk?.body.unlockType
      if (unlockType == UNLOCKABLE_TITLE && !onStartAwards)
        ::my_stats.markStatsReset()

      if ((! ::is_unlock_need_popup(blk.body.unlockId)
          && ! ::is_unlock_need_popup_in_menu(blk.body.unlockId))
        || !(popupMask & USERLOG_POPUP.UNLOCK))
      {
        if (!onStartAwards
            && (!blk?.body.popupInDebriefing || !::isHandlerInScene(::gui_handlers.DebriefingModal))
            && (unlockType == UNLOCKABLE_TITLE
               || unlockType == UNLOCKABLE_AIRCRAFT
               || unlockType == UNLOCKABLE_DECAL
               || unlockType == UNLOCKABLE_SKIN
               || unlockType == UNLOCKABLE_ATTACHABLE
               || unlockType == UNLOCKABLE_PILOT
               )
           )
        {
          unlocksRewards[blk.body.unlockId] <- true
          seenIdsArray.append(blk?.id)
        }

        continue
      }

      if (::is_unlock_need_popup_in_menu(blk.body.unlockId))
      {
        // if new unlock passes 'is_unlock_need_popup_in_menu'
        // we need to check if there is Popup Dialog
        // needed to be shown by this unlock
        // (check is at verifyPopupBlk)
        ::shown_userlog_notifications.append(blk?.id)
        unlocksNeedsPopupWnd = true
        continue
      }

      let unlock = {}
      foreach(name, value in blk.body)
        unlock[name] <- value

      let config = ::build_log_unlock_data(unlock)
      config.disableLogId <- blk.id
      ::showUnlockWnd(config)
      ::shown_userlog_notifications.append(blk.id)
      continue
    }
    else if (blk?.type == EULT_RENT_UNIT || blk?.type == EULT_RENT_UNIT_EXPIRED)
    {
      let logTypeName = ::getLogNameByType(blk.type)
      let logName = getTblValue("rentContinue", blk.body, false)? "rent_unit_extended" : logTypeName
      let unitName = getTblValue("unit", blk.body)
      let unit = ::getAircraftByName(unitName)
      let config = {
        unitName = unitName
        name = loc("mainmenu/rent/" + logName)
        desc = loc("userlog/" + logName, {unitName = ::getUnitName(unit, false)})
        descAlign = "center"
        popupImage = ""
        disableLogId = blk.id
      }

      if (blk?.type == EULT_RENT_UNIT)
      {
        config.desc += "\n"

        let rentTimeHours = time.secondsToHours(getTblValue("rentTimeLeftSec", blk.body, 0))
        let timeText = colorize("userlogColoredText", time.hoursToString(rentTimeHours))
        config.desc += loc("mainmenu/rent/rentTimeSec", {time = timeText})

        config.desc = colorize("activeTextColor", config.desc)
      }

      rentsTable[unitName + "_" + logTypeName] <- config
      markDisabled = true
    }
    else if (blk?.type == EULT_OPEN_ALL_IN_TIER)
    {
      if (onStartAwards || !(popupMask & USERLOG_POPUP.FINISHED_RESEARCHES))
        continue
      combineUserLogs(combinedUnitTiersUserLogs, blk, "unit", ["expToInvUnit", "expToExcess"])
      markDisabled = true
    }
    else if (blk?.type == EULT_OPEN_TROPHY
             && !getTblValue("everyDayLoginAward", blk.body, false))
    {
      if ("rentedUnit" in blk.body)
        ignoreRentItems.append(blk.body.rentedUnit + "_" + ::getLogNameByType(EULT_RENT_UNIT))

      if (onStartAwards || !(popupMask & USERLOG_POPUP.OPEN_TROPHY))
        continue

      let key = blk.body.id + "" + getTblValue("parentTrophyRandId", blk.body, "")
      let itemId = blk?.body?.itemDefId || blk?.body?.trophyItemDefId || blk?.body?.id || ""
      let item = ::ItemsManager.findItemById(itemId)
      let userstatItemRewardData = getUserstatItemRewardData(itemId)
      let isUserstatRewards = userstatItemRewardData != null
      if (item != null && (!item?.shouldAutoConsume || isUserstatRewards) &&
        (item?.needShowRewardWnd?() || blk?.body?.id == "@external_inventory_trophy"))
      {
        let trophyRewardTable = ::buildTableFromBlk(blk.body)
        if (isUserstatRewards) {
          trophyRewardTable.__update({
            rewardTitle = loc(userstatRewardTitleLocId)
            rewardListLocId = userstatItemsListLocId
          })
          removeUserstatItemRewardToShow(item.id)
        }
        if (!(key in trophyRewardsTable))
          trophyRewardsTable[key] <- []
        trophyRewardsTable[key].append(trophyRewardTable)
        markDisabled = true
      }
    }
    else if (blk?.type == EULT_CHARD_AWARD
             && getTblValue("rewardType", blk.body, "") == "EveryDayLoginAward"
             && ::my_stats.isNewbieInited() && !::my_stats.isMeNewbie()
             && !::isHandlerInScene(::gui_handlers.DebriefingModal))
    {
      handler.doWhenActive((@(blk) function() {showEveryDayLoginAwardWnd(blk)})(blk))
    }
    else if (blk?.type == EULT_PUNLOCK_NEW_PROPOSAL)
    {
      ::broadcastEvent("BattleTasksIncomeUpdate")
      markDisabled = true
    }
    else if (blk?.type == EULT_INVENTORY_ADD_ITEM)
    {
      let item = ::ItemsManager.getInventoryItemById(blk.body?.itemDefId)
      if (item)
      {
        if (!item?.shouldAutoConsume && !(item?.isHiddenItem() ?? false))
        {
          let logTypeName = ::getLogNameByType(blk.type)
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
          if (wSet)
            button = [{
              id = "workshop_button",
              text = loc("items/workshop"),
              func = @() wSet.needShowPreview() ? workshopPreview.open(wSet)
                : ::gui_start_items_list(itemsTab.WORKSHOP, {
                    curSheet = { id = wSet.getShopTabId() },
                    initSubsetId = wSet.getSubsetIdByItemId(item.id)
                  })
            }]

          ::g_popups.add(name, item && item.getName() ? item.getName() : "",
            null, button, null, logTypeName)
        }
        markDisabled = true
      }
    }
    else if (blk?.type == EULT_TICKETS_REMINDER)
    {
      let logTypeName = ::getLogNameByType(blk.type)
      let name = loc($"userlog/{logTypeName}")
      let desc = [colorize("userlogColoredText", ::events.getNameByEconomicName(blk?.body.name))]
      if (getTblValue("battleLimitReminder", blk.body))
        desc.append(loc("userlog/battleLimitReminder") + loc("ui/colon") + (blk?.body.battleLimitReminder ?? ""))
      if (getTblValue("defeatCountReminder", blk.body))
        desc.append(loc("userlog/defeatCountReminder") + loc("ui/colon") + (blk?.body.defeatCountReminder ?? ""))
      if (getTblValue("sequenceDefeatCountReminder", blk.body))
        desc.append(loc("userlog/sequenceDefeatCountReminder") + loc("ui/colon") + (blk?.body.sequenceDefeatCountReminder ?? ""))

      ::g_popups.add(name, ::g_string.implode(desc, "\n"), null, null, null, logTypeName)
      markDisabled = true
    }
    else if (blk?.type == EULT_ACTIVATE_ITEM)
    {
      let uid = blk?.body.uid
      let item = ::ItemsManager.findItemByUid(uid, itemType.DISCOUNT)
      if (item?.isSpecialOffer ?? false) {
        let locParams = item.getSpecialOfferLocParams()
        let unit = locParams?.unit
        if (unit != null) {
          let unitName = unit.name
          let desc = [loc("specialOffer/unitDiscount", {
            unitName = colorize("userlogColoredText", ::getUnitName(unit, false))
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
    else if (blk?.type == EULT_REMOVE_ITEM)
    {
      let reason = getTblValue("reason", blk.body, "unknown")
      if (reason == "unknown" || reason == "consumed")
      {
        let logTypeName = ::getLogNameByType(blk.type)
        let locId = $"userlog/{logTypeName}/{reason}"
        let itemId = getTblValue("id", blk.body, "")
        let item = ::ItemsManager.findItemById(itemId)
        if (item && item.iType == itemType.TICKET)
          ::g_popups.add("",
            loc(locId, {itemName = colorize("userlogColoredText", item.getName())}),
            null, null, null, logTypeName)
      }
      markDisabled = true
    }
    else if (blk?.type == EULT_BUYING_RESOURCE)
    {
      if (blk?.body?.entName != null && entitlementRewards?[blk.body.entName] == null)
        entitlementRewards[blk.body.entName] <- true
      markDisabled = true
    }
    else if (blk?.type == EULT_CLAN_UNITS && blk.body?.optype == "flush"
             && ::my_stats.isNewbieInited() && !::my_stats.isMeNewbie()) {
      let needChoseResearch = (::getAircraftByName(blk.body.unit)?.isResearched() ?? false)
        && needChooseClanUnitResearch()
      if (!needChoseResearch && ::load_local_account_settings(SKIP_CLAN_FLUSH_EXP_INFO_SAVE_ID, false))
        markDisabled = true
      else
        handler.doWhenActive(function() {
          if (!::shown_userlog_notifications.contains(blk.id))
            showClanFlushExpInfo({ userlog = blk, needChoseResearch })
        })
    }

    if (markDisabled)
      seenIdsArray.append(blk.id)
  }

  if (unlocksNeedsPopupWnd)
    handler.doWhenActive( (@(handler) function() { ::g_popup_msg.showPopupWndIfNeed(handler) })(handler))

  if (seenIdsArray.len())
    disableSeenUserlogs(seenIdsArray)

  ::gui_start_open_trophy(trophyRewardsTable)

  entitlementRewards.each(@(_key, entId) handler.doWhenActive(@() showEntitlement(entId, { ignoreAvailability = true })))
  unlocksRewards.each(@(_key, unlockId) handler.doWhenActive(@() showUnlock(unlockId, { ignoreAvailability = true })))

  rentsTable.each(function(config, key) {
    if (!isInArray(key, ignoreRentItems))
    {
      if (onStartAwards)
        handler.doWhenActive(@() ::showUnlockWnd(config))
      else
        ::showUnlockWnd(config)
    }
  })

  specialOffers.each(@(config) handler.doWhenActive(@() ::showUnlockWnd(config)))

  foreach(_name, table in combinedUnitTiersUserLogs)
  {
    ::gui_start_mod_tier_researched(table)
  }
}

::checkCountry <- function checkCountry(country, _assertText, country_0_available = false)
{
  if (!country || country=="")
    return false
  if (country == "country_0")
    return country_0_available
  if (isInArray(country, shopCountriesList))
    return true
  return false
}

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

::isUserlogVisible <- function isUserlogVisible(blk, filter, idx)
{
  if (blk?.type == null)
    return false
  if (("show" in filter) && !isInArray(blk.type, filter.show))
    return false
  if (("hide" in filter) && isInArray(blk.type, filter.hide))
    return false
  if (("checkFunc" in filter) && !filter.checkFunc(blk))
    return false
  if (getTblValue("currentRoomOnly", filter, false) && !::is_user_log_for_current_room(idx))
    return false
  if (haveHiddenItem(blk?.body.itemDefId))
    return false
  if (blk.type == EULT_OPEN_TROPHY && !::PrizesView.hasKnowPrize(blk.body))
    return false
  return true
}

::getUserLogsList <- function getUserLogsList(filter)
{
  let logs = [];
  let total = ::get_user_logs_count()
  local needSave = false

  /**
   * If statick tournament reward exist in log, writes it to logs root
   */
  let grabStatickReward = function (reward, logObj)
  {
    if (reward.awardType == "base_win_award")
    {
      logObj.baseTournamentWp <- getTblValue("wp", reward, 0)
      logObj.baseTournamentGold <- getTblValue("gold", reward, 0)
      return true
    }
    return false
  }

  for(local i = total - 1; i >= 0; i--)
  {
    let blk = ::DataBlock()
    ::get_user_log_blk_body(i, blk)

    if (!::isUserlogVisible(blk, filter, i))
      continue

    let isUnlockTypeNotSuitable = ("unlockType" in blk.body)
      && (blk.body.unlockType == UNLOCKABLE_TROPHY_PSN
        || blk.body.unlockType == UNLOCKABLE_TROPHY_XBOXONE
        || (("unlocks" in filter) && !isInArray(blk.body.unlockType, filter.unlocks)))

    let unlock = ::g_unlocks.getUnlockById(getTblValue("unlockId", blk.body))
    let hideUnlockById = unlock != null && !isUnlockVisible(unlock)

    if (isUnlockTypeNotSuitable || (hideUnlockById && blk?.type != EULT_BUYING_UNLOCK))
      continue

    let logObj = {
      idx = i
      type = blk?.type
      time = ::get_user_log_time_sec(i)
      enabled = !blk?.disabled
      roomId = blk?.roomId
      isAerobaticSmoke = unlock?.isAerobaticSmoke ?? false
    }

    for (local j = 0, c = blk.body.paramCount(); j < c; j++)
    {
      local key = blk.body.getParamName(j)
      if (key in logObj)
        key = "body_" + key
      logObj[key] <- blk.body.getParamValue(j)
    }
    local hasVisibleItem = false
    for (local j = 0, c = blk.body.blockCount(); j < c; j++)
    {
      let block = blk.body.getBlock(j)
      let name = block.getBlockName()

      //can be 2 aircrafts with the same name (cant foreach)
      //trophyMultiAward logs have spare in body too. they no need strange format hacks.
      if (name == "aircrafts"
          || (name == "spare" && !::PrizesView.isPrizeMultiAward(blk.body)))
      {
        if (!(name in logObj))
          logObj[name] <- []

        for (local k = 0; k < block.paramCount(); k++)
          logObj[name].append({name = block.getParamName(k), value = block.getParamValue(k)})
      }
      else if (name == "rewardTS")
      {
        let reward = ::buildTableFromBlk(block)
        if (!grabStatickReward(reward, logObj))
        {
          if (!(name in logObj))
            logObj[name] <- []
          logObj[name].append(reward)
        }
      }
      else if (block instanceof ::DataBlock)
      {
        if (haveHiddenItem(block?.itemDefId))
          continue
        hasVisibleItem = hasVisibleItem || block?.itemDefId != null
        logObj[name] <- ::buildTableFromBlk(block)
      }
    }

    if (!hasVisibleItem
        && (logObj.type == EULT_INVENTORY_ADD_ITEM || logObj.type == EULT_INVENTORY_FAIL_ITEM))
      continue

    local skip = false
    if ("filters" in filter)
      foreach(f, values in filter.filters)
        if (!isInArray((f in logObj)? logObj[f] : null, values))
        {
          skip = true
          break
        }

    if (skip)
      continue

    let dubIdx = (logObj.type == EULT_OPEN_TROPHY  && logObj?.parentTrophyRandId)
      ? logs.findindex(@(inst) inst.type == EULT_OPEN_TROPHY
        && inst?.parentTrophyRandId == logObj.parentTrophyRandId
          && inst?.id == logObj?.id && inst.time == logObj.time)
      : null
    if (dubIdx != null)
    {
      let curLog = logs[dubIdx]
      // Stack all trophy rewards
      if (curLog?.item && logObj?.item)
        curLog.item = typeof(curLog.item) == "array" ? curLog.item.append(logObj.item)
          : [curLog.item].append(logObj.item)
      // Stack all identical trophies
      if (!curLog?.item && !logObj?.item)
        curLog.count <- (curLog?.count ?? 1) + (logObj?.count ?? 1)
    }
    // Changes of current logObj above will be used for logObj view only
    // so no need reduce logs array to avoid differences with blk
    logs.append(dubIdx != null ? logObj.__merge({isDubTrophy = true}) : logObj)

    if ("disableVisible" in filter && filter.disableVisible)
    {
      if (::disable_user_log_entry(i))
        needSave = true
    }
  }

  if (needSave)
  {
    log("getUserLogsList - needSave")
    saveOnlineJob()
  }
  return logs
}