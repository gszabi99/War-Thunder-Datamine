from "%scripts/dagui_natives.nut" import set_cached_music, has_entitlement, periodic_task_unregister, periodic_task_register
from "%scripts/dagui_library.nut" import *
let { isDataBlock, isEmpty, copy, isString, chooseRandom } = require("%sqStdLibs/helpers/u.nut")
let { convertBlk } = require("%sqstd/datablock.nut")
let DataBlock = require("DataBlock")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { split_by_chars } = require("string")
let time = require("%scripts/time.nut")
let { hasAllFeatures } = require("%scripts/user/features.nut")
let { isVisibleByConditions } = require("%scripts/promo/promoConditions.nut")
let { getStringWidthPx } = require("%scripts/viewUtils/daguiFonts.nut")
let { getPromoAction, isVisiblePromoByAction } = require("%scripts/promo/promoActions.nut")
let { getPromoButtonConfig } = require("%scripts/promo/promoButtonsConfig.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { validateLink } = require("%scripts/onlineShop/url.nut")
let { move_mouse_on_obj } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { showGuestEmailRegistration, needShowGuestEmailRegistration
} = require("%scripts/user/suggestionEmailRegistration.nut")
let { is_chat_message_empty } = require("chat")
let { checkUnlockString } = require("%scripts/unlocks/unlocksModule.nut")
let { split, cutPrefix } = require("%sqstd/string.nut")
let { get_charserver_time_sec } = require("chard")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { get_gui_regional_blk, get_game_settings_blk } = require("blkGetters")
let { isAvailableForCurLang, getLocTextFromConfig } = require("%scripts/langUtils/language.nut")
let newIconWidget = require("%scripts/newIconWidget.nut")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")
let { isPartnerUnlockAvailable } = require("%scripts/user/partnerUnlocks.nut")

const BUTTON_OUT_OF_DATE_DAYS = 15
const DEFAULT_TIME_SWITCH_SEC = 10
const DEFAULT_MANUAL_SWITCH_TIME_MULTIPLAYER = 2
const DEFAULT_REQ_STOP_PLAY_TIME_SONG_SEC = 60
const PERFORM_PROMO_ACTION_NAME = "performAction"

enum PROMO_BUTTON_TYPE {
  ARROW = "arrowButton"
  IMAGE = "imageButton"
  IMAGE_ROULETTE = "imageRoulette"
}

local cache = null
let getPromoConfig = @() cache

let multiblockData = {}



let actionParamsByBlockId = {}
let getActionParamsData = @(blockId) getTblValue(blockId, actionParamsByBlockId)

let createActionParamsData = @(actionName, paramsArray = null) {
  action = actionName
  paramsArray = paramsArray ?? []
}

function gatherPromoActionsParamsData(block) {
  let actionStr = getTblValue("action", block)
  if (isEmpty(actionStr))
    return null

  let params = split(actionStr, "; ")
  let action = params.remove(0)
  return createActionParamsData(action, params)
}

function setPromoActionsParamsData(blockId, actionOrActionData, paramsArray = null) {
  actionParamsByBlockId[blockId] <- isString(actionOrActionData)
    ? createActionParamsData(actionOrActionData, paramsArray)
    : actionOrActionData
}

function launchPromoAction(actionData, handler, obj) {
  let action = actionData.action
  let actionFunc = getPromoAction(action)
  if (!actionFunc) {
    assert(false, $"Promo: Not found action in actions table. Action {action}")
    log("Promo: Rest params of paramsArray")
    debugTableData(actionData)
    return false
  }

  actionFunc(handler, actionData.paramsArray, obj)
  return true
}

function performPromoAction(handler, obj) {
  if (!checkObj(obj))
    return false

  let key = obj?.id
  let actionData = getActionParamsData(key)
  if (!actionData) {
    assert(false, $"Promo: Not found action params by key {key ?? "NULL"}")
    return false
  }

  if (actionData?.action == "url" && needShowGuestEmailRegistration()) {
    showGuestEmailRegistration()
    return false
  }

  return launchPromoAction(actionData, handler, obj)
}

let getPromoActionParamsKey = @(id) $"perform_action_{id}"
let cutPromoActionParamsKey = @(idd) cutPrefix(idd, "perform_action_", idd)




local showAllPromoBlocks = false

let canSwitchShowAllPromoBlocksFlag = @() hasFeature("ShowAllPromoBlocks")

function setShowAllPromoBlocks(value) {
  if (showAllPromoBlocks != value) {
    showAllPromoBlocks = value
    broadcastEvent("ShowAllPromoBlocksValueChanged")
  }
}

let getShowAllPromoBlocks = @()
  canSwitchShowAllPromoBlocksFlag() && showAllPromoBlocks




function switchPromoBlock(obj, promoHolderObj) {
  if (!checkObj(promoHolderObj))
    return

  if (obj?.blockId == null || multiblockData?[obj.blockId] == null)
    return

  let promoButtonObj = promoHolderObj.findObject(obj.blockId)
  let value = obj.getValue()
  let prevValue = multiblockData[promoButtonObj.id].value
  if (prevValue >= 0) {
    let prevObj = promoButtonObj.findObject(getPromoActionParamsKey($"{promoButtonObj.id}_{prevValue}"))
    if (prevObj?.isValid() ?? false)
      prevObj.animation = "hide"
  }

  let searchId = getPromoActionParamsKey($"{promoButtonObj.id}_{value}")
  let curObj = promoButtonObj.findObject(searchId)
  curObj.animation = "show"
  multiblockData[promoButtonObj.id].value = value

  let curListObj = curObj.findObject("multiblock_radiobuttons_list")
  if (!checkObj(curListObj))
      return

  curListObj.setValue(value)
}

function manualSwitchPromoBlock(obj, promoHolderObj) {
  if (!checkObj(promoHolderObj))
    return

  let data = multiblockData[obj.blockId]
  data.life_time = data.manual_switch_time_multiplayer * data.switch_time_sec

  switchPromoBlock(obj, promoHolderObj)
}

function selectNextPromoBlock(obj, dt) {
  let objId = obj?.id
  if (objId not in multiblockData)
    return

  multiblockData[objId].life_time -= dt
  if (multiblockData[objId].life_time > 0)
    return

  multiblockData[objId].life_time = multiblockData[objId].switch_time_sec

  let listObj = obj.findObject("multiblock_radiobuttons_list")
  if (!checkObj(listObj))
    return

  let curVal = listObj.getValue()
  local nextVal = curVal + 1
  if (nextVal >= listObj.childrenCount())
    nextVal = 0
  listObj.setValue(nextVal)
}




local playlistSongTimerTask = -1

function requestTurnOffPlayMenuMusic(_dt) {
  if (playlistSongTimerTask < 0)
    return

  set_cached_music(CACHED_MUSIC_MENU, "", "")
  periodic_task_unregister(playlistSongTimerTask)
  playlistSongTimerTask = -1
}

function enablePromoPlayMenuMusic(playlistArray, periodSec) {
  if (playlistSongTimerTask >= 0)
    return

  set_cached_music(CACHED_MUSIC_MENU, chooseRandom(playlistArray), "")
  playlistSongTimerTask = periodic_task_register({}, requestTurnOffPlayMenuMusic, periodSec)
}




function isPromoCollapsed(id) {
  let blk = loadLocalByAccount("seen/promo_collapsed")
  return blk?[id] ?? false
}

function changeToggleStatus(id, value) {
  let newValue = !value
  let blk = loadLocalByAccount("seen/promo_collapsed") ?? DataBlock()
  blk[id] = newValue

  saveLocalByAccount("seen/promo_collapsed", blk)
  return newValue
}

function updateCollapseStatuses(arr) {
  let blk = loadLocalByAccount("seen/promo_collapsed")
  if (!blk)
    return

  let clearedBlk = DataBlock()
  foreach (id, status in blk) {
    if (isInArray(id, arr))
      continue

    clearedBlk[id] = status
  }

  saveLocalByAccount("seen/promo_collapsed", clearedBlk)
}

function togglePromoItem(toggleButtonObj) {
  let promoButtonObj = toggleButtonObj.getParent()
  let toggled = isPromoCollapsed(promoButtonObj.id)
  let newVal = changeToggleStatus(promoButtonObj.id, toggled)
  promoButtonObj.collapsed = newVal ? "yes" : "no"
  toggleButtonObj.getScene().applyPendingChanges(false)
  move_mouse_on_obj(toggleButtonObj)
}




function isWidgetSeenById(id) {
  let blk = loadLocalByAccount("seen/promo")
  return id in blk
}

function initNewWidget(id, obj) {
  if (isWidgetSeenById(id))
    return null

  let widgetContainer = obj.findObject($"{id}_new_icon_widget_container")
  return checkObj(widgetContainer) ? newIconWidget(obj.getScene(), widgetContainer)
    : null
}

function initWidgets(obj, widgetsTable) {
  foreach (id, _table in widgetsTable)
    widgetsTable[id] = initNewWidget(id, obj)
}

function updateSimpleWidgetsData(table) {
  let minDay = time.getUtcDays() - BUTTON_OUT_OF_DATE_DAYS
  let idOnRemoveArray = []
  let blk = DataBlock()
  foreach (id, day in table) {
    if (day < minDay) {
      idOnRemoveArray.append(id)
      continue
    }

    blk[id] = day
  }

  saveLocalByAccount("seen/promo", blk)
  updateCollapseStatuses(idOnRemoveArray)
}

function setSimpleWidgetData(widgetsTable, id, widgetsWithCounter = []) {
  if (isInArray(id, widgetsWithCounter))
    return

  let blk = loadLocalByAccount("seen/promo")
  let table = isDataBlock(blk) ? convertBlk(blk) : {}
  if (id not in table)
    table[id] <- time.getUtcDays()

  if (getTblValue(id, widgetsTable) != null)
    widgetsTable[id].setWidgetVisible(false)

  updateSimpleWidgetsData(table)
}




let oldRecordsCheckTable = {
  promo = @(tm) tm
}

function checkOldRecordsOnInit() {
  let blk = loadLocalByAccount("seen")
  if (!blk)
    return

  foreach (blockName, convertTimeFunc in oldRecordsCheckTable) {
    let newBlk = DataBlock()
    let checkBlock = blk.getBlockByName(blockName)
    if (!checkBlock)
      continue

    for (local i = 0; i < checkBlock.paramCount(); ++i) {
      let id = checkBlock.getParamName(i)
      let lastTimeSeen = checkBlock.getParamValue(i)
      let days = convertTimeFunc(lastTimeSeen)

      let minDay = time.getUtcDays() - BUTTON_OUT_OF_DATE_DAYS
      if (days > minDay)
        continue

      newBlk[id] <- lastTimeSeen
    }
    saveLocalByAccount($"seen/{blockName}", newBlk)
  }
}

function getUTCTimeFromBlock(block, timeProperty) {
  let timeText = getTblValue(timeProperty, block, null)
  if (!isString(timeText) || timeText.len() == 0)
    return -1
  return time.getTimestampFromStringUtc(timeText)
}

function checkBlockTime(block) {
  let utcTime = get_charserver_time_sec()
  let startTime = getUTCTimeFromBlock(block, "startTime")
  if (startTime > 0 && startTime >= utcTime)
    return false

  let endTime = getUTCTimeFromBlock(block, "endTime")
  if (endTime > 0 && utcTime >= endTime)
    return false

  if (!isPartnerUnlockAvailable(block?.partnerUnlock, block?.partnerUnlockDurationMin))
    return false

  
  return true
}

function isMultiBlockActiveChanged(blockBlk) {
  if (!blockBlk?.multiple)
    return false

  let id = blockBlk.getBlockName()
  for (local i = 0; i < blockBlk.blockCount(); ++i) {
    let isActiveBlock = checkBlockTime(blockBlk.getBlock(i))
    let isMultiblockDataActive = multiblockData?[id].subBlockInfo[i] ?? false
    if (isActiveBlock != isMultiblockDataActive)
      return true
  }
  return false
}

function checkPromoBlockReqEntitlement(block) {
  if ("reqEntitlement" not in block)
    return true

  return split_by_chars(block.reqEntitlement, "; ")
    .findvalue(@(ent) has_entitlement(ent) == 1) != null
}

function checkPromoBlockReqFeature(block) {
  if ("reqFeature" not in block)
    return true

  return hasAllFeatures(split_by_chars(block.reqFeature, "; "))
}

function isPromoVisibleByAction(block) {
  let actionData = gatherPromoActionsParamsData(block)
  if (!actionData)
    return true

  return isVisiblePromoByAction(actionData.action, actionData.paramsArray)
}

let checkPromoBlockUnlock = @(block)
  ("reqUnlock" in block) ? checkUnlockString(block.reqUnlock) : true

let isPromoLinkVisible = @(block)
  isEmpty(block?.link) || hasFeature("AllowExternalLink")

let checkBlockVisibility = @(block) (isAvailableForCurLang(block)
  && checkPromoBlockReqFeature(block)
  && checkPromoBlockReqEntitlement(block)
  && checkPromoBlockUnlock(block)
  && checkBlockTime(block)
  && isPromoVisibleByAction(block)
  && isVisibleByConditions(block)
  && isPromoLinkVisible(block)) || getShowAllPromoBlocks()

let visibilityStatuses = {}
let getPromoVisibilityById = @(id) getTblValue(id, visibilityStatuses, false)

function needUpdate(newData) {
  local reqForceUpdate = false
  for (local i = 0; i < newData.blockCount(); ++i) {
    let block = newData.getBlock(i)
    let id = block.getBlockName()

    let show = checkBlockVisibility(block)
    if (getTblValue(id, visibilityStatuses) != show) {
      visibilityStatuses[id] <- show
      reqForceUpdate = true
    }
    if (!reqForceUpdate && isMultiBlockActiveChanged(block))
      reqForceUpdate = true
  }

  return reqForceUpdate
}

function receivePromoBlk() {
  local customPromoBlk = get_gui_regional_blk()?.promo_block
  
  if (!isDataBlock(customPromoBlk)) {
    let blk = get_game_settings_blk()
    customPromoBlk = blk?.promo_block
    if (!isDataBlock(customPromoBlk))
      customPromoBlk = DataBlock()
  }

  let showAllPromo = getShowAllPromoBlocks()
  let promoBlk = copy(customPromoBlk)
  let guiBlk = GUI.get()
  let staticPromoBlk = guiBlk?.static_promo_block
  if (isDataBlock(staticPromoBlk)) {
    
    for (local i = 0; i < staticPromoBlk.blockCount(); ++i) {
      let block = staticPromoBlk.getBlock(i)
      let blockName = block.getBlockName()
      let haveDouble = blockName in promoBlk
      if (!haveDouble || showAllPromo)
        promoBlk[blockName] <- copy(block)
    }
  }

  if (!needUpdate(promoBlk))
    return null
  return promoBlk
}

function requestPromoUpdate() {
  let promoBlk = receivePromoBlk()
  if (isEmpty(promoBlk))
    return false

  checkOldRecordsOnInit()
  cache = DataBlock()
  cache.setFrom(promoBlk)
  actionParamsByBlockId.clear()
  return true
}

function getFirstActiveSubBlockIndex(block) {
  for (local i = 0; i < block.blockCount(); ++i)
    if (checkBlockTime(block.getBlock(i)))
      return i
  return -1
}

function getActiveSubBlockCount(block) {
  local activeBlockCounter = 0
  if (!block?.multiple)
    return activeBlockCounter

  for (local i = 0; i < block.blockCount(); ++i) {
    let isVisibleSubBlock = checkBlockTime(block.getBlock(i))
    if (isVisibleSubBlock)
      ++activeBlockCounter
  }
  return activeBlockCounter
}

function getType(block) {
  let blockCount = block.blockCount()
  let activeBlockCount = getActiveSubBlockCount(block)
  if (blockCount > 1 && activeBlockCount > 1)
    return PROMO_BUTTON_TYPE.IMAGE_ROULETTE

  if (blockCount == 1)
    block = block.getBlock(0)
  else if (activeBlockCount == 1)
    block = block.getBlock(getFirstActiveSubBlockIndex(block))

  if (getTblValue("image", block, "") != "")
    return PROMO_BUTTON_TYPE.IMAGE
  return getPromoButtonConfig(block.getBlockName())?.buttonType ?? PROMO_BUTTON_TYPE.ARROW
}

function checkMultiVisibleBlocks(block) {
  local countVisible = 0
  let blocksCount = block.blockCount()
  for (local i = 0; i < blocksCount; ++i)
    if (checkBlockTime(convertBlk(block.getBlock(i))))
      ++countVisible
  return countVisible > 1
}

let defaultCollapsedIcon = loc("icon/news")

function getPromoCollapsedIcon(view, promoButtonId) {
  let icon = getPromoButtonConfig(promoButtonId)?.collapsedIcon
  let res = (icon != null) ? getTblValue(icon, view, icon) 
    : getLocTextFromConfig(view, "collapsedIcon", defaultCollapsedIcon)
  return loc(res)
}

function getPromoCollapsedText(view, promoButtonId) {
  let text = getPromoButtonConfig(promoButtonId)?.collapsedText
  let res = (text != null) ? getTblValue(text, view, "") 
    : getLocTextFromConfig(view, "collapsedText", "")
  return loc(res)
}




let getViewText = @(view, defValue = null) getLocTextFromConfig(view, "text", defValue)

let getImage = @(view) getLocTextFromConfig(view, "image", "")

function getPromoLinkText(view) {
  let keyPostfix = getCurCircuitOverride("linkForPopupPostfix", "")
  return keyPostfix != "" ? (view?[$"link{keyPostfix}"] ?? "")
    : getLocTextFromConfig(view, "link", "")
}

let getPromoLinkBtnText = @(view) getLocTextFromConfig(view, "linkText", "")

let isValueCurrentInMultiBlock = @(id, value)
  (multiblockData?[id].value ?? 0) == value

function generatePromoBlockView(block) {
  let id = block.getBlockName()
  let view = convertBlk(block)
  let promoButtonConfig = getPromoButtonConfig(id)
  let multiBlockTbl = {}
  view.id <- id
  view.collapsed <- isPromoCollapsed(id) ? "yes" : "no"
  view.fillBlocks <- []
  view.h_ratio <- 1 / (block?.aspect_ratio ?? promoButtonConfig?.aspect_ratio ?? 1.0)

  let unseenIcon = promoButtonConfig?.getCustomSeenId()
  if (unseenIcon)
    view.unseenIcon <- unseenIcon
  view.notifyNew <- !unseenIcon && (view?.notifyNew ?? true)

  let isDebugModeEnabled = getShowAllPromoBlocks()
  let blocksCount = block.blockCount()
  let isMultiblock = block?.multiple ?? false
  let hasMultiVisibleBlocks = isMultiblock ? checkMultiVisibleBlocks(block) : false
  view.isMultiblock <- hasMultiVisibleBlocks
  view.radiobuttons <- []

  if (isMultiblock) {
    let value = to_integer_safe(multiblockData?[id]?.value ?? 0)
    let switchVal = to_integer_safe(block?.switch_time_sec
      || DEFAULT_TIME_SWITCH_SEC)
    let mSwitchVal = to_integer_safe(block?.manual_switch_time_multiplayer
      || DEFAULT_MANUAL_SWITCH_TIME_MULTIPLAYER)
    let lifeTimeVal = multiblockData?[id].life_time ?? switchVal
    multiblockData[id] <- {
      value = value,
      switch_time_sec = switchVal,
      manual_switch_time_multiplayer = mSwitchVal,
      life_time = lifeTimeVal
    }
  }

  view.type <- getType(block)
  let requiredBlocks = isMultiblock ? blocksCount : 1
  local hasImage = isMultiblock
  local counter = 0
  for (local i = 0; i < requiredBlocks; ++i) {
    let checkBlock = isMultiblock ? block.getBlock(i) : block
    let fillBlock = convertBlk(checkBlock)
    let isVisibleSubBlock = checkBlockTime(fillBlock)

    if (isMultiblock)
      multiBlockTbl[i] <- isVisibleSubBlock

    if (isMultiblock && !isVisibleSubBlock)
      continue

    let blockId = view.id + (hasMultiVisibleBlocks ? $"_{counter}" : "")
    let actionParamsKey = getPromoActionParamsKey(blockId)
    fillBlock.blockId <- actionParamsKey

    let actionData = gatherPromoActionsParamsData(fillBlock) || gatherPromoActionsParamsData(block)
    if (actionData) {
      let action = actionData.action
      if (action == "url" && actionData.paramsArray.len())
        fillBlock.link <- validateLink(actionData.paramsArray[0])

      fillBlock.action <- PERFORM_PROMO_ACTION_NAME
      view.collapsedAction <- PERFORM_PROMO_ACTION_NAME
      setPromoActionsParamsData(actionParamsKey, actionData)
    }

    local link = getPromoLinkText(fillBlock)
    if (isEmpty(link) && isMultiblock)
      link = getPromoLinkText(block)
    if (!isEmpty(link)) {
      fillBlock.link <- link
      setPromoActionsParamsData(actionParamsKey, "url", [link, getTblValue("forceExternalBrowser", checkBlock, false)])
      fillBlock.action <- PERFORM_PROMO_ACTION_NAME
      view.collapsedAction <- PERFORM_PROMO_ACTION_NAME
    }

    local image = getImage(fillBlock)
    if (image == "" && i == 0)
      image = getImage(promoButtonConfig)
    if (image != "") {
      fillBlock.image <- image
      hasImage = true
    }

    local text = promoButtonConfig?.getText() ?? getViewText(fillBlock, isMultiblock ? "" : null)
    if (isEmpty(text) && isMultiblock)
      text = getViewText(block)
    fillBlock.text <- text
    fillBlock.needAutoScroll <- getStringWidthPx(text, "fontNormal")
      > to_pixels("1@arrowButtonWidth-2@blockInterval") ? "yes" : "no"

    let showTextShade = !is_chat_message_empty(text) || isDebugModeEnabled
    fillBlock.showTextShade <- showTextShade

    let isBlockSelected = isValueCurrentInMultiBlock(id, view.fillBlocks.len())
    local show = checkBlockVisibility(checkBlock) && isBlockSelected
    if (view.type == PROMO_BUTTON_TYPE.ARROW && !showTextShade)
      show = false
    fillBlock.blockShow <- show

    fillBlock.h_ratio <- view.h_ratio
    view.fillBlocks.append(fillBlock)

    counter += 1
    view.radiobuttons.append({ selected = isBlockSelected })
  }

  if (isMultiblock)
    multiblockData[id].subBlockInfo <- multiBlockTbl

  if (view.fillBlocks.len() == 1)
    view.radiobuttons = []

  if (!hasImage)
    view.h_ratio = 0

  view?.$rawdelete("action")
  view.show <- checkBlockVisibility(block) && block?.pollId == null
  view.collapsedIcon <- getPromoCollapsedIcon(view, id)
  view.collapsedText <- getPromoCollapsedText(view, id)
  view.needUpdateByTimer <- view?.needUpdateByTimer ?? promoButtonConfig?.needUpdateByTimer

  return view
}

function setPromoButtonText(buttonObj, id, text = "") {
  if (!checkObj(buttonObj))
    return

  let obj = buttonObj.findObject($"{id}_text")
  if (checkObj(obj)) {
    obj.setValue(text)
    obj.needAutoScroll = getStringWidthPx(text, "fontNormal")
      > to_pixels("1@arrowButtonWidth-2@blockInterval") ? "yes" : "no"
  }
}

return {
  PERFORM_PROMO_ACTION_NAME
  performPromoAction
  launchPromoAction
  getPromoActionParamsKey
  cutPromoActionParamsKey
  gatherPromoActionsParamsData
  setPromoActionsParamsData
  isPromoVisibleByAction
  getPromoVisibilityById
  checkPromoBlockUnlock
  checkPromoBlockReqEntitlement
  checkPromoBlockReqFeature
  isPromoLinkVisible
  getPromoLinkBtnText
  getPromoCollapsedIcon
  getPromoCollapsedText
  isPromoCollapsed
  togglePromoItem
  setPromoButtonText
  generatePromoBlockView
  initWidgets
  setSimpleWidgetData
  isWidgetSeenById
  enablePromoPlayMenuMusic
  DEFAULT_REQ_STOP_PLAY_TIME_SONG_SEC
  getPromoConfig
  requestPromoUpdate
  selectNextPromoBlock
  manualSwitchPromoBlock
  switchPromoBlock
  getShowAllPromoBlocks
  setShowAllPromoBlocks
  canSwitchShowAllPromoBlocksFlag
}