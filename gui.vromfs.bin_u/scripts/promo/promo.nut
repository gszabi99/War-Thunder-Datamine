//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

//checked for explicitness
#no-root-fallback
#explicit-this

let DataBlock = require("DataBlock")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { split_by_chars } = require("string")
let time = require("%scripts/time.nut")
let { hasAllFeatures } = require("%scripts/user/features.nut")
let promoConditions = require("%scripts/promo/promoConditions.nut")
let { getStringWidthPx } = require("%scripts/viewUtils/daguiFonts.nut")
let { getPromoAction, isVisiblePromoByAction } = require("%scripts/promo/promoActions.nut")
let { getPromoButtonConfig } = require("%scripts/promo/promoButtonsConfig.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { validateLink } = require("%scripts/onlineShop/url.nut")
let { showGuestEmailRegistration, needShowGuestEmailRegistration
} = require("%scripts/user/suggestionEmailRegistration.nut")
let { is_chat_message_empty } = require("chat")
let { checkUnlockString } = require("%scripts/unlocks/unlocksModule.nut")
let { split, cutPrefix } = require("%sqstd/string.nut")

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

  function checkBlockReqEntitlement(block) {
    if (!("reqEntitlement" in block))
      return true

    return split_by_chars(block.reqEntitlement, "; ").findvalue(@(ent) ::has_entitlement(ent) == 1) != null
  }
}

let function isMultiBlockActiveChanged(blockBlk) {
  if (!blockBlk?.multiple)
    return false
  let id = blockBlk.getBlockName()
  for (local i = 0; i < blockBlk.blockCount(); i++) {
    let isActiveBlock = this.checkBlockTime(blockBlk.getBlock(i))
    let isMultiblockDataActive = this.multiblockData?[id].subBlockInfo[i] ?? false
    if (isActiveBlock != isMultiblockDataActive)
      return true
  }
  return false
}

let function getActiveSubBlockCount(block) {
  local activeBlockCounter = 0
  if (!block?.multiple)
    return activeBlockCounter
  for (local i = 0; i < block.blockCount(); i++) {
    let isVisibleSubBlock = this.checkBlockTime(block.getBlock(i))
    if (isVisibleSubBlock)
      activeBlockCounter++
  }
  return activeBlockCounter
}

let function getFirstActiveSubBlockIndex(block) {
  for (local i = 0; i < block.blockCount(); i++)
    if (this.checkBlockTime(block.getBlock(i)))
      return i
  return -1
}

::g_promo.checkOldRecordsOnInit <- function checkOldRecordsOnInit() {
  let blk = ::loadLocalByAccount("seen")
  if (!blk)
    return

  foreach (blockName, convertTimeFunc in this.oldRecordsCheckTable) {
    let newBlk = DataBlock()
    let checkBlock = blk.getBlockByName(blockName)
    if (!checkBlock)
      continue

    for (local i = 0; i < checkBlock.paramCount(); i++) {
      let id = checkBlock.getParamName(i)
      let lastTimeSeen = checkBlock.getParamValue(i)
      let days = convertTimeFunc(lastTimeSeen)

      let minDay = time.getUtcDays() - this.BUTTON_OUT_OF_DATE_DAYS
      if (days > minDay)
        continue

      newBlk[id] <- lastTimeSeen
    }
    ::saveLocalByAccount("seen/" + blockName, newBlk)
  }
}

::g_promo.recievePromoBlk <- function recievePromoBlk() {
  local customPromoBlk = ::get_gui_regional_blk()?.promo_block
  if (!u.isDataBlock(customPromoBlk)) { //compatibility with not exist or old gui_regional
    let blk = ::get_game_settings_blk()
    customPromoBlk = blk?.promo_block
    if (!u.isDataBlock(customPromoBlk))
      customPromoBlk = DataBlock()
  }
  let showAllPromo = ::g_promo.getShowAllPromoBlocks()

  let promoBlk = u.copy(customPromoBlk)
  let guiBlk = GUI.get()
  let staticPromoBlk = guiBlk?.static_promo_block

  if (!u.isEmpty(staticPromoBlk)) {
    //---Check on non-unique block names-----
    for (local i = 0; i < staticPromoBlk.blockCount(); i++) {
      let block = staticPromoBlk.getBlock(i)
      let blockName = block.getBlockName()
      let haveDouble = blockName in promoBlk
      if (!haveDouble || showAllPromo)
        promoBlk[blockName] <- u.copy(block)
    }
  }

  if (!::g_promo.needUpdate(promoBlk))
    return null
  return promoBlk
}

::g_promo.requestUpdate <- function requestUpdate() {
  let promoBlk = ::g_promo.recievePromoBlk()
  if (u.isEmpty(promoBlk))
    return false

  ::g_promo.checkOldRecordsOnInit()
  this.cache = DataBlock()
  this.cache.setFrom(promoBlk)
  this.actionParamsByBlockId.clear()
  return true
}

::g_promo.clearCache <- function clearCache() {
  this.cache = null
}

::g_promo.getConfig <- function getConfig() {
  return ::g_promo.cache
}

::g_promo.needUpdate <- function needUpdate(newData) {
  local reqForceUpdate = false
  for (local i = 0; i < newData.blockCount(); i++) {
    let block = newData.getBlock(i)
    let id = block.getBlockName()

    let show = this.checkBlockVisibility(block)
    if (getTblValue(id, this.visibilityStatuses) != show) {
      this.visibilityStatuses[id] <- show
      reqForceUpdate = true
    }
    if (!reqForceUpdate && isMultiBlockActiveChanged(block))
      reqForceUpdate = true
  }

  return reqForceUpdate
}

::g_promo.createActionParamsData <- function createActionParamsData(actionName, paramsArray = null) {
  return {
    action = actionName
    paramsArray = paramsArray || []
  }
}

::g_promo.gatherActionParamsData <- function gatherActionParamsData(block) {
  let actionStr = getTblValue("action", block)
  if (u.isEmpty(actionStr))
    return null

  let params = split(actionStr, this.paramsSeparator)
  local action = params.remove(0)
  return this.createActionParamsData(action, params)
}

::g_promo.setActionParamsData <- function setActionParamsData(blockId, actionOrActionData, paramsArray = null) {
  if (u.isString(actionOrActionData))
    actionOrActionData = this.createActionParamsData(actionOrActionData, paramsArray)

  this.actionParamsByBlockId[blockId] <- actionOrActionData
}

::g_promo.getActionParamsData <- function getActionParamsData(blockId) {
  return getTblValue(blockId, this.actionParamsByBlockId)
}

::g_promo.generateBlockView <- function generateBlockView(block) {
  let id = block.getBlockName()
  let view = ::buildTableFromBlk(block)
  let promoButtonConfig = getPromoButtonConfig(id)
  let multiBlockTbl = {}
  view.id <- id
  view.collapsed <- ::g_promo.isCollapsed(id) ? "yes" : "no"
  view.fillBlocks <- []
  view.h_ratio <- 1 / (block?.aspect_ratio ?? promoButtonConfig?.aspect_ratio ?? 1.0)

  let unseenIcon = promoButtonConfig?.getCustomSeenId()
  if (unseenIcon)
    view.unseenIcon <- unseenIcon
  view.notifyNew <- !unseenIcon && (view?.notifyNew ?? true)

  let isDebugModeEnabled = this.getShowAllPromoBlocks()
  let blocksCount = block.blockCount()
  let isMultiblock = block?.multiple ?? false
  view.isMultiblock <- isMultiblock
  view.radiobuttons <- []

  if (isMultiblock) {
    let value = ::to_integer_safe(this.multiblockData?[id]?.value ?? 0)
    let switchVal = ::to_integer_safe(block?.switch_time_sec || this.DEFAULT_TIME_SWITCH_SEC)
    let mSwitchVal = ::to_integer_safe(block?.manual_switch_time_multiplayer || this.DEFAULT_MANUAL_SWITCH_TIME_MULTIPLAYER)
    let lifeTimeVal = this.multiblockData?[id]?.life_time ?? switchVal
    this.multiblockData[id] <- { value = value,
                            switch_time_sec = switchVal,
                            manual_switch_time_multiplayer = mSwitchVal,
                            life_time = lifeTimeVal }
  }

  view.type <- ::g_promo.getType(block)
  let requiredBlocks = isMultiblock ? blocksCount : 1
  local hasImage = isMultiblock
  local counter = 0
  for (local i = 0; i < requiredBlocks; i++) {
    let checkBlock = isMultiblock ? block.getBlock(i) : block
    let fillBlock = ::buildTableFromBlk(checkBlock)
    let isVisibleSubBlock = this.checkBlockTime(fillBlock)

    if (isMultiblock)
      multiBlockTbl[i] <- isVisibleSubBlock

    if (isMultiblock && !isVisibleSubBlock)
      continue

    let blockId = view.id + (isMultiblock ? ($"_{counter}") : "")
    let actionParamsKey = this.getActionParamsKey(blockId)
    fillBlock.blockId <- actionParamsKey

    let actionData = this.gatherActionParamsData(fillBlock) || this.gatherActionParamsData(block)
    if (actionData) {
      let action = actionData.action
      if (action == "url" && actionData.paramsArray.len())
        fillBlock.link <- validateLink(actionData.paramsArray[0])

      fillBlock.action <- this.PERFORM_ACTON_NAME
      view.collapsedAction <- this.PERFORM_ACTON_NAME
      this.setActionParamsData(actionParamsKey, actionData)
    }

    local link = this.getLinkText(fillBlock)
    if (u.isEmpty(link) && isMultiblock)
      link = this.getLinkText(block)
    if (!u.isEmpty(link)) {
      fillBlock.link <- link
      this.setActionParamsData(actionParamsKey, "url", [link, getTblValue("forceExternalBrowser", checkBlock, false)])
      fillBlock.action <- this.PERFORM_ACTON_NAME
      view.collapsedAction <- this.PERFORM_ACTON_NAME
    }

    local image = this.getImage(fillBlock)
    if (image == "" && i == 0)
      image = this.getImage(promoButtonConfig)
    if (image != "") {
      fillBlock.image <- image
      hasImage = true
    }

    local text = promoButtonConfig?.getText() ?? this.getViewText(fillBlock, isMultiblock ? "" : null)
    if (u.isEmpty(text) && isMultiblock)
      text = this.getViewText(block)
    fillBlock.text <- text
    fillBlock.needAutoScroll <- getStringWidthPx(text, "fontNormal")
      > to_pixels("1@arrowButtonWidth-2@blockInterval") ? "yes" : "no"

    let showTextShade = !is_chat_message_empty(text) || isDebugModeEnabled
    fillBlock.showTextShade <- showTextShade

    let isBlockSelected = this.isValueCurrentInMultiBlock(id, view.fillBlocks.len())
    local show = this.checkBlockVisibility(checkBlock) && isBlockSelected
    if (view.type == this.PROMO_BUTTON_TYPE.ARROW && !showTextShade)
      show = false
    fillBlock.blockShow <- show

    fillBlock.h_ratio <- view.h_ratio
    view.fillBlocks.append(fillBlock)

    counter += 1
    view.radiobuttons.append({ selected = isBlockSelected })
  }

  if (isMultiblock)
    this.multiblockData[id].subBlockInfo <- multiBlockTbl

  if (view.fillBlocks.len() == 1)
    view.radiobuttons = []

  if (!hasImage)
    view.h_ratio = 0

  if ("action" in view)
    delete view.action
  view.show <- this.checkBlockVisibility(block) && block?.pollId == null
  view.collapsedIcon <- this.getCollapsedIcon(view, id)
  view.collapsedText <- this.getCollapsedText(view, id)
  view.needUpdateByTimer <- view?.needUpdateByTimer ?? promoButtonConfig?.needUpdateByTimer

  return view
}

::g_promo.getCollapsedIcon <- function getCollapsedIcon(view, promoButtonId) {
  local result = ""
  let icon = getPromoButtonConfig(promoButtonId)?.collapsedIcon
  if (icon)
    result = getTblValue(icon, view, icon) //can be set as param
  else
    result = ::g_language.getLocTextFromConfig(view, "collapsedIcon", this.defaultCollapsedIcon)

  return loc(result)
}

::g_promo.getCollapsedText <- function getCollapsedText(view, promoButtonId) {
  local result = ""
  let text = getPromoButtonConfig(promoButtonId)?.collapsedText
  if (text)
    result = getTblValue(text, view, this.defaultCollapsedText) //can be set as param
  else
    result = ::g_language.getLocTextFromConfig(view, "collapsedText", this.defaultCollapsedText)

  return loc(result)
}

/**
 * First searches text for current language (e.g. "text_en", "text_ru").
 * If no such text found, tries to return text in "text" property.
 * If nothing find returns block id.
 */
::g_promo.getViewText <- function getViewText(view, defValue = null) {
  return ::g_language.getLocTextFromConfig(view, "text", defValue)
}

::g_promo.getLinkText <- function getLinkText(view) {
  return ::g_language.getLocTextFromConfig(view, "link", "")
}

::g_promo.getLinkBtnText <- function getLinkBtnText(view) {
  return ::g_language.getLocTextFromConfig(view, "linkText", "")
}

::g_promo.getImage <- function getImage(view) {
  return ::g_language.getLocTextFromConfig(view, "image", "")
}

::g_promo.checkBlockTime <- function checkBlockTime(block) {
  let utcTime = ::get_charserver_time_sec()

  let startTime = this.getUTCTimeFromBlock(block, "startTime")
  if (startTime > 0 && startTime >= utcTime)
    return false

  let endTime = this.getUTCTimeFromBlock(block, "endTime")
  if (endTime > 0 && utcTime >= endTime)
    return false

  if (!::g_partner_unlocks.isPartnerUnlockAvailable(block?.partnerUnlock, block?.partnerUnlockDurationMin))
    return false

  // Block has no time restrictions.
  return true
}

::g_promo.checkBlockReqFeature <- function checkBlockReqFeature(block) {
  if (!("reqFeature" in block))
    return true

  return hasAllFeatures(split_by_chars(block.reqFeature, "; "))
}

::g_promo.checkBlockUnlock <- function checkBlockUnlock(block) {
  if (!("reqUnlock" in block))
    return true

  return checkUnlockString(block.reqUnlock)
}

::g_promo.isVisibleByAction <- function isVisibleByAction(block) {
  let actionData = this.gatherActionParamsData(block)
  if (!actionData)
    return true

  return isVisiblePromoByAction(actionData.action, actionData.paramsArray)
}

::g_promo.getCurrentValueInMultiBlock <- function getCurrentValueInMultiBlock(id) {
  return this.multiblockData?[id]?.value ?? 0
}

::g_promo.isValueCurrentInMultiBlock <- function isValueCurrentInMultiBlock(id, value) {
  return ::g_promo.getCurrentValueInMultiBlock(id) == value
}

::g_promo.checkBlockVisibility <- function checkBlockVisibility(block) {
  return (::g_language.isAvailableForCurLang(block)
           && this.checkBlockReqFeature(block)
           && this.checkBlockReqEntitlement(block)
           && this.checkBlockUnlock(block)
           && this.checkBlockTime(block)
           && this.isVisibleByAction(block)
           && promoConditions.isVisibleByConditions(block)
           && this.isLinkVisible(block))
         || this.getShowAllPromoBlocks()
}

::g_promo.isLinkVisible <- function isLinkVisible(block) {
  return u.isEmpty(block?.link) || hasFeature("AllowExternalLink")
}

::g_promo.getUTCTimeFromBlock <- function getUTCTimeFromBlock(block, timeProperty) {
  let timeText = getTblValue(timeProperty, block, null)
  if (!u.isString(timeText) || timeText.len() == 0)
    return -1
  return time.getTimestampFromStringUtc(timeText)
}

::g_promo.initWidgets <- function initWidgets(obj, widgetsTable, widgetsWithCounter = []) {
  foreach (id, _table in widgetsTable)
    widgetsTable[id] = ::g_promo.initNewWidget(id, obj, widgetsWithCounter)
}

::g_promo.getActionParamsKey <- function getActionParamsKey(id) {
  return "perform_action_" + id
}

::g_promo.cutActionParamsKey <- function cutActionParamsKey(id) {
  return cutPrefix(id, "perform_action_", id)
}

::g_promo.getType <- function getType(block) {
  let blockCount = block.blockCount()
  let activeBlockCount = getActiveSubBlockCount(block)
  if (blockCount > 1 && activeBlockCount > 1)
    return this.PROMO_BUTTON_TYPE.IMAGE_ROULETTE
  if (blockCount == 1)
    block = block.getBlock(0)
  else if (activeBlockCount == 1)
    block = block.getBlock(getFirstActiveSubBlockIndex(block))

  if (getTblValue("image", block, "") != "")
    return this.PROMO_BUTTON_TYPE.IMAGE
  return getPromoButtonConfig(block.getBlockName())?.buttonType ?? this.PROMO_BUTTON_TYPE.ARROW
}

::g_promo.setButtonText <- function setButtonText(buttonObj, id, text = "") {
  if (!checkObj(buttonObj))
    return

  let obj = buttonObj.findObject(id + "_text")
  if (checkObj(obj)) {
    obj.setValue(text)
    obj.needAutoScroll = getStringWidthPx(text, "fontNormal")
      > to_pixels("1@arrowButtonWidth-2@blockInterval") ? "yes" : "no"
  }
}

::g_promo.getVisibilityById <- function getVisibilityById(id) {
  return getTblValue(id, this.visibilityStatuses, false)
}

//----------- <NEW ICON WIDGET> ----------------------------
::g_promo.initNewWidget <- function initNewWidget(id, obj, _widgetsWithCounter = []) {
  if (this.isWidgetSeenById(id))
    return null

  local newIconWidget = null
  let widgetContainer = obj.findObject(id + "_new_icon_widget_container")
  if (checkObj(widgetContainer))
    newIconWidget = ::NewIconWidget(obj.getScene(), widgetContainer)
  return newIconWidget
}

::g_promo.isWidgetSeenById <- function isWidgetSeenById(id) {
  let blk = ::loadLocalByAccount("seen/promo")
  return id in blk
}

::g_promo.setSimpleWidgetData <- function setSimpleWidgetData(widgetsTable, id, widgetsWithCounter = []) {
  if (isInArray(id, widgetsWithCounter))
    return

  let blk = ::loadLocalByAccount("seen/promo")
  let table = ::buildTableFromBlk(blk)

  if (!(id in table))
    table[id] <- time.getUtcDays()

  if (getTblValue(id, widgetsTable) != null)
    widgetsTable[id].setWidgetVisible(false)

  this.updateSimpleWidgetsData(table)
}

::g_promo.updateSimpleWidgetsData <- function updateSimpleWidgetsData(table) {
  let minDay = time.getUtcDays() - this.BUTTON_OUT_OF_DATE_DAYS
  let idOnRemoveArray = []
  let blk = DataBlock()
  foreach (id, day in table) {
    if (day < minDay) {
      idOnRemoveArray.append(id)
      continue
    }

    blk[id] = day
  }

  ::saveLocalByAccount("seen/promo", blk)
  this.updateCollapseStatuses(idOnRemoveArray)
}
//-------------- </NEW ICON WIDGET> ----------------------

//-------------- <ACTION> --------------------------------
::g_promo.performAction <- function performAction(handler, obj) {
  if (!checkObj(obj))
    return false

  let key = obj?.id
  let actionData = this.getActionParamsData(key)
  if (!actionData) {
    assert(false, "Promo: Not found action params by key " + (key ?? "NULL"))
    return false
  }

  if (actionData?.action == "url" && needShowGuestEmailRegistration()) {
      showGuestEmailRegistration()
      return false
  }

  return this.launchAction(actionData, handler, obj)
}

::g_promo.launchAction <- function launchAction(actionData, handler, obj) {
  let action = actionData.action
  let actionFunc = getPromoAction(action)
  if (!actionFunc) {
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
::g_promo.canSwitchShowAllPromoBlocksFlag <- function canSwitchShowAllPromoBlocksFlag() {
  return hasFeature("ShowAllPromoBlocks")
}

/** Returns 'true' is user can use check box and it is checked. */
::g_promo.getShowAllPromoBlocks <- function getShowAllPromoBlocks() {
  return this.canSwitchShowAllPromoBlocksFlag() && this.showAllPromoBlocks
}

::g_promo.setShowAllPromoBlocks <- function setShowAllPromoBlocks(value) {
  if (this.showAllPromoBlocks != value) {
    this.showAllPromoBlocks = value
    broadcastEvent("ShowAllPromoBlocksValueChanged")
  }
}

//-------------- </SHOW ALL CHECK BOX> --------------------

//--------------------- <TOGGLE> ----------------------------

::g_promo.toggleItem <- function toggleItem(toggleButtonObj) {
  let promoButtonObj = toggleButtonObj.getParent()
  let toggled = this.isCollapsed(promoButtonObj.id)
  let newVal = this.changeToggleStatus(promoButtonObj.id, toggled)
  promoButtonObj.collapsed = newVal ? "yes" : "no"
  toggleButtonObj.getScene().applyPendingChanges(false)
  ::move_mouse_on_obj(toggleButtonObj)
}

::g_promo.isCollapsed <- function isCollapsed(id) {
  let blk = ::loadLocalByAccount("seen/promo_collapsed")
  return blk?[id] ?? false
}

::g_promo.changeToggleStatus <- function changeToggleStatus(id, value) {
  let newValue = !value
  let blk = ::loadLocalByAccount("seen/promo_collapsed") || DataBlock()
  blk[id] = newValue

  ::saveLocalByAccount("seen/promo_collapsed", blk)
  return newValue
}

::g_promo.updateCollapseStatuses <- function updateCollapseStatuses(arr) {
  let blk = ::loadLocalByAccount("seen/promo_collapsed")
  if (!blk)
    return

  let clearedBlk = DataBlock()
  foreach (id, status in blk) {
    if (isInArray(id, arr))
      continue

    clearedBlk[id] = status
  }

  ::saveLocalByAccount("seen/promo_collapsed", clearedBlk)
}

//-------------------- </TOGGLE> ----------------------------

//----------------- <RADIOBUTTONS> --------------------------

::g_promo.switchBlock <- function switchBlock(obj, promoHolderObj) {
  if (!checkObj(promoHolderObj))
    return

  if (obj?.blockId == null || this.multiblockData?[obj.blockId] == null)
    return

  let promoButtonObj = promoHolderObj.findObject(obj.blockId)
  let value = obj.getValue()
  let prevValue = this.multiblockData[promoButtonObj.id].value
  if (prevValue >= 0) {
    let prevObj = promoButtonObj.findObject(::g_promo.getActionParamsKey($"{promoButtonObj.id}_{prevValue}"))
    if (prevObj?.isValid() ?? false)
      prevObj.animation = "hide"
  }

  let searchId = ::g_promo.getActionParamsKey(promoButtonObj.id + "_" + value)
  let curObj = promoButtonObj.findObject(searchId)
  curObj.animation = "show"
  this.multiblockData[promoButtonObj.id].value = value

  let curListObj = curObj.findObject("multiblock_radiobuttons_list")
  if (!checkObj(curListObj))
      return

  curListObj.setValue(value)
}

::g_promo.manualSwitchBlock <- function manualSwitchBlock(obj, promoHolderObj) {
  if (!checkObj(promoHolderObj))
    return

  let pId = obj.blockId

  this.multiblockData[pId].life_time = this.multiblockData[pId].manual_switch_time_multiplayer * this.multiblockData[pId].switch_time_sec

  ::g_promo.switchBlock(obj, promoHolderObj)
}

::g_promo.selectNextBlock <- function selectNextBlock(obj, dt) {
  let objId = obj?.id
  if (!(objId in this.multiblockData))
    return

  this.multiblockData[objId].life_time -= dt
  if (this.multiblockData[objId].life_time > 0)
    return

  this.multiblockData[objId].life_time = this.multiblockData[objId].switch_time_sec

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
::g_promo.enablePlayMenuMusic <- function enablePlayMenuMusic(playlistArray, tm) {
  if (this.PLAYLIST_SONG_TIMER_TASK >= 0)
    return

  ::set_cached_music(CACHED_MUSIC_MENU, u.chooseRandom(playlistArray), "")
  this.PLAYLIST_SONG_TIMER_TASK = ::periodic_task_register(this, ::g_promo.requestTurnOffPlayMenuMusic, tm)
}

::g_promo.requestTurnOffPlayMenuMusic <- function requestTurnOffPlayMenuMusic(_dt) {
  if (this.PLAYLIST_SONG_TIMER_TASK < 0)
    return

  ::set_cached_music(CACHED_MUSIC_MENU, "", "")
  ::periodic_task_unregister(this.PLAYLIST_SONG_TIMER_TASK)
  this.PLAYLIST_SONG_TIMER_TASK = -1
}

//------------------- </PLAYBACK> ----------------------------