local time = require("scripts/time.nut")
local workshop = require("scripts/items/workshop/workshop.nut")
local workshopPreview = require("scripts/items/workshop/workshopPreview.nut")
local { disableSeenUserlogs } = require("scripts/userLog/userlogUtils.nut")
local { showEntitlement } = require("scripts/onlineShop/entitlementRewardWnd.nut")
local { showUnlock } = require("scripts/unlocks/unlockRewardWnd.nut")

::shown_userlog_notifications <- []

::g_script_reloader.registerPersistentData("UserlogDataGlobals", ::getroottable(), ["shown_userlog_notifications"])


local logNameByType = {
  [::EULT_SESSION_START]                 = "session_start",
  [::EULT_EARLY_SESSION_LEAVE]           = "early_session_leave",
  [::EULT_SESSION_RESULT]                = "session_result",
  [::EULT_AWARD_FOR_PVE_MODE]            = "award_for_pve_mode",
  [::EULT_BUYING_AIRCRAFT]               = "buy_aircraft",
  [::EULT_BUYING_WEAPON]                 = "buy_weapon",
  [::EULT_BUYING_WEAPONS_MULTI]          = "buy_weapons_auto",
  [::EULT_BUYING_WEAPON_FAIL]            = "buy_weapon_failed",
  [::EULT_REPAIR_AIRCRAFT]               = "repair_aircraft",
  [::EULT_REPAIR_AIRCRAFT_MULTI]         = "repair_aircraft_multi",
  [::EULT_NEW_RANK]                      = "new_rank",
  [::EULT_NEW_UNLOCK]                    = "new_unlock",
  [::EULT_BUYING_SLOT]                   = "buy_slot",
  [::EULT_TRAINING_AIRCRAFT]             = "train_aircraft",
  [::EULT_UPGRADING_CREW]                = "upgrade_crew",
  [::EULT_SPECIALIZING_CREW]             = "specialize_crew",
  [::EULT_PURCHASINGSKILLPOINTS]         = "purchase_skillpoints",
  [::EULT_BUYENTITLEMENT]                = "buy_entitlement",
  [::EULT_BUYING_MODIFICATION]           = "buy_modification",
  [::EULT_BUYING_SPARE_AIRCRAFT]         = "buy_spare",
  [::EULT_CLAN_ACTION]                   = "clan_action",
  [::EULT_BUYING_UNLOCK]                 = "buy_unlock",
  [::EULT_CHARD_AWARD]                   = "chard_award",
  [::EULT_ADMIN_ADD_GOLD]                = "admin_add_gold",
  [::EULT_ADMIN_REVERT_GOLD]             = "admin_revert_gold",
  [::EULT_BUYING_SCHEME]                 = "buying_scheme",
  [::EULT_BUYING_MODIFICATION_MULTI]     = "buy_modification_multi",
  [::EULT_BUYING_MODIFICATION_FAIL]      = "buy_modification_fail",
  [::EULT_OPEN_ALL_IN_TIER]              = "open_all_in_tier",
  [::EULT_OPEN_TROPHY]                   = "open_trophy",
  [::EULT_BUY_ITEM]                      = "buy_item",
  [::EULT_NEW_ITEM]                      = "new_item",
  [::EULT_ACTIVATE_ITEM]                 = "activate_item",
  [::EULT_REMOVE_ITEM]                   = "remove_item",
  [::EULT_INVENTORY_ADD_ITEM]            = "inventory_add_item",
  [::EULT_INVENTORY_FAIL_ITEM]           = "inventory_fail_item",
  [::EULT_TICKETS_REMINDER]              = "ticket_reminder",
  [::EULT_BUY_BATTLE]                    = "buy_battle",
  [::EULT_CONVERT_EXPERIENCE]            = "convert_exp",
  [::EULT_SELL_BLUEPRINT]                = "sell_blueprint",
  [::EULT_PUNLOCK_NEW_PROPOSAL]          = "battle_tasks_new_proposal",
  [::EULT_PUNLOCK_EXPIRED]               = "battle_tasks_expired",
  [::EULT_PUNLOCK_ACCEPT]                = "battle_tasks_accept",
  [::EULT_PUNLOCK_CANCELED]              = "battle_tasks_cancel",
  [::EULT_PUNLOCK_REROLL_PROPOSAL]       = "battle_tasks_reroll",
  [::EULT_PUNLOCK_ACCEPT_MULTI]          = "battle_tasks_multi_accept",
  [::EULT_CONVERT_BLUEPRINTS]            = "convert_blueprint",
  [::EULT_RENT_UNIT]                     = "rent_unit",
  [::EULT_RENT_UNIT_EXPIRED]             = "rent_unit_expired",
  [::EULT_BUYING_RESOURCE]               = "buy_resource",
  [::EULT_EXCHANGE_WARBONDS]             = "exchange_warbonds",
  [::EULT_INVITE_TO_TOURNAMENT]          = "invite_to_tournament",
  [::EULT_TOURNAMENT_AWARD]              = "tournament_award",
  [::EULT_WW_START_OPERATION]            = "ww_start_operation",
  [::EULT_WW_END_OPERATION]              = "ww_end_operation",
  [::EULT_WW_CREATE_OPERATION]           = "ww_create_operation",
  [::EULT_CLAN_UNITS]                    = "clan_units",
  [::EULT_WW_AWARD]                      = "ww_award",
}

local clanActionNames = {
  [ULC_CREATE]                  = "create",
  [ULC_DISBAND]                 = "disband",

  [ULC_REQUEST_MEMBERSHIP]      = "request_membership",
  [ULC_CANCEL_MEMBERSHIP]       = "cancel_membership",
  [ULC_REJECT_MEMBERSHIP]       = "reject_candidate",
  [ULC_ACCEPT_MEMBERSHIP]       = "accept_candidate",

  [ULC_DISMISS]                 = "dismiss_member",
  [ULC_CHANGE_ROLE]             = "change_role",
  [ULC_CHANGE_ROLE_AUTO]        = "change_role_auto",
  [ULC_LEAVE]                   = "leave",
  [ULC_DISBANDED_BY_LEADER]     = "disbanded_by_leader",

  [ULC_ADD_TO_BLACKLIST]        = "add_to_blacklist",
  [ULC_DEL_FROM_BLACKLIST]      = "remove_from_blacklist",
  [ULC_CHANGE_CLAN_INFO]        = "clan_info_was_changed",
  [ULC_CLAN_INFO_WAS_CHANGED]   = "clan_info_was_renamed",
  [ULC_DISBANDED_BY_ADMIN]      = "clan_disbanded_by_admin",
  [ULC_UPGRADE_CLAN]            = "clan_was_upgraded",
  [ULC_UPGRADE_MEMBERS]         = "clan_max_members_count_was_increased",
}

::getLogNameByType <- @(logType) logNameByType?[logType] ?? "unknown"
::getClanActionName <- @(action) clanActionNames?[action] ?? "unknown"

::get_userlog_image_item <- function get_userlog_image_item(item, params = {})
{
  local defaultParams = {
    enableBackground = false,
    showAction = false,
    showPrice = false,
    showSellAmount = ::getTblValue("type", params, -1) == ::EULT_BUY_ITEM,
    bigPicture = false
    contentIcon = false
  }

  params = ::combine_tables(params, defaultParams)
  return item ? ::handyman.renderCached(("gui/items/item"), { items = item.getViewData(params)}) : ""
}


::get_link_markup <- function get_link_markup(text, url, acccessKeyName=null)
{
  if (!::u.isString(url) || url.len() == 0 || !::has_feature("AllowExternalLink"))
    return ""
  local btnParams = {
    text = text
    isHyperlink = true
    link = url
  }
  if (acccessKeyName && acccessKeyName.len() > 0)
  {
    btnParams.acccessKeyName <- acccessKeyName
  }
  return ::handyman.renderCached("gui/commonParts/button", btnParams)
}


::check_new_user_logs <- function check_new_user_logs()
{
  local total = ::get_user_logs_count()
  local newUserlogsArray = []
  for(local i=0; i<total; i++)
  {
    local blk = ::DataBlock()
    ::get_user_log_blk_body(i, blk)
    if (blk?.disabled || ::isInArray(blk?.type, ::hidden_userlogs))
      continue

    local unlockId = blk?.body.unlockId
    if (unlockId != null && !::is_unlock_visible(::g_unlocks.getUnlockById(unlockId)))
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
  local total = ::get_user_logs_count()
  for(local i = 0; i < total; i++)
  {
    local blk = ::DataBlock()
    ::get_user_log_blk_body(i, blk)
    if (!blk?.disabled && checkPopupUserLog(blk)
        && !::isInArray(blk.id, ::shown_userlog_notifications))
      ::shown_userlog_notifications.append(blk.id)
  }
}

::checkPopupUserLog <- function checkPopupUserLog(user_log_blk)
{
  if (user_log_blk == null)
    return false
  foreach (popupItem in ::popup_userlogs)
  {
    if (::u.isTable(popupItem))
    {
      if (popupItem.type != user_log_blk?.type)
        continue
      local rewardType = user_log_blk?.body.rewardType
      local rewardTypeFilter = popupItem.rewardType
      if (typeof(rewardTypeFilter) == "string" && rewardTypeFilter == rewardType)
        return true
      if (typeof(rewardTypeFilter) == "array" && ::isInArray(rewardType, rewardTypeFilter))
        return true
    }
    else if (popupItem == user_log_blk?.type)
      return true
  }
  return false
}

::checkAwardsOnStartFrom <- function checkAwardsOnStartFrom()
{
  checkNewNotificationUserlogs(true)
}

::checkNewNotificationUserlogs <- function checkNewNotificationUserlogs(onStartAwards = false)
{
  if (::getFromSettingsBlk("debug/skipPopups"))
    return
  if (!::g_login.isLoggedIn())
    return
  local handler = ::handlersManager.getActiveBaseHandler()
  if (!handler)
    return //no need to try do something when no one base handler loaded

  local seenIdsArray = []

  local combinedUnitTiersUserLogs = {}
  local trophyRewardsTable = {}
  local entitlementRewards = {}
  local unlocksRewards = {}
  local rentsTable = {}
  local ignoreRentItems = []
  local total = ::get_user_logs_count()
  local unlocksNeedsPopupWnd = false
  local popupMask = ("getUserlogsMask" in handler) ? handler.getUserlogsMask() : USERLOG_POPUP.ALL

  for (local i = 0; i < total; i++)
  {
    local blk = ::DataBlock()
    ::get_user_log_blk_body(i, blk)

    if (blk?.disabled || ::isInArray(blk?.id, ::shown_userlog_notifications))
      continue

    //gamercard popups
    if (checkPopupUserLog(blk))
    {
      if (onStartAwards)
        continue

      local title = ""
      local msg = ""
      local logName = getLogNameByType(blk?.type)
      if (blk?.type == ::EULT_SESSION_RESULT)
      {
        local mission = ""
        if ((blk?.body.locName.len() ?? 0) > 0)
          mission = ::get_locId_name(blk?.body, "locName")
        else
          mission = ::loc("missions/" + (blk?.body.mission ?? ""))
        local nameLoc = "userlog/"+logName + (blk?.body.win? "/win":"/lose")
        msg = format(::loc(nameLoc), mission) //need more info in log, maybe title.
        ::my_stats.markStatsReset()
        if (popupMask & USERLOG_POPUP.FINISHED_RESEARCHES)
          ::checkNonApprovedResearches(true)
        ::broadcastEvent("BattleEnded", {eventId = blk?.body.eventId})
      }
      else if (blk?.type == ::EULT_CHARD_AWARD)
      {
        local rewardType = blk?.body.rewardType
        if (rewardType == "WagerWin" ||
            rewardType == "WagerFail" ||
            rewardType == "WagerStageWin" ||
            rewardType == "WagerStageFail")
        {
          local itemId = blk?.body.id
          local item = ::ItemsManager.findItemById(itemId)
          if (item != null)
          {
            msg = ::isInArray(rewardType, ["WagerStageWin", "WagerStageFail"])
              ? ::loc("userlog/" + rewardType) + ::loc("ui/colon") + ::colorize("userlogColoredText", item.getName())
              : ::loc("userlog/" + rewardType, {wagerName = ::colorize("userlogColoredText", item.getName())})
          }
        }
        else
          continue
      }
      else if (blk?.type == ::EULT_EXCHANGE_WARBONDS)
      {
        local awardBlk = blk?.body.award
        if (awardBlk)
        {
          local priceText = ::g_warbonds.getWarbondPriceText(awardBlk?.cost ?? 0)
          local awardType = ::g_wb_award_type.getTypeByBlk(awardBlk)
          msg = awardType.getUserlogBuyText(awardBlk, priceText)
          if (awardType.id == ::EWBAT_BATTLE_TASK && !::warbonds_has_active_battle_task(awardBlk?.name))
            ::broadcastEvent("BattleTasksIncomeUpdate")
        }
      }
      else
        msg = ::loc("userlog/" + logName)
      ::g_popups.add(title, msg)
      ::shown_userlog_notifications.append(blk?.id)
      /*---^^^^---show notifications---^^^^---*/
    }

    if (!::isInMenu()) //other notifications only in the menu
      continue

    local markDisabled = false
    if (blk?.type == ::EULT_NEW_UNLOCK)
    {
      if (!blk?.body.unlockId)
        continue

      local unlockType = blk?.body.unlockType
      if (unlockType == ::UNLOCKABLE_TITLE && !onStartAwards)
        ::my_stats.markStatsReset()

      if ((! ::is_unlock_need_popup(blk.body.unlockId)
          && ! ::is_unlock_need_popup_in_menu(blk.body.unlockId))
        || !(popupMask & USERLOG_POPUP.UNLOCK))
      {
        if (!onStartAwards
            && (!blk?.body.popupInDebriefing || !::isHandlerInScene(::gui_handlers.DebriefingModal))
            && (unlockType == ::UNLOCKABLE_TITLE
               || unlockType == ::UNLOCKABLE_AIRCRAFT
               || unlockType == ::UNLOCKABLE_DECAL
               || unlockType == ::UNLOCKABLE_SKIN
               || unlockType == ::UNLOCKABLE_ATTACHABLE
               || unlockType == ::UNLOCKABLE_PILOT
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

      local unlock = {}
      foreach(name, value in blk.body)
        unlock[name] <- value

      local config = ::build_log_unlock_data(unlock)
      config.disableLogId <- blk.id
      handler.doWhenActive(@() ::showUnlockWnd(config))
      ::shown_userlog_notifications.append(blk.id)
      continue
    }
    else if (blk?.type == ::EULT_RENT_UNIT || blk?.type == ::EULT_RENT_UNIT_EXPIRED)
    {
      local logTypeName = ::getLogNameByType(blk.type)
      local logName = ::getTblValue("rentContinue", blk.body, false)? "rent_unit_extended" : logTypeName
      local unitName = ::getTblValue("unit", blk.body)
      local unit = ::getAircraftByName(unitName)
      local config = {
        unitName = unitName
        name = ::loc("mainmenu/rent/" + logName)
        desc = ::loc("userlog/" + logName, {unitName = ::getUnitName(unit, false)})
        descAlign = "center"
        popupImage = ""
        disableLogId = blk.id
      }

      if (blk?.type == ::EULT_RENT_UNIT)
      {
        config.desc += "\n"

        local rentTimeHours = time.secondsToHours(::getTblValue("rentTimeLeftSec", blk.body, 0))
        local timeText = ::colorize("userlogColoredText", time.hoursToString(rentTimeHours))
        config.desc += ::loc("mainmenu/rent/rentTimeSec", {time = timeText})

        config.desc = ::colorize("activeTextColor", config.desc)
      }

      rentsTable[unitName + "_" + logTypeName] <- config
      markDisabled = true
    }
    else if (blk?.type == ::EULT_OPEN_ALL_IN_TIER)
    {
      if (onStartAwards || !(popupMask & USERLOG_POPUP.FINISHED_RESEARCHES))
        continue
      ::combineUserLogs(combinedUnitTiersUserLogs, blk, "unit", ["expToInvUnit", "expToExcess"])
      markDisabled = true
    }
    else if (blk?.type == ::EULT_OPEN_TROPHY
             && !::getTblValue("everyDayLoginAward", blk.body, false))
    {
      if ("rentedUnit" in blk.body)
        ignoreRentItems.append(blk.body.rentedUnit + "_" + ::getLogNameByType(::EULT_RENT_UNIT))

      if (onStartAwards || !(popupMask & USERLOG_POPUP.OPEN_TROPHY))
        continue

      local key = blk.body.id + "" + ::getTblValue("parentTrophyRandId", blk.body, "")
      local itemId = blk?.body?.itemDefId || blk?.body?.trophyItemDefId || blk?.body?.id || ""
      local item = ::ItemsManager.findItemById(itemId)
      if (!item?.shouldAutoConsume &&
        (item?.needShowRewardWnd?() || blk?.body?.id == "@external_inventory_trophy"))
      {
        if (!(key in trophyRewardsTable))
          trophyRewardsTable[key] <- []
        trophyRewardsTable[key].append(buildTableFromBlk(blk.body))
        markDisabled = true
      }
    }
    else if (blk?.type == ::EULT_CHARD_AWARD
             && ::getTblValue("rewardType", blk.body, "") == "EveryDayLoginAward"
             && !::is_me_newbie())
    {
      handler.doWhenActive((@(blk) function() {::gui_start_show_login_award(blk)})(blk))
    }
    else if (blk?.type == ::EULT_PUNLOCK_NEW_PROPOSAL)
    {
      ::broadcastEvent("BattleTasksIncomeUpdate")
      markDisabled = true
    }
    else if (blk?.type == ::EULT_INVENTORY_ADD_ITEM)
    {
      local item = ::ItemsManager.findItemById(blk.body?.itemDefId)
      if (item)
      {
        if (!item?.shouldAutoConsume)
        {
          local locId = "userlog/" + ::getLogNameByType(blk.type)
          local numItems = blk.body?.quantity ?? 1
          local name = ::loc(locId, {
            numItemsColored = numItems
            numItems = numItems
            numItemsAdd = numItems
            itemName = ""
          })

          local button = null
          local wSet = workshop.getSetByItemId(item.id)
          if (wSet)
            button = [{
              id = "workshop_button",
              text = ::loc("items/workshop"),
              func = @() wSet.needShowPreview() ? workshopPreview.open(wSet)
                : ::gui_start_items_list(itemsTab.WORKSHOP, {
                    curSheet = { id = wSet.getShopTabId() },
                    initSubsetId = wSet.getSubsetIdByItemId(item.id)
                  })
            }]

          ::g_popups.add(name, item && item.getName() ? item.getName() : "", null, button)
        }
        markDisabled = true
      }
    }
    else if (blk?.type == ::EULT_TICKETS_REMINDER)
    {
      local name = ::loc("userlog/" + ::getLogNameByType(blk.type))
      local desc = [::colorize("userlogColoredText", ::events.getNameByEconomicName(blk?.body.name))]
      if (::getTblValue("battleLimitReminder", blk.body))
        desc.append(::loc("userlog/battleLimitReminder") + ::loc("ui/colon") + (blk?.body.battleLimitReminder ?? ""))
      if (::getTblValue("defeatCountReminder", blk.body))
        desc.append(::loc("userlog/defeatCountReminder") + ::loc("ui/colon") + (blk?.body.defeatCountReminder ?? ""))
      if (::getTblValue("sequenceDefeatCountReminder", blk.body))
        desc.append(::loc("userlog/sequenceDefeatCountReminder") + ::loc("ui/colon") + (blk?.body.sequenceDefeatCountReminder ?? ""))

      ::g_popups.add(name, ::g_string.implode(desc, "\n"))
      markDisabled = true
    }
    else if (blk?.type == ::EULT_REMOVE_ITEM)
    {
      local reason = ::getTblValue("reason", blk.body, "unknown")
      if (reason == "unknown" || reason == "consumed")
      {
        local locId = "userlog/" + ::getLogNameByType(blk.type) + "/" + reason
        local itemId = ::getTblValue("id", blk.body, "")
        local item = ::ItemsManager.findItemById(itemId)
        if (item && item.iType == itemType.TICKET)
          ::g_popups.add("", ::loc(locId, {itemName = ::colorize("userlogColoredText", item.getName())}))
      }
      markDisabled = true
    }
    else if (blk?.type == ::EULT_BUYING_RESOURCE)
    {
      if (blk?.body?.entName != null && entitlementRewards?[blk.body.entName] == null)
        entitlementRewards[blk.body.entName] <- true
      markDisabled = true
    }

    if (markDisabled)
      seenIdsArray.append(blk.id)
  }

  if (unlocksNeedsPopupWnd)
    handler.doWhenActive( (@(handler) function() { ::g_popup_msg.showPopupWndIfNeed(handler) })(handler))

  if (seenIdsArray.len())
    disableSeenUserlogs(seenIdsArray)

  if (trophyRewardsTable.len() > 0)
    handler.doWhenActive(@() ::gui_start_open_trophy(trophyRewardsTable))

  entitlementRewards.each(@(key, entId) handler.doWhenActive(@() showEntitlement(entId)))
  unlocksRewards.each(@(key, unlockId) handler.doWhenActive(@() showUnlock(unlockId)))

  rentsTable.each(function(config, key) {
    if (!::isInArray(key, ignoreRentItems))
    {
      if (onStartAwards)
        handler.doWhenActive(@() ::showUnlockWnd(config))
      else
        ::showUnlockWnd(config)
    }
  })

  foreach(name, table in combinedUnitTiersUserLogs)
  {
    ::gui_start_mod_tier_researched(table)
  }
}

::combineUserLogs <- function combineUserLogs(currentData, newUserLog, combineKey = null, sumParamsArray = [])
{
  local body = newUserLog?.body
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
    local haveParam = ::getTblValue(param, currentData[combineKey])
    if (!haveParam)
      currentData[combineKey][param] <- [value]
    else if (::isInArray(param, sumParamsArray))
      currentData[combineKey][param][0] += value
    else if (!::isInArray(value, currentData[combineKey][param]))
      currentData[combineKey][param].append(value)
  }
}

::checkCountry <- function checkCountry(country, assertText, country_0_available = false)
{
  if (!country || country=="")
    return false
  if (country == "country_0")
    return country_0_available
  if (::isInArray(country, ::shopCountriesList))
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
::isUserlogVisible <- function isUserlogVisible(blk, filter, idx)
{
  if (blk?.type == null)
    return false
  if (("show" in filter) && !::isInArray(blk.type, filter.show))
    return false
  if (("hide" in filter) && ::isInArray(blk.type, filter.hide))
    return false
  if (("checkFunc" in filter) && !filter.checkFunc(blk))
    return false
  if (::getTblValue("currentRoomOnly", filter, false) && !::is_user_log_for_current_room(idx))
    return false
  return true
}

::getUserLogsList <- function getUserLogsList(filter)
{
  local logs = [];
  local total = ::get_user_logs_count()
  local needSave = false

  /**
   * If statick tournament reward exist in log, writes it to logs root
   */
  local grabStatickReward = function (reward, log)
  {
    if (reward.awardType == "base_win_award")
    {
      log.baseTournamentWp <- ::getTblValue("wp", reward, 0)
      log.baseTournamentGold <- ::getTblValue("gold", reward, 0)
      return true
    }
    return false
  }

  for(local i = total - 1; i >= 0; i--)
  {
    local blk = ::DataBlock()
    ::get_user_log_blk_body(i, blk)

    if (!::isUserlogVisible(blk, filter, i))
      continue

    local isUnlockTypeNotSuitable = ("unlockType" in blk.body)
      && (blk.body.unlockType == ::UNLOCKABLE_TROPHY_PSN
        || blk.body.unlockType == ::UNLOCKABLE_TROPHY_XBOXONE
        || (("unlocks" in filter) && !::isInArray(blk.body.unlockType, filter.unlocks)))

    local unlock = ::g_unlocks.getUnlockById(::getTblValue("unlockId", blk.body))
    local hideUnlockById = unlock != null && !::is_unlock_visible(unlock)

    if (isUnlockTypeNotSuitable || hideUnlockById)
      continue

    local log = {
      idx = i
      type = blk?.type
      time = ::get_user_log_time_sec(i)
      enabled = !blk?.disabled
      roomId = blk?.roomId
    }

    for (local j = 0, c = blk.body.paramCount(); j < c; j++)
    {
      local key = blk.body.getParamName(j)
      if (key in log)
        key = "body_" + key
      log[key] <- blk.body.getParamValue(j)
    }
    for (local j = 0, c = blk.body.blockCount(); j < c; j++)
    {
      local block = blk.body.getBlock(j)
      local name = block.getBlockName()

      //can be 2 aircrafts with the same name (cant foreach)
      //trophyMultiAward logs have spare in body too. they no need strange format hacks.
      if (name == "aircrafts"
          || (name == "spare" && !::PrizesView.isPrizeMultiAward(blk.body)))
      {
        if (!(name in log))
          log[name] <- []

        for (local k = 0; k < block.paramCount(); k++)
          log[name].append({name = block.getParamName(k), value = block.getParamValue(k)})
      }
      else if (name == "rewardTS")
      {
        local reward = ::buildTableFromBlk(block)
        if (!grabStatickReward(reward, log))
        {
          if (!(name in log))
            log[name] <- []
          log[name].append(reward)
        }
      }
      else if (block instanceof ::DataBlock)
        log[name] <- ::buildTableFromBlk(block)
    }

    local skip = false
    if ("filters" in filter)
      foreach(f, values in filter.filters)
        if (!::isInArray((f in log)? log[f] : null, values))
        {
          skip = true
          break
        }

    if (skip)
      continue

    logs.append(log)

    if ("disableVisible" in filter && filter.disableVisible)
    {
      if (::disable_user_log_entry(i))
        needSave = true
    }
  }

  if (needSave)
  {
    dagor.debug("getUserLogsList - needSave")
    ::save_online_job()
  }
  return logs;
}

::get_decorator_unlock <- function get_decorator_unlock(resourceId, resourceType)
{
  local unlock = ::create_default_unlock_data()
  local decoratorType = null
  unlock.id = resourceId
  decoratorType = ::g_decorator_type.getTypeByResourceType(resourceType)
  if (decoratorType != ::g_decorator_type.UNKNOWN)
  {
    unlock.name = decoratorType.getLocName(unlock.id, true)
    unlock.desc = decoratorType.getLocDesc(unlock.id)
    unlock.image = decoratorType.userlogPurchaseIcon

    local decorator = ::g_decorator.getDecorator(unlock.id, decoratorType)
    if (decorator && !::is_in_loading_screen())
    {
      unlock.descrImage <- decoratorType.getImage(decorator)
      unlock.descrImageRatio <- decoratorType.getRatio(decorator)
      unlock.descrImageSize <- decoratorType.getImageSize(decorator)
    }
  }

  return unlock
}
