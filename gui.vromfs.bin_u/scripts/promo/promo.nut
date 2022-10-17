from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { split_by_chars } = require("string")
let time = require("%scripts/time.nut")
let { hasAllFeatures } = require("%scripts/user/features.nut")
let promoConditions = require("%scripts/promo/promoConditions.nut")
let { getStringWidthPx } = require("%scripts/viewUtils/daguiFonts.nut")
let { getPromoAction, isVisiblePromoByAction } = require("%scripts/promo/promoActions.nut")
let { getPromoButtonConfig } = require("%scripts/promo/promoButtonsConfig.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { validateLink } = require("%scripts/onlineShop/url.nut")

::g_promo <- {
  PROMO_BUTTON_TYPE = {
    ARROW = "arrowButton"
    IMAGE = "imageButton"
    IMAGE_ROULETTE = "imageRoulette"
  }

  BUTTON_OUT_OF_DATE_DAYS = 15
  PERFORM_ACTON_NAME = "performAction"

  DEFAULT_TIME_SWITCH_SEC = 10
  DEFAULT_MANUAL_SWITCH_TIME_MULTIPLAYER = 2
  DEFAULT_REQ_STOP_PLAY_TIME_SONG_SEC = 60

  PLAYLIST_SONG_TIMER_TASK = -1

  defaultCollapsedIcon = loc("icon/news")
  defaultCollapsedText = ""

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

  function checkBlockReqEntitlement(block)
  {
    if (!("reqEntitlement" in block))
      return true

    return split_by_chars(block.reqEntitlement, "; ").findvalue(@(ent) ::has_entitlement(ent) == 1 ) != null
  }
}

::g_promo.checkOldRecordsOnInit <- function checkOldRecordsOnInit()
{
  let blk = ::loadLocalByAccount("seen")
  if (!blk)
    return

  foreach (blockName, convertTimeFunc in oldRecordsCheckTable)
  {
    let newBlk = ::DataBlock()
    let checkBlock = blk.getBlockByName(blockName)
    if (!checkBlock)
      continue

    for (local i = 0; i < checkBlock.paramCount(); i++)
    {
      let id = checkBlock.getParamName(i)
      let lastTimeSeen = checkBlock.getParamValue(i)
      let days = convertTimeFunc(lastTimeSeen)

      let minDay = time.getUtcDays() - BUTTON_OUT_OF_DATE_DAYS
      if (days > minDay)
        continue

      newBlk[id] <- lastTimeSeen
    }
    ::saveLocalByAccount("seen/" + blockName, newBlk)
  }
}

::g_promo.recievePromoBlk <- function recievePromoBlk()
{
  local customPromoBlk = ::get_gui_regional_blk()?.promo_block
  if (!::u.isDataBlock(customPromoBlk)) //compatibility with not exist or old gui_regional
  {
    let blk = ::get_game_settings_blk()
    customPromoBlk = blk?.promo_block
    if (!::u.isDataBlock(customPromoBlk))
      customPromoBlk = ::DataBlock()
  }
  let showAllPromo = ::g_promo.getShowAllPromoBlocks()

  let promoBlk = ::u.copy(customPromoBlk)
  let guiBlk = GUI.get()
  let staticPromoBlk = guiBlk?.static_promo_block

  if (!::u.isEmpty(staticPromoBlk))
  {
    //---Check on non-unique block names-----
    for (local i = 0; i < staticPromoBlk.blockCount(); i++)
    {
      let block = staticPromoBlk.getBlock(i)
      let blockName = block.getBlockName()
      let haveDouble = blockName in promoBlk
      if (!haveDouble || showAllPromo)
        promoBlk[blockName] <- ::u.copy(block)
    }
  }

  if (!::g_promo.needUpdate(promoBlk))
    return null
  return promoBlk
}

::g_promo.requestUpdate <- function requestUpdate()
{
  let promoBlk = ::g_promo.recievePromoBlk()
  if (::u.isEmpty(promoBlk))
    return false

  ::g_promo.checkOldRecordsOnInit()
  cache = ::DataBlock()
  cache.setFrom(promoBlk)
  actionParamsByBlockId.clear()
  return true
}

::g_promo.clearCache <- function clearCache()
{
  cache = null
}

::g_promo.getConfig <- function getConfig()
{
  return ::g_promo.cache
}

::g_promo.needUpdate <- function needUpdate(newData)
{
  local reqForceUpdate = false
  for (local i = 0; i < newData.blockCount(); i++)
  {
    let block = newData.getBlock(i)
    let id = block.getBlockName()

    let show = checkBlockVisibility(block)
    if (getTblValue(id, visibilityStatuses) != show)
    {
      visibilityStatuses[id] <- show
      reqForceUpdate = true
    }
  }

  return reqForceUpdate
}

::g_promo.createActionParamsData <- function createActionParamsData(actionName, paramsArray = null)
{
  return {
    action = actionName
    paramsArray = paramsArray || []
  }
}

::g_promo.gatherActionParamsData <- function gatherActionParamsData(block)
{
  let actionStr = getTblValue("action", block)
  if (::u.isEmpty(actionStr))
    return null

  let params = ::g_string.split(actionStr, paramsSeparator)
  local action = params.remove(0)
  return createActionParamsData(action, params)
}

::g_promo.setActionParamsData <- function setActionParamsData(blockId, actionOrActionData, paramsArray = null)
{
  if (::u.isString(actionOrActionData))
    actionOrActionData = createActionParamsData(actionOrActionData, paramsArray)

  actionParamsByBlockId[blockId] <- actionOrActionData
}

::g_promo.getActionParamsData <- function getActionParamsData(blockId)
{
  return getTblValue(blockId, actionParamsByBlockId)
}

::g_promo.generateBlockView <- function generateBlockView(block)
{
  let id = block.getBlockName()
  let view = ::buildTableFromBlk(block)
  let promoButtonConfig = getPromoButtonConfig(id)
  view.id <- id
  view.type <- ::g_promo.getType(block)
  view.collapsed <- ::g_promo.isCollapsed(id)? "yes" : "no"
  view.fillBlocks <- []
  view.h_ratio <- 1 / (block?.aspect_ratio ?? promoButtonConfig?.aspect_ratio ?? 1.0)

  let unseenIcon = promoButtonConfig?.getCustomSeenId()
  if (unseenIcon)
    view.unseenIcon <- unseenIcon
  view.notifyNew <- !unseenIcon && (view?.notifyNew ?? true)

  let isDebugModeEnabled = getShowAllPromoBlocks()
  let blocksCount = block.blockCount()
  let isMultiblock = block?.multiple ?? false
  view.isMultiblock <- isMultiblock

  view.radiobuttons <- []
  if (isMultiblock)
  {
    let value = ::to_integer_safe(multiblockData?[id]?.value ?? 0)
    let switchVal = ::to_integer_safe(block?.switch_time_sec || DEFAULT_TIME_SWITCH_SEC)
    let mSwitchVal = ::to_integer_safe(block?.manual_switch_time_multiplayer || DEFAULT_MANUAL_SWITCH_TIME_MULTIPLAYER)
    let lifeTimeVal = multiblockData?[id]?.life_time ?? switchVal
    multiblockData[id] <- { value = value,
                            switch_time_sec = switchVal,
                            manual_switch_time_multiplayer = mSwitchVal,
                            life_time = lifeTimeVal}
  }

  let requiredBlocks = isMultiblock? blocksCount : 1
  local hasImage = isMultiblock
  for (local i = 0; i < requiredBlocks; i++)
  {
    let blockId = view.id + (isMultiblock? ("_" + i) : "")
    let actionParamsKey = getActionParamsKey(blockId)

    let checkBlock = isMultiblock? block.getBlock(i) : block
    let fillBlock = ::buildTableFromBlk(checkBlock)
    fillBlock.blockId <- actionParamsKey

    let actionData = gatherActionParamsData(fillBlock) || gatherActionParamsData(block)
    if (actionData)
    {
      let action = actionData.action
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
      setActionParamsData(actionParamsKey, "url", [link, getTblValue("forceExternalBrowser", checkBlock, false)])
      fillBlock.action <- PERFORM_ACTON_NAME
      view.collapsedAction <- PERFORM_ACTON_NAME
    }

    local image = getImage(fillBlock)
    if (image == "" && i == 0)
      image = getImage(promoButtonConfig)
    if (image != "")
    {
      fillBlock.image <- image
      hasImage = true
    }

    local text = promoButtonConfig?.getText() ?? getViewText(fillBlock, isMultiblock ? "" : null)
    if (::u.isEmpty(text) && isMultiblock)
      text = getViewText(block)
    fillBlock.text <- text
    fillBlock.needAutoScroll <- getStringWidthPx(text, "fontNormal")
      > to_pixels("1@arrowButtonWidth-2@blockInterval") ? "yes" : "no"

    let showTextShade = !::is_chat_message_empty(text) || isDebugModeEnabled
    fillBlock.showTextShade <- showTextShade

    let isBlockSelected = isValueCurrentInMultiBlock(id, i)
    local show = checkBlockVisibility(checkBlock) && isBlockSelected
    if (view.type == PROMO_BUTTON_TYPE.ARROW && !showTextShade)
      show = false
    fillBlock.blockShow <- show

    fillBlock.h_ratio <- view.h_ratio
    view.fillBlocks.append(fillBlock)

    view.radiobuttons.append({selected = isBlockSelected})
  }

  if (!hasImage)
    view.h_ratio = 0

  if ("action" in view)
    delete view.action
  view.show <- checkBlockVisibility(block) && block?.pollId == null
  view.collapsedIcon <- getCollapsedIcon(view, id)
  view.collapsedText <- getCollapsedText(view, id)
  view.needUpdateByTimer <- view?.needUpdateByTimer ?? promoButtonConfig?.needUpdateByTimer

  return view
}

::g_promo.getCollapsedIcon <- function getCollapsedIcon(view, promoButtonId)
{
  local result = ""
  let icon = getPromoButtonConfig(promoButtonId)?.collapsedIcon
  if (icon)
    result = getTblValue(icon, view, icon) //can be set as param
  else
    result = ::g_language.getLocTextFromConfig(view, "collapsedIcon", defaultCollapsedIcon)

  return loc(result)
}

::g_promo.getCollapsedText <- function getCollapsedText(view, promoButtonId)
{
  local result = ""
  let text = getPromoButtonConfig(promoButtonId)?.collapsedText
  if (text)
    result = getTblValue(text, view, defaultCollapsedText) //can be set as param
  else
    result = ::g_language.getLocTextFromConfig(view, "collapsedText", defaultCollapsedText)

  return loc(result)
}

/**
 * First searches text for current language (e.g. "text_en", "text_ru").
 * If no such text found, tries to return text in "text" property.
 * If nothing find returns block id.
 */
::g_promo.getViewText <- function getViewText(view, defValue = null)
{
  return ::g_language.getLocTextFromConfig(view, "text", defValue)
}

::g_promo.getLinkText <- function getLinkText(view)
{
  return ::g_language.getLocTextFromConfig(view, "link", "")
}

::g_promo.getLinkBtnText <- function getLinkBtnText(view)
{
  return ::g_language.getLocTextFromConfig(view, "linkText", "")
}

::g_promo.getImage <- function getImage(view)
{
  return ::g_language.getLocTextFromConfig(view, "image", "")
}

::g_promo.checkBlockTime <- function checkBlockTime(block)
{
  let utcTime = ::get_charserver_time_sec()

  let startTime = getUTCTimeFromBlock(block, "startTime")
  if (startTime > 0 && startTime >= utcTime)
    return false

  let endTime = getUTCTimeFromBlock(block, "endTime")
  if (endTime > 0 && utcTime >= endTime)
    return false

  if (!::g_partner_unlocks.isPartnerUnlockAvailable(block?.partnerUnlock, block?.partnerUnlockDurationMin))
    return false

  // Block has no time restrictions.
  return true
}

::g_promo.checkBlockReqFeature <- function checkBlockReqFeature(block)
{
  if (!("reqFeature" in block))
    return true

  return hasAllFeatures(split_by_chars(block.reqFeature, "; "))
}

::g_promo.checkBlockUnlock <- function checkBlockUnlock(block)
{
  if (!("reqUnlock" in block))
    return true

  return ::g_unlocks.checkUnlockString(block.reqUnlock)
}

::g_promo.isVisibleByAction <- function isVisibleByAction(block)
{
  let actionData = gatherActionParamsData(block)
  if (!actionData)
    return true

  return isVisiblePromoByAction(actionData.action, actionData.paramsArray)
}

::g_promo.getCurrentValueInMultiBlock <- function getCurrentValueInMultiBlock(id)
{
  return multiblockData?[id]?.value ?? 0
}

::g_promo.isValueCurrentInMultiBlock <- function isValueCurrentInMultiBlock(id, value)
{
  return ::g_promo.getCurrentValueInMultiBlock(id) == value
}

::g_promo.checkBlockVisibility <- function checkBlockVisibility(block)
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

::g_promo.isLinkVisible <- function isLinkVisible(block)
{
  return ::u.isEmpty(block?.link) || hasFeature("AllowExternalLink")
}

::g_promo.getUTCTimeFromBlock <- function getUTCTimeFromBlock(block, timeProperty)
{
  let timeText = getTblValue(timeProperty, block, null)
  if (!::u.isString(timeText) || timeText.len() == 0)
    return -1
  return time.getTimestampFromStringUtc(timeText)
}

::g_promo.initWidgets <- function initWidgets(obj, widgetsTable, widgetsWithCounter = [])
{
  foreach(id, table in widgetsTable)
    widgetsTable[id] = ::g_promo.initNewWidget(id, obj, widgetsWithCounter)
}

::g_promo.getActionParamsKey <- function getActionParamsKey(id)
{
  return "perform_action_" + id
}

::g_promo.cutActionParamsKey <- function cutActionParamsKey(id)
{
  return ::g_string.cutPrefix(id, "perform_action_", id)
}

::g_promo.getType <- function getType(block)
{
  local res = getPromoButtonConfig(block.getBlockName())?.buttonType ?? PROMO_BUTTON_TYPE.ARROW
  if (block.blockCount() > 1)
    res = PROMO_BUTTON_TYPE.IMAGE_ROULETTE
  else if (getTblValue("image", block, "") != "")
    res = PROMO_BUTTON_TYPE.IMAGE

  return res
}

::g_promo.setButtonText <- function setButtonText(buttonObj, id, text = "")
{
  if (!checkObj(buttonObj))
    return

  let obj = buttonObj.findObject(id + "_text")
  if (checkObj(obj))
  {
    obj.setValue(text)
    obj.needAutoScroll = getStringWidthPx(text, "fontNormal")
      > to_pixels("1@arrowButtonWidth-2@blockInterval") ? "yes" : "no"
  }
}

::g_promo.getVisibilityById <- function getVisibilityById(id)
{
  return getTblValue(id, visibilityStatuses, false)
}

//----------- <NEW ICON WIDGET> ----------------------------
::g_promo.initNewWidget <- function initNewWidget(id, obj, widgetsWithCounter = [])
{
  if (isWidgetSeenById(id))
    return null

  local newIconWidget = null
  let widgetContainer = obj.findObject(id + "_new_icon_widget_container")
  if (checkObj(widgetContainer))
    newIconWidget = ::NewIconWidget(obj.getScene(), widgetContainer)
  return newIconWidget
}

::g_promo.isWidgetSeenById <- function isWidgetSeenById(id)
{
  let blk = ::loadLocalByAccount("seen/promo")
  return id in blk
}

::g_promo.setSimpleWidgetData <- function setSimpleWidgetData(widgetsTable, id, widgetsWithCounter = [])
{
  if (isInArray(id, widgetsWithCounter))
    return

  let blk = ::loadLocalByAccount("seen/promo")
  let table = ::buildTableFromBlk(blk)

  if (!(id in table))
    table[id] <- time.getUtcDays()

  if (getTblValue(id, widgetsTable) != null)
    widgetsTable[id].setWidgetVisible(false)

  updateSimpleWidgetsData(table)
}

::g_promo.updateSimpleWidgetsData <- function updateSimpleWidgetsData(table)
{
  let minDay = time.getUtcDays() - BUTTON_OUT_OF_DATE_DAYS
  let idOnRemoveArray = []
  let blk = ::DataBlock()
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
::g_promo.performAction <- function performAction(handler, obj)
{
  if (!checkObj(obj))
    return false

  let key = obj?.id
  let actionData = getActionParamsData(key)
  if (!actionData)
  {
    assert(false, "Promo: Not found action params by key " + (key ?? "NULL"))
    return false
  }

  return launchAction(actionData, handler, obj)
}

::g_promo.launchAction <- function launchAction(actionData, handler, obj)
{
  let action = actionData.action
  let actionFunc = getPromoAction(action)
  if (!actionFunc)
  {
    assert(false, "Promo: Not found action in actions table. Action " + action)
    log("Promo: Rest params of paramsArray")
    debugTableData(actionData)
    return false
  }

  actionFunc(handler, actionData.paramsArray, obj)
  return true
}
//---------------- </ACTIONS> -----------------------------

//-------------- <SHOW ALL CHECK BOX> ---------------------

/** Returns 'true' if user can use "Show All Promo Blocks" check box. */
::g_promo.canSwitchShowAllPromoBlocksFlag <- function canSwitchShowAllPromoBlocksFlag()
{
  return hasFeature("ShowAllPromoBlocks")
}

/** Returns 'true' is user can use check box and it is checked. */
::g_promo.getShowAllPromoBlocks <- function getShowAllPromoBlocks()
{
  return canSwitchShowAllPromoBlocksFlag() && showAllPromoBlocks
}

::g_promo.setShowAllPromoBlocks <- function setShowAllPromoBlocks(value)
{
  if (showAllPromoBlocks != value)
  {
    showAllPromoBlocks = value
    ::broadcastEvent("ShowAllPromoBlocksValueChanged")
  }
}

//-------------- </SHOW ALL CHECK BOX> --------------------

//--------------------- <TOGGLE> ----------------------------

::g_promo.toggleItem <- function toggleItem(toggleButtonObj)
{
  let promoButtonObj = toggleButtonObj.getParent()
  let toggled = isCollapsed(promoButtonObj.id)
  let newVal = changeToggleStatus(promoButtonObj.id, toggled)
  promoButtonObj.collapsed = newVal? "yes" : "no"
  toggleButtonObj.getScene().applyPendingChanges(false)
  ::move_mouse_on_obj(toggleButtonObj)
}

::g_promo.isCollapsed <- function isCollapsed(id)
{
  let blk = ::loadLocalByAccount("seen/promo_collapsed")
  return blk?[id] ?? false
}

::g_promo.changeToggleStatus <- function changeToggleStatus(id, value)
{
  let newValue = !value
  let blk = ::loadLocalByAccount("seen/promo_collapsed") || ::DataBlock()
  blk[id] = newValue

  ::saveLocalByAccount("seen/promo_collapsed", blk)
  return newValue
}

::g_promo.updateCollapseStatuses <- function updateCollapseStatuses(arr)
{
  let blk = ::loadLocalByAccount("seen/promo_collapsed")
  if (!blk)
    return

  let clearedBlk = ::DataBlock()
  foreach(id, status in blk)
  {
    if (isInArray(id, arr))
      continue

    clearedBlk[id] = status
  }

  ::saveLocalByAccount("seen/promo_collapsed", clearedBlk)
}

//-------------------- </TOGGLE> ----------------------------

//----------------- <RADIOBUTTONS> --------------------------

::g_promo.switchBlock <- function switchBlock(obj, promoHolderObj)
{
  if (!checkObj(promoHolderObj))
    return

  if (obj?.blockId == null || multiblockData?[obj.blockId] == null)
    return

  let promoButtonObj = promoHolderObj.findObject(obj.blockId)
  let value = obj.getValue()
  let prevValue = multiblockData[promoButtonObj.id].value
  if (prevValue >= 0)
  {
    let prevObj = promoButtonObj.findObject(::g_promo.getActionParamsKey($"{promoButtonObj.id}_{prevValue}"))
    if (prevObj?.isValid() ?? false)
      prevObj.animation = "hide"
  }

  let searchId = ::g_promo.getActionParamsKey(promoButtonObj.id + "_" + value)
  let curObj = promoButtonObj.findObject(searchId)
  curObj.animation = "show"
  multiblockData[promoButtonObj.id].value = value

  let curListObj = curObj.findObject("multiblock_radiobuttons_list")
  if (!checkObj(curListObj))
      return

  curListObj.setValue(value)
}

::g_promo.manualSwitchBlock <- function manualSwitchBlock(obj, promoHolderObj)
{
  if (!checkObj(promoHolderObj))
    return

  let pId = obj.blockId

  multiblockData[pId].life_time = multiblockData[pId].manual_switch_time_multiplayer * multiblockData[pId].switch_time_sec

  ::g_promo.switchBlock(obj, promoHolderObj)
}

::g_promo.selectNextBlock <- function selectNextBlock(obj, dt)
{
  if (!(obj?.id in multiblockData))
    return

  multiblockData[obj.id].life_time -= dt
  if (multiblockData[obj.id].life_time > 0)
    return

  multiblockData[obj.id].life_time = multiblockData[obj.id].switch_time_sec

  let listObj = obj.findObject("multiblock_radiobuttons_list")
  if (!checkObj(listObj))
    return

  let curVal = listObj.getValue()
  local nextVal = curVal + 1
  if (nextVal >= listObj.childrenCount())
    nextVal = 0
  listObj.setValue(nextVal)
}

//----------------- </RADIOBUTTONS> -------------------------

//------------------ <PLAYBACK> -----------------------------
::g_promo.enablePlayMenuMusic <- function enablePlayMenuMusic(playlistArray, tm)
{
  if (PLAYLIST_SONG_TIMER_TASK >= 0)
    return

  ::set_cached_music(CACHED_MUSIC_MENU, ::u.chooseRandom(playlistArray), "")
  PLAYLIST_SONG_TIMER_TASK = ::periodic_task_register(this, ::g_promo.requestTurnOffPlayMenuMusic, tm)
}

::g_promo.requestTurnOffPlayMenuMusic <- function requestTurnOffPlayMenuMusic(dt)
{
  if (PLAYLIST_SONG_TIMER_TASK < 0)
    return

  ::set_cached_music(CACHED_MUSIC_MENU, "", "")
  ::periodic_task_unregister(PLAYLIST_SONG_TIMER_TASK)
  PLAYLIST_SONG_TIMER_TASK = -1
}
//------------------- </PLAYBACK> ----------------------------
