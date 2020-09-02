local time = require("scripts/time.nut")
local { hasAllFeatures } = require("scripts/user/features.nut")
local bhvUnseen = ::require("scripts/seen/bhvUnseen.nut")
local promoConditions = require("scripts/promo/promoConditions.nut")
local { getPollIdByFullUrl, invalidateTokensCache } = require("scripts/web/webpoll.nut")
local { isPlatformSony,
        isPlatformXboxOne } = require("scripts/clientState/platform.nut")

local { canUseIngameShop = @() false,
        openIngameStore = @() null
} = isPlatformSony? require("scripts/onlineShop/ps4Shop.nut")
  : isPlatformXboxOne? require("scripts/onlineShop/xboxShop.nut")
  : null

local { getBundleId } = require("scripts/onlineShop/onlineBundles.nut")
local { validateLink, openUrl } = require("scripts/onlineShop/url.nut")

enum ONLINE_SHOP_TYPES {
  WARPOINTS = "warpoints"
  PREMIUM = "premium"
  BUNDLE = "bundle"
  EAGLES = "eagles"
}

local function openLink(owner, params = [], source = "promo_open_link")
{
  local link = ""
  local forceBrowser = false
  if (::u.isString(params))
    link = params
  else if (::u.isArray(params) && params.len() > 0)
  {
    link = params[0]
    forceBrowser = params.len() > 1? params[1] : false
  }

  local processedLink = validateLink(link)
  if (processedLink == null)
    return
  openUrl(processedLink, forceBrowser, false, source)
}

local function onOpenTutorial(owner, params = [])
{
  local tutorialId = ""
  if (::u.isString(params))
    tutorialId = params
  else if (::u.isArray(params) && params.len() > 0)
    tutorialId = params[0]

  owner.checkedNewFlight((@(tutorialId) function() {
    if (!::gui_start_checkTutorial(tutorialId, false))
      ::gui_start_tutorial()
  })(tutorialId))
}

local function openEventsWnd(owner, params = [])
{
  local eventId = params.len() > 0? params[0] : null
  owner.checkedForward((@(eventId) function() {
    goForwardIfOnline((@(eventId) function() {
      ::gui_start_modal_events({event = eventId})
    })(eventId), false, true)
  })(eventId), null)
}

local function openItemsWnd(owner, params = [])
{
  local tab = getconsttable()?.itemsTab?[(params?[1] ?? "SHOP").toupper()] ?? itemsTab.INVENTORY

  local curSheet = null
  local sheetSearchId = params?[0] ?? null
  local initSubsetId = params?[2] ?? null
  if (sheetSearchId)
    curSheet = {searchId = sheetSearchId}

  if (tab >= itemsTab.TOTAL)
    tab = itemsTab.INVENTORY

  ::gui_start_items_list(tab, {curSheet = curSheet, initSubsetId = initSubsetId})
}

local function onOpenBattleTasksWnd(owner, params = {}, obj = null)
{
  local taskId = obj?.task_id
  if (taskId == null && params.len() > 0)
    taskId = params[0]

  ::g_warbonds_view.resetShowProgressBarFlag()
  ::gui_start_battle_tasks_wnd(taskId)
}

local function onLaunchEmailRegistration(params)
{
  local platformName = params?[0] ?? ""
  if (platformName == "")
    return

  local launchFunctionName = ::format("launch%sEmailRegistration", platformName)
  local launchFunction = ::g_user_utils?[launchFunctionName]
  if (launchFunction)
    launchFunction()
}

local openProfileSheetParams = {
  UnlockAchievement = @(p1, p2) {
    uncollapsedChapterName = p2 != ""? p1 : null
    curAchievementGroupName = p1 + (p2 != "" ? ("/" + p2) : "")
  }
  Medal = @(p1, p2) { filterCountryName = p1 }
  UnlockSkin = @(p1, p2) {
    filterCountryName = p1
    filterUnitTag = p2
  }
  UnlockDecal = @(p1, p2) { filterGroupName = p1 }
}

::g_promo <- {
  PROMO_BUTTON_TYPE = {
    ARROW = "arrowButton"
    IMAGE = "imageButton"
    IMAGE_ROULETTE = "imageRoulette"
    BATTLE_TASK = "battleTask"
    RECENT_ITEMS = "recentItems"
  }

  BUTTON_OUT_OF_DATE_DAYS = 15
  MAX_IMAGE_WIDTH_COEF = 2
  PERFORM_ACTON_NAME = "performAction"

  DEFAULT_TIME_SWITCH_SEC = 10
  DEFAULT_MANUAL_SWITCH_TIME_MULTIPLAYER = 2
  DEFAULT_REQ_STOP_PLAY_TIME_SONG_SEC = 60

  PLAYLIST_SONG_TIMER_TASK = -1

  performActionTable = {
    events = function(handler, params, obj) { return openEventsWnd(handler, params) }
    tutorial = function(handler, params, obj) { return onOpenTutorial(handler, params) }
    battle_tasks = function(handler, params, obj) { return onOpenBattleTasksWnd(handler, params, obj) }
    url = function(handler, params, obj) {
      local pollId = getPollIdByFullUrl(params?[0] ?? "")
      if (pollId != null)
        invalidateTokensCache(pollId.tointeger())
      return openLink(handler, params)
    }
    items = function(handler, params, obj) { return openItemsWnd(handler, params) }
    squad_contacts = function(handler, params, obj) { return ::open_search_squad_player() }
    world_war = function(handler, params, obj) { ::g_world_war.openMainWnd(params?[0] == "openMainMenu") }
    content_pack = function(handler, params, obj)
    {
      ::check_package_and_ask_download(::getTblValue(0, params, ""))
    }
    profile = function(handler, params, obj)
    {
      local sheet = params?[0]
      local launchParams = openProfileSheetParams?[sheet](params?[1], params?[2] ?? "") ?? {}
      launchParams.__update({ initialSheet = sheet })
      ::gui_start_profile(launchParams)
    }
    achievements = function(handler, params, obj)
    {
      local sheet = "UnlockAchievement"
      local launchParams = openProfileSheetParams?[sheet](params?[0], params?[1] ?? "") ?? {}
      launchParams.__update({ initialSheet = sheet })
      ::gui_start_profile(launchParams)
    }
    show_unit = function(handler, params, obj)
    {
      local unitName = params?[0] ?? ""
      local unit = ::getAircraftByName(unitName)
      if (!unit)
        return

      local country = unit.shopCountry
      local showUnitInShop = @() ::gui_handlers.ShopViewWnd.open({
        curAirName = unitName
        forceUnitType = unit?.unitType })

      local acceptCallback = ::Callback( function() {
        ::switch_profile_country(country)
        showUnitInShop() }, this)
      if (country != ::get_profile_country_sq())
        ::queues.checkAndStart(
          acceptCallback,
          null,
          "isCanModifyCrew")
      else
        showUnitInShop()
    }
    email_registration = @(handler, params, obj) onLaunchEmailRegistration(params)
    online_shop = function(handler, params, obj) {
      local shopType = params?[0]
      if (shopType == ONLINE_SHOP_TYPES.BUNDLE
        || (shopType == ONLINE_SHOP_TYPES.EAGLES && canUseIngameShop()))
      {
        local bundleId = getBundleId(params?[1])
        if (bundleId != "")
        {
          if (isPlatformSony || isPlatformXboxOne)
            openIngameStore({ curItemId = bundleId, openedFrom = "promo" })
          else
            ::OnlineShopModel.doBrowserPurchaseByGuid(bundleId, params?[1])
          return
        }
      }
      else
        handler.startOnlineShop(shopType, null, "promo")
    }
  }

  collapsedParams = {
    world_war_button = { collapsedIcon = ::loc("icon/worldWar") }
    events_mainmenu_button = { collapsedIcon = ::loc("icon/events") }
    tutorial_mainmenu_button = { collapsedIcon = ::loc("icon/tutorial") }
    current_battle_tasks_mainmenu_button = {
      collapsedIcon = ::loc("icon/battleTasks")
      collapsedText = "title"
    }
    web_poll = { collapsedIcon = ::loc("icon/web_poll") }
  }
  defaultCollapsedIcon = ::loc("icon/news")
  defaultCollapsedText = ""

  visibilityByAction = {
    content_pack = function(params)
    {
      return ::has_feature("Packages") && !::have_package(::getTblValue(0, params, ""))
    }
  }

  customSeenId = {
    events_mainmenu_button = @() bhvUnseen.makeConfigStr(SEEN.EVENTS, SEEN.S_EVENTS_WINDOW)
  }
  getCustomSeenId = @(blockId) customSeenId?[blockId] && customSeenId[blockId]()

  actionParamsByBlockId = {}
  showAllPromoBlocks = false

  paramsSeparator = "; "
  blocksSeparator = "|"

  cache = null
  visibilityStatuses = {}

  multiblockData = {}

  // block name in 'customSettings > accounts > <account> > seen' = function (must return days)
  oldRecordsCheckTable = {
    promo = @(tm) tm
  }

  needUpdateByTimerTable = {
    world_war_button = true
  }

  openLinkWithSource = openLink

  function checkBlockReqEntitlement(block)
  {
    if (!("reqEntitlement" in block))
      return true

    return ::split(block.reqEntitlement, "; ").findvalue(@(ent) ::has_entitlement(ent) == 1 ) != null
  }
}

g_promo.checkOldRecordsOnInit <- function checkOldRecordsOnInit()
{
  local blk = ::loadLocalByAccount("seen")
  if (!blk)
    return

  foreach (blockName, convertTimeFunc in oldRecordsCheckTable)
  {
    local newBlk = ::DataBlock()
    local checkBlock = blk.getBlockByName(blockName)
    if (!checkBlock)
      continue

    for (local i = 0; i < checkBlock.paramCount(); i++)
    {
      local id = checkBlock.getParamName(i)
      local lastTimeSeen = checkBlock.getParamValue(i)
      local days = convertTimeFunc(lastTimeSeen)

      local minDay = time.getUtcDays() - BUTTON_OUT_OF_DATE_DAYS
      if (days > minDay)
        continue

      newBlk[id] <- lastTimeSeen
    }
    ::saveLocalByAccount("seen/" + blockName, newBlk)
  }
}

g_promo.recievePromoBlk <- function recievePromoBlk()
{
  local customPromoBlk = ::get_gui_regional_blk()?.promo_block
  if (!::u.isDataBlock(customPromoBlk)) //compatibility with not exist or old gui_regional
  {
    local blk = ::get_game_settings_blk()
    customPromoBlk = blk?.promo_block
    if (!::u.isDataBlock(customPromoBlk))
      customPromoBlk = ::DataBlock()
  }
  local showAllPromo = ::g_promo.getShowAllPromoBlocks()

  local promoBlk = ::u.copy(customPromoBlk)
  local guiBlk = ::configs.GUI.get()
  local staticPromoBlk = guiBlk?.static_promo_block

  if (!::u.isEmpty(staticPromoBlk))
  {
    //---Check on non-unique block names-----
    for (local i = 0; i < staticPromoBlk.blockCount(); i++)
    {
      local block = staticPromoBlk.getBlock(i)
      local blockName = block.getBlockName()
      local haveDouble = blockName in promoBlk
      if (!haveDouble || showAllPromo)
        promoBlk[blockName] <- ::u.copy(block)
    }
  }

  if (!::g_promo.needUpdate(promoBlk) && !showAllPromo)
    return null
  return promoBlk
}

g_promo.requestUpdate <- function requestUpdate()
{
  local promoBlk = ::g_promo.recievePromoBlk()
  if (::u.isEmpty(promoBlk))
    return false

  ::g_promo.checkOldRecordsOnInit()
  cache = ::DataBlock()
  cache.setFrom(promoBlk)
  actionParamsByBlockId.clear()
  return true
}

g_promo.clearCache <- function clearCache()
{
  cache = null
}

g_promo.getConfig <- function getConfig()
{
  return ::g_promo.cache
}

g_promo.needUpdate <- function needUpdate(newData)
{
  local reqForceUpdate = false
  for (local i = 0; i < newData.blockCount(); i++)
  {
    local block = newData.getBlock(i)
    local id = block.getBlockName()

    local show = checkBlockVisibility(block)
    if (::getTblValue(id, visibilityStatuses) != show)
    {
      visibilityStatuses[id] <- show
      reqForceUpdate = true
    }
  }

  return reqForceUpdate
}

g_promo.createActionParamsData <- function createActionParamsData(actionName, paramsArray = null)
{
  return {
    action = actionName
    paramsArray = paramsArray || []
  }
}

g_promo.gatherActionParamsData <- function gatherActionParamsData(block)
{
  local actionStr = ::getTblValue("action", block)
  if (::u.isEmpty(actionStr))
    return null

  local params = ::g_string.split(actionStr, paramsSeparator)
  local action = params.remove(0)
  return createActionParamsData(action, params)
}

g_promo.setActionParamsData <- function setActionParamsData(blockId, actionOrActionData, paramsArray = null)
{
  if (::u.isString(actionOrActionData))
    actionOrActionData = createActionParamsData(actionOrActionData, paramsArray)

  actionParamsByBlockId[blockId] <- actionOrActionData
}

g_promo.getActionParamsData <- function getActionParamsData(blockId)
{
  return ::getTblValue(blockId, actionParamsByBlockId)
}

g_promo.generateBlockView <- function generateBlockView(block)
{
  local id = block.getBlockName()
  local view = ::buildTableFromBlk(block)
  view.id <- id
  view.type <- ::g_promo.getType(block)
  view.collapsed <- ::g_promo.isCollapsed(id)? "yes" : "no"
  view.aspect_ratio <- countMaxSize(block)
  view.fillBlocks <- []

  local unseenIcon = getCustomSeenId(id)
  if (unseenIcon)
    view.unseenIcon <- unseenIcon
  view.notifyNew <- !unseenIcon && (view?.notifyNew ?? true)

  local isDebugModeEnabled = getShowAllPromoBlocks()
  local blocksCount = block.blockCount()
  local isMultiblock = block?.multiple ?? false
  view.isMultiblock <- isMultiblock

  view.radiobuttons <- []
  if (isMultiblock)
  {
    local value = ::to_integer_safe(multiblockData?[id]?.value ?? 0)
    local switchVal = ::to_integer_safe(block?.switch_time_sec || DEFAULT_TIME_SWITCH_SEC)
    local mSwitchVal = ::to_integer_safe(block?.manual_switch_time_multiplayer || DEFAULT_MANUAL_SWITCH_TIME_MULTIPLAYER)
    local lifeTimeVal = multiblockData?[id]?.life_time ?? switchVal
    multiblockData[id] <- { value = value,
                            switch_time_sec = switchVal,
                            manual_switch_time_multiplayer = mSwitchVal,
                            life_time = lifeTimeVal}
  }

  local requiredBlocks = isMultiblock? blocksCount : 1

  for (local i = 0; i < requiredBlocks; i++)
  {
    local blockId = view.id + (isMultiblock? ("_" + i) : "")
    local actionParamsKey = getActionParamsKey(blockId)

    local checkBlock = isMultiblock? block.getBlock(i) : block
    local fillBlock = ::buildTableFromBlk(checkBlock)
    fillBlock.blockId <- actionParamsKey

    local actionData = gatherActionParamsData(fillBlock) || gatherActionParamsData(block)
    if (actionData)
    {
      local action = actionData.action
      if (action == "url" && actionData.paramsArray.len())
        fillBlock.link <- validateLink(actionData.paramsArray[0])

      fillBlock.action <- PERFORM_ACTON_NAME
      view.collapsedAction <- PERFORM_ACTON_NAME
      setActionParamsData(actionParamsKey, actionData)
    }

    local link = getLinkText(fillBlock)
    if (::u.isEmpty(link) && isMultiblock)
      link = getLinkText(block)
    if (!::u.isEmpty(link))
    {
      fillBlock.link <- link
      setActionParamsData(actionParamsKey, "url", [link, ::getTblValue("forceExternalBrowser", checkBlock, false)])
      fillBlock.action <- PERFORM_ACTON_NAME
      view.collapsedAction <- PERFORM_ACTON_NAME
    }

    local image = getImage(fillBlock)
    if (image != "")
      fillBlock.image <- image

    local text = getViewText(fillBlock, isMultiblock ? "" : null)
    if (::u.isEmpty(text) && isMultiblock)
      text = getViewText(block)
    fillBlock.text <- text

    local showTextShade = !::is_chat_message_empty(text) || isDebugModeEnabled
    fillBlock.showTextShade <- showTextShade

    local isBlockSelected = isValueCurrentInMultiBlock(id, i)
    local show = checkBlockVisibility(checkBlock) && isBlockSelected
    if (view.type == PROMO_BUTTON_TYPE.ARROW && !showTextShade)
      show = false
    fillBlock.blockShow <- show

    fillBlock.aspect_ratio <- view.aspect_ratio
    view.fillBlocks.append(fillBlock)

    view.radiobuttons.append({selected = isBlockSelected})
  }

  if ("action" in view)
    delete view.action
  view.show <- checkBlockVisibility(block) && block?.pollId == null
  view.collapsedIcon <- getCollapsedIcon(view, id)
  view.collapsedText <- getCollapsedText(view, id)
  view.needUpdateByTimer <- view?.needUpdateByTimer ?? needUpdateByTimerTable?[id]

  return view
}

g_promo.getCollapsedIcon <- function getCollapsedIcon(view, promoButtonId)
{
  local result = ""
  local icon = collapsedParams?[promoButtonId].collapsedIcon
  if (icon)
    result = ::getTblValue(icon, view, icon) //can be set as param
  else
    result = ::g_language.getLocTextFromConfig(view, "collapsedIcon", defaultCollapsedIcon)

  return ::loc(result)
}

g_promo.getCollapsedText <- function getCollapsedText(view, promoButtonId)
{
  local result = ""
  local text = collapsedParams?[promoButtonId].collapsedText
  if (text)
    result = ::getTblValue(text, view, defaultCollapsedText) //can be set as param
  else
    result = ::g_language.getLocTextFromConfig(view, "collapsedText", defaultCollapsedText)

  return ::loc(result)
}

g_promo.countMaxSize <- function countMaxSize(block)
{
  local ratio = block?.aspect_ratio ?? 1
  local height = 1.0
  local width = ratio

  if (ratio > MAX_IMAGE_WIDTH_COEF)
  {
    width = MAX_IMAGE_WIDTH_COEF
    height = MAX_IMAGE_WIDTH_COEF / ratio
  }

  return ::format("height:t='%0.2f@arrowButtonWithImageHeight'; width:t='%0.2fh'", height, width)
}

/**
 * First searches text for current language (e.g. "text_en", "text_ru").
 * If no such text found, tries to return text in "text" property.
 * If nothing find returns block id.
 */
g_promo.getViewText <- function getViewText(view, defValue = null)
{
  return ::g_language.getLocTextFromConfig(view, "text", defValue)
}

g_promo.getLinkText <- function getLinkText(view)
{
  return ::g_language.getLocTextFromConfig(view, "link", "")
}

g_promo.getLinkBtnText <- function getLinkBtnText(view)
{
  return ::g_language.getLocTextFromConfig(view, "linkText", "")
}

g_promo.getImage <- function getImage(view)
{
  return ::g_language.getLocTextFromConfig(view, "image", "")
}

g_promo.checkBlockTime <- function checkBlockTime(block)
{
  local utcTime = ::get_charserver_time_sec()

  local startTime = getUTCTimeFromBlock(block, "startTime")
  if (startTime > 0 && startTime >= utcTime)
    return false

  local endTime = getUTCTimeFromBlock(block, "endTime")
  if (endTime > 0 && utcTime >= endTime)
    return false

  if (!::g_partner_unlocks.isPartnerUnlockAvailable(block?.partnerUnlock, block?.partnerUnlockDurationMin))
    return false

  // Block has no time restrictions.
  return true
}

g_promo.checkBlockReqFeature <- function checkBlockReqFeature(block)
{
  if (!("reqFeature" in block))
    return true

  return hasAllFeatures(::split(block.reqFeature, "; "))
}

g_promo.checkBlockUnlock <- function checkBlockUnlock(block)
{
  if (!("reqUnlock" in block))
    return true

  return ::g_unlocks.checkUnlockString(block.reqUnlock)
}

g_promo.isVisibleByAction <- function isVisibleByAction(block)
{
  local actionData = gatherActionParamsData(block)
  if (!actionData)
    return true
  local isVisibleFunc = ::getTblValue(actionData.action, visibilityByAction)
  return !isVisibleFunc || isVisibleFunc(actionData.paramsArray)
}

g_promo.getCurrentValueInMultiBlock <- function getCurrentValueInMultiBlock(id)
{
  return multiblockData?[id]?.value ?? 0
}

g_promo.isValueCurrentInMultiBlock <- function isValueCurrentInMultiBlock(id, value)
{
  return ::g_promo.getCurrentValueInMultiBlock(id) == value
}

g_promo.checkBlockVisibility <- function checkBlockVisibility(block)
{
  return (::g_language.isAvailableForCurLang(block)
           && checkBlockReqFeature(block)
           && checkBlockReqEntitlement(block)
           && checkBlockUnlock(block)
           && checkBlockTime(block)
           && isVisibleByAction(block)
           && promoConditions.isVisibleByConditions(block)
           && isLinkVisible(block))
         || getShowAllPromoBlocks()
}

g_promo.isLinkVisible <- function isLinkVisible(block)
{
  return ::u.isEmpty(block?.link) || ::has_feature("AllowExternalLink")
}

g_promo.getUTCTimeFromBlock <- function getUTCTimeFromBlock(block, timeProperty)
{
  local timeText = ::getTblValue(timeProperty, block, null)
  if (!::u.isString(timeText) || timeText.len() == 0)
    return -1
  return time.getTimestampFromStringUtc(timeText)
}

g_promo.initWidgets <- function initWidgets(obj, widgetsTable, widgetsWithCounter = [])
{
  foreach(id, table in widgetsTable)
    widgetsTable[id] = ::g_promo.initNewWidget(id, obj, widgetsWithCounter)
}

g_promo.getActionParamsKey <- function getActionParamsKey(id)
{
  return "perform_action_" + id
}

g_promo.cutActionParamsKey <- function cutActionParamsKey(id)
{
  return ::g_string.cutPrefix(id, "perform_action_", id)
}

g_promo.getType <- function getType(block)
{
  local res = PROMO_BUTTON_TYPE.ARROW
  if (block.blockCount() > 1)
    res = PROMO_BUTTON_TYPE.IMAGE_ROULETTE
  else if (::getTblValue("image", block, "") != "")
    res = PROMO_BUTTON_TYPE.IMAGE
  else if (block.getBlockName().indexof("current_battle_tasks") != null)
    res = PROMO_BUTTON_TYPE.BATTLE_TASK

  return res
}

g_promo.setButtonText <- function setButtonText(buttonObj, id, text = "")
{
  if (!::checkObj(buttonObj))
    return

  local obj = buttonObj.findObject(id + "_text")
  if (::checkObj(obj))
    obj.setValue(text)
}

g_promo.getVisibilityById <- function getVisibilityById(id)
{
  return ::getTblValue(id, visibilityStatuses, false)
}

//----------- <NEW ICON WIDGET> ----------------------------
g_promo.initNewWidget <- function initNewWidget(id, obj, widgetsWithCounter = [])
{
  if (isWidgetSeenById(id))
    return null

  local newIconWidget = null
  local widgetContainer = obj.findObject(id + "_new_icon_widget_container")
  if (::checkObj(widgetContainer))
    newIconWidget = NewIconWidget(obj.getScene(), widgetContainer)
  return newIconWidget
}

g_promo.isWidgetSeenById <- function isWidgetSeenById(id)
{
  local blk = ::loadLocalByAccount("seen/promo")
  return id in blk
}

g_promo.setSimpleWidgetData <- function setSimpleWidgetData(widgetsTable, id, widgetsWithCounter = [])
{
  if (::isInArray(id, widgetsWithCounter))
    return

  local blk = ::loadLocalByAccount("seen/promo")
  local table = ::buildTableFromBlk(blk)

  if (!(id in table))
    table[id] <- time.getUtcDays()

  if (::getTblValue(id, widgetsTable) != null)
    widgetsTable[id].setWidgetVisible(false)

  updateSimpleWidgetsData(table)
}

g_promo.updateSimpleWidgetsData <- function updateSimpleWidgetsData(table)
{
  local minDay = time.getUtcDays() - BUTTON_OUT_OF_DATE_DAYS
  local idOnRemoveArray = []
  local blk = ::DataBlock()
  foreach(id, day in table)
  {
    if (day < minDay)
    {
      idOnRemoveArray.append(id)
      continue
    }

    blk[id] = day
  }

  ::saveLocalByAccount("seen/promo", blk)
  updateCollapseStatuses(idOnRemoveArray)
}
//-------------- </NEW ICON WIDGET> ----------------------

//-------------- <ACTION> --------------------------------
g_promo.performAction <- function performAction(handler, obj)
{
  if (!::checkObj(obj))
    return false

  local key = obj?.id
  local actionData = getActionParamsData(key)
  if (!actionData)
  {
    ::dagor.assertf(false, "Promo: Not found action params by key " + (key ?? "NULL"))
    return false
  }

  return launchAction(actionData, handler, obj)
}

g_promo.launchAction <- function launchAction(actionData, handler, obj)
{
  local action = actionData.action
  local actionFunc = ::getTblValue(action, performActionTable)
  if (!actionFunc)
  {
    ::dagor.assert(false, "Promo: Not found action in actions table. Action " + action)
    ::dagor.debug("Promo: Rest params of paramsArray")
    debugTableData(actionData)
    return false
  }

  actionFunc(handler, actionData.paramsArray, obj)
  return true
}
//---------------- </ACTIONS> -----------------------------

//-------------- <SHOW ALL CHECK BOX> ---------------------

/** Returns 'true' if user can use "Show All Promo Blocks" check box. */
g_promo.canSwitchShowAllPromoBlocksFlag <- function canSwitchShowAllPromoBlocksFlag()
{
  return ::has_feature("ShowAllPromoBlocks")
}

/** Returns 'true' is user can use check box and it is checked. */
g_promo.getShowAllPromoBlocks <- function getShowAllPromoBlocks()
{
  return canSwitchShowAllPromoBlocksFlag() && showAllPromoBlocks
}

g_promo.setShowAllPromoBlocks <- function setShowAllPromoBlocks(value)
{
  if (showAllPromoBlocks != value)
  {
    showAllPromoBlocks = value
    ::broadcastEvent("ShowAllPromoBlocksValueChanged")
  }
}

//-------------- </SHOW ALL CHECK BOX> --------------------

//--------------------- <TOGGLE> ----------------------------

g_promo.toggleItem <- function toggleItem(toggleButtonObj)
{
  local promoButtonObj = toggleButtonObj.getParent()
  local toggled = isCollapsed(promoButtonObj.id)
  local newVal = changeToggleStatus(promoButtonObj.id, toggled)
  promoButtonObj.collapsed = newVal? "yes" : "no"
}

g_promo.isCollapsed <- function isCollapsed(id)
{
  local blk = ::loadLocalByAccount("seen/promo_collapsed")
  return blk?[id] ?? false
}

g_promo.changeToggleStatus <- function changeToggleStatus(id, value)
{
  local newValue = !value
  local blk = ::loadLocalByAccount("seen/promo_collapsed") || ::DataBlock()
  blk[id] = newValue

  ::saveLocalByAccount("seen/promo_collapsed", blk)
  return newValue
}

g_promo.updateCollapseStatuses <- function updateCollapseStatuses(arr)
{
  local blk = ::loadLocalByAccount("seen/promo_collapsed")
  if (!blk)
    return

  local clearedBlk = ::DataBlock()
  foreach(id, status in blk)
  {
    if (::isInArray(id, arr))
      continue

    clearedBlk[id] = status
  }

  ::saveLocalByAccount("seen/promo_collapsed", clearedBlk)
}

//-------------------- </TOGGLE> ----------------------------

//----------------- <RADIOBUTTONS> --------------------------

g_promo.switchBlock <- function switchBlock(obj, promoHolderObj)
{
  if (!::checkObj(promoHolderObj))
    return

  if (obj?.blockId == null || multiblockData?[obj.blockId] == null)
    return

  local promoButtonObj = promoHolderObj.findObject(obj.blockId)
  local value = obj.getValue()
  local prevValue = multiblockData[promoButtonObj.id].value
  if (prevValue >= 0)
  {
    local prevObj = promoButtonObj.findObject(::g_promo.getActionParamsKey(promoButtonObj.id + "_" + prevValue))
    prevObj.animation = "hide"
  }

  local searchId = ::g_promo.getActionParamsKey(promoButtonObj.id + "_" + value)
  local curObj = promoButtonObj.findObject(searchId)
  curObj.animation = "show"
  multiblockData[promoButtonObj.id].value = value
}

g_promo.manualSwitchBlock <- function manualSwitchBlock(obj, promoHolderObj)
{
  if (!::checkObj(promoHolderObj))
    return

  local pId = obj.blockId

  multiblockData[pId].life_time = multiblockData[pId].manual_switch_time_multiplayer * multiblockData[pId].switch_time_sec

  ::g_promo.switchBlock(obj, promoHolderObj)
}

g_promo.selectNextBlock <- function selectNextBlock(obj, dt)
{
  if (!(obj?.id in multiblockData))
    return

  multiblockData[obj.id].life_time -= dt
  if (multiblockData[obj.id].life_time > 0)
    return

  multiblockData[obj.id].life_time = multiblockData[obj.id].switch_time_sec

  local listObj = obj.findObject("multiblock_radiobuttons_list")
  if (!::checkObj(listObj))
    return

  local curVal = listObj.getValue()
  local nextVal = curVal + 1
  if (nextVal >= listObj.childrenCount())
    nextVal = 0
  listObj.setValue(nextVal)
}

//----------------- </RADIOBUTTONS> -------------------------

//------------------ <PLAYBACK> -----------------------------
g_promo.enablePlayMenuMusic <- function enablePlayMenuMusic(playlistArray, tm)
{
  if (PLAYLIST_SONG_TIMER_TASK >= 0)
    return

  ::set_cached_music(::CACHED_MUSIC_MENU, ::u.chooseRandom(playlistArray), "")
  PLAYLIST_SONG_TIMER_TASK = ::periodic_task_register(this, ::g_promo.requestTurnOffPlayMenuMusic, tm)
}

g_promo.requestTurnOffPlayMenuMusic <- function requestTurnOffPlayMenuMusic(dt)
{
  if (PLAYLIST_SONG_TIMER_TASK < 0)
    return

  ::set_cached_music(::CACHED_MUSIC_MENU, "", "")
  ::periodic_task_unregister(PLAYLIST_SONG_TIMER_TASK)
  PLAYLIST_SONG_TIMER_TASK = -1
}
//------------------- </PLAYBACK> ----------------------------
