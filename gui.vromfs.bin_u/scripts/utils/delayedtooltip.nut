from "%scripts/dagui_natives.nut" import is_mouse_last_time_used, periodic_task_unregister, periodic_task_register
from "%scripts/dagui_library.nut" import *
let { show_obj, setPopupMenuPosAndAlign } = require("%sqDagui/daguiUtil.nut")
let { getObjCenteringPosRC } = require("%sqDagui/guiBhv/guiBhvUtils.nut")
let { getTooltipType } = require("genericTooltipTypes.nut")
let { fillTooltip, addEventListenersTooltip } = require("genericTooltip.nut")
let globalCallbacks = require("%sqDagui/globalCallbacks/globalCallbacks.nut")
let { parse_json } = require("json")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { posNavigator } = require("%sqDagui/guiBhv/bhvPosNavigator.nut")
let { InContainersNavigator } = require("%sqDagui/guiBhv/bhvInContainersNavigator.nut")
let { canShowUnitContextMenu } = require("%scripts/unit/contextMenu.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")

const WAIT_ICON_ID = "__delayed_tooltip_wait_icon__"
const TOOLTIP_ID = "__delayed_tooltip_obj__"
const HINT_ID = "__delayed_tooltip_hint__"
let waitIconMarkup = "holdWaitPlace { id:t='{0}'; holdWaitIconBg {} holdWaitIcon { id:t='icon'; sector-angle-2:t = '0' } }"
  .subst(WAIT_ICON_ID)
let tooltipObjMarkup = "tooltipObj { id:t='{0}'; position:t='root'; order-popup:t='yes' }"
  .subst(TOOLTIP_ID)
let needActionAfterHoldPID = dagui_propid_add_name_id("need-action-after-hold")

local waitPlace = null
local tooltipData = null 
local tooltipPlace = null
local hintPlace = null
local hintTgt = null
let hasTooltip = @(obj) (obj?.tooltipId ?? "") != ""
local validateTimerId = -1

function hideWaitIcon() {
  show_obj(waitPlace, false)
  waitPlace = null
}

function hideTooltip() {
  show_obj(tooltipPlace, false)
  tooltipPlace = null
  tooltipData = null
}

function hideHint() {
  show_obj(hintPlace, false)
  hintPlace = null
}

function removeValidateTimer() {
  if (validateTimerId != -1)
    periodic_task_unregister(validateTimerId)
  validateTimerId = -1
}

function validateObjs(_) {
  if (hintTgt?.isValid() && hintTgt.isHovered()) 
    return
  hintTgt = null
  hideWaitIcon()
  hideTooltip()
  hideHint()
  removeValidateTimer()
}

function startValidateTimer() {
  if (validateTimerId < 0)
    validateTimerId = periodic_task_register({}, validateObjs, 1)
}

function getInfoObjForObj(obj, curInfoObj, infoObjId, ctor) {
  if (curInfoObj?.isValid() && curInfoObj.getParent().isVisible())
    return curInfoObj
  let rootObj = obj.getScene().getRoot()
  local sceneObj = obj
  while (true) {
    let parentObj = sceneObj.getParent()
    if (!parentObj?.isValid() || parentObj.isEqual(rootObj))
      break
    sceneObj = parentObj
  }

  let res = sceneObj.findObject(infoObjId)
  return res?.isValid() ? res : ctor(sceneObj)
}

let mkObjCtorByMarkup = @(objId, markup) function(sceneObj) {
  sceneObj.getScene().appendWithBlk(sceneObj, markup)
  return sceneObj.findObject(objId)
}

let waitIconCtor = mkObjCtorByMarkup(WAIT_ICON_ID, waitIconMarkup)
let getWaitIconForObj = @(obj) getInfoObjForObj(obj, waitPlace, WAIT_ICON_ID, waitIconCtor)
let tooltipCtor = mkObjCtorByMarkup(TOOLTIP_ID, tooltipObjMarkup)
let getTooltipForObj  = @(obj) getInfoObjForObj(obj, tooltipPlace, TOOLTIP_ID, tooltipCtor)
let getHintForObj  = @(obj) getInfoObjForObj(obj, hintPlace, HINT_ID,
  @(sceneObj) sceneObj.getScene().createElementByObject(sceneObj, "%gui/tooltips/holdTooltipHint.blk", "holdWaitPlace", null))

function showWaitIconForObj(obj) {
  let wIcon = getWaitIconForObj(obj)
  if (!wIcon)
    return

  if (waitPlace?.isValid() && !waitPlace.isEqual(wIcon))
    hideWaitIcon()

  let pos = getObjCenteringPosRC(obj)
  wIcon.left = pos[0].tostring()
  wIcon.top = pos[1].tostring()
  show_obj(wIcon, true)
  wIcon.findObject("icon")["sector-angle-2"] = "0"
  waitPlace = wIcon
}

function fillTooltipObj(tooltipObj, tooltipId, isOpenByHoldBtn = false) {
  let params = parse_json(tooltipId)
  params.isOpenByHoldBtn <- isOpenByHoldBtn
  if (type(params) != "table" || !("ttype" in params) || !("id" in params))
    return false

  let tooltipType = getTooltipType(params.ttype)
  let isSuccess = fillTooltip(tooltipObj, null, tooltipType, params.id, params)
  if (isSuccess)
    tooltipData = addEventListenersTooltip(tooltipObj, null, tooltipType, params.id, params)
  return isSuccess
}

function showTooltipForObj(obj, isOpenByHoldBtn = false) {
  let tooltipId = obj?.tooltipId
  let tooltip = getTooltipForObj(obj)
  if (!tooltip)
    return
  if (tooltipPlace?.isValid() && !tooltipPlace.isEqual(tooltip))
    hideTooltip()

  let isSuccess = fillTooltipObj(tooltip, tooltipId ?? "", isOpenByHoldBtn)
  show_obj(tooltip, isSuccess)
  tooltipPlace = tooltip

  if (!isSuccess)
    return

  if (!obj?.isValid()) {
    let objId = obj?.id 
    script_net_assert_once("DelayedTooltip", "Invalid object for tooltip")
    return
  }
  let align = obj.getFinalProp("tooltip-align") ?? ALIGN.RIGHT
  tooltip.getScene().applyPendingChanges(false)
  setPopupMenuPosAndAlign(obj, align, tooltip)
}

function showHintForObj(obj) {
  let hasContextMenu = canShowUnitContextMenu(obj)
  if(!hasTooltip(obj) && !hasContextMenu)
    return

  let hObj = getHintForObj(obj)
  hObj["hasContextMenuHint"] = hasContextMenu ? "yes" : "no"

  if (!hObj)
    return

  if (hintPlace?.isValid() && !hintPlace.isEqual(hObj))
    hideHint()

  let pos = obj.getPosRC()
  let size = obj.getSize()
  hObj.left = (pos[0] + size[0] / 2).tostring()
  hObj.top = pos[1].tostring()
  show_obj(hObj, true)
  hintPlace = hObj
}

function onPush(obj, listObj = null) {
  hideTooltip()
  let has = hasTooltip(obj)
  let propsObj = listObj ?? obj
  propsObj.set_prop_latent(needActionAfterHoldPID, has ? "no" : "yes")
  if (has)
    showWaitIconForObj(obj)
}

function onHoldStart(obj, _listObj = null) {
  hideWaitIcon()
  hideHint()
  if (hasTooltip(obj))
    showTooltipForObj(obj, true)
}

function onHoldStop(_obj, _listObj = null) {
  hideWaitIcon()
  hideTooltip()
}

local hoverHintTask = -1
function removeHintTask() {
  if (hoverHintTask != -1)
    periodic_task_unregister(hoverHintTask)
  hoverHintTask = -1
}
function restartHintTask(cb, delay = 1) {
  removeHintTask()
  hoverHintTask = periodic_task_register({}, cb, delay)
}

function onHover(obj) {
  hideWaitIcon()
  let isHovered = obj.isHovered()
  let isSame = hintTgt?.isValid() && hintTgt.isEqual(obj)
  if (isSame ? !isHovered : isHovered) {
    removeHintTask()
    hideHint()
    hideTooltip()
  }
  if (!isHovered)
    return

  startValidateTimer()
  hintTgt = obj
  restartHintTask(function(_) {
    removeHintTask()
    if (hintTgt?.isValid())
      if (is_mouse_last_time_used()) {
        if (hasTooltip(obj))
          showTooltipForObj(hintTgt)
      }
      else
        if(showConsoleButtons.get())
          showHintForObj(hintTgt)
  })
}

function getHoveredChild(listObj) {
  let isContainerBhv = listObj?.isContainerBhv
  let bhv = isContainerBhv? InContainersNavigator : posNavigator
  return bhv.getHoveredChild(listObj)?.hoveredObj
}

let mkListCb = @(func, emptyObjFunc = null) function(listObj, _params) {
  let tgt = getHoveredChild(listObj)
  if (tgt != null)
    func(tgt, listObj)
  else
    emptyObjFunc?(tgt, listObj)
}

let mkChildCb = @(func, emptyObjFunc = null) function(childObj, _params) {
  local tgt = childObj.getParent()
  while (tgt != null && "tooltipId" not in tgt)
    tgt = tgt.getParent()
  if (tgt != null)
    func(tgt, childObj)
  else
    emptyObjFunc?(tgt, childObj)
}

let actions = {
  delayedTooltipPush             = @(obj, _params) onPush(obj)
  delayedTooltipHoldStart        = @(obj, _params) onHoldStart(obj)
  delayedTooltipHoldStop         = @(obj, _params) onHoldStop(obj)
  delayedTooltipHover             = @(obj, _params) onHover(obj)

  delayedTooltipListPush         = mkListCb(onPush)
  delayedTooltipListHoldStart    = mkListCb(onHoldStart, onHoldStop)
  delayedTooltipListHoldStop     = mkListCb(onHoldStop, onHoldStop)

  delayedTooltipChildPush        = mkChildCb(onPush)
  delayedTooltipChildHoldStart   = mkChildCb(onHoldStart, onHoldStop)
  delayedTooltipChildHoldStop    = mkChildCb(onHoldStop, onHoldStop)
}

globalCallbacks.addTypes(actions.map(@(a) {
  onCb = a
}))

let paramsListSelf = {
  behavior = "button"
  on_pushed = "::gcb.delayedTooltipPush"
  on_hold_start = "::gcb.delayedTooltipHoldStart"
  on_hold_stop = "::gcb.delayedTooltipHoldStop"
}

let paramsListChild = {
  behavior = "PosNavigator"
  navigatorShortcuts = "yes"
  on_pushed = "::gcb.delayedTooltipListPush"
  on_hold_start = "::gcb.delayedTooltipListHoldStart"
  on_hold_stop = "::gcb.delayedTooltipListHoldStop"
}

let mkMarkup = @(list) " ".join(list.reduce(@(res, val, id) res.append($"{id}:t='{val}';"), []))
let markupTooltipHoldSelf = mkMarkup(paramsListSelf)
let markupTooltipHoldChild = mkMarkup(paramsListChild)

return {
  markupTooltipHoldSelf
  markupTooltipHoldChild
  hideWaitIcon
  hideTooltip
  delayedTooltipOnHover = onHover
}