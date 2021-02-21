local { getObjCenteringPosRC } = require("sqDagui/guiBhv/guiBhvUtils.nut")
local { getTooltipType } = require("genericTooltipTypes.nut")
local { fillTooltip } = require("genericTooltip.nut")
local globalCallbacks = require("sqDagui/globalCallbacks/globalCallbacks.nut")

const WAIT_ICON_ID = "__delayed_tooltip_wait_icon__"
const TOOLTIP_ID = "__delayed_tooltip_obj__"
const HINT_ID = "__delayed_tooltip_hint__"
local waitIconMarkup = "holdWaitPlace { id:t='{0}'; holdWaitIconBg {} holdWaitIcon { id:t='icon'; sector-angle-2:t = '0' } }"
  .subst(WAIT_ICON_ID)
local tooltipObjMarkup = "tooltipObj { id:t='{0}'; position:t='root'; order-popup:t='yes' }"
  .subst(TOOLTIP_ID)
local needActionAfterHoldPID = ::dagui_propid.add_name_id("need-action-after-hold")

local waitPlace = null
local tooltipPlace = null
local hintPlace = null
local hintTgt = null
local hasTooltip = @(obj) (obj?.tooltipId ?? "") != ""
local validateTimerId = -1

local function hideWaitIcon() {
  ::show_obj(waitPlace, false)
  waitPlace = null
}

local function hideTooltip() {
  ::show_obj(tooltipPlace, false)
  tooltipPlace = null
}

local function hideHint() {
  ::show_obj(hintPlace, false)
  hintPlace = null
}

local function removeValidateTimer() {
  if (validateTimerId != -1)
    ::periodic_task_unregister(validateTimerId)
  validateTimerId = -1
}

local function validateObjs(_) {
  if (hintTgt?.isValid() && hintTgt.isHovered()) //hold_stop or unhover event do not always received on destroy object
    return
  hintTgt = null
  hideWaitIcon()
  hideTooltip()
  hideHint()
  removeValidateTimer()
}

local function startValidateTimer() {
  if (validateTimerId < 0)
    validateTimerId = ::periodic_task_register({}, validateObjs, 1)
}

local function getInfoObjForObj(obj, curInfoObj, infoObjId, ctor) {
  if (curInfoObj?.isValid() && curInfoObj.getParent().isVisible())
    return curInfoObj
  local rootObj = obj.getScene().getRoot()
  local sceneObj = obj
  while(true) {
    local parentObj = sceneObj.getParent()
    if (!parentObj?.isValid() || parentObj.isEqual(rootObj))
      break
    sceneObj = parentObj
  }

  local res = sceneObj.findObject(infoObjId)
  return res?.isValid() ? res : ctor(sceneObj)
}

local mkObjCtorByMarkup = @(objId, markup) function(sceneObj) {
  sceneObj.getScene().appendWithBlk(sceneObj, markup)
  return sceneObj.findObject(objId)
}

local waitIconCtor = mkObjCtorByMarkup(WAIT_ICON_ID, waitIconMarkup)
local getWaitIconForObj = @(obj) getInfoObjForObj(obj, waitPlace, WAIT_ICON_ID, waitIconCtor)
local tooltipCtor = mkObjCtorByMarkup(TOOLTIP_ID, tooltipObjMarkup)
local getTooltipForObj  = @(obj) getInfoObjForObj(obj, tooltipPlace, TOOLTIP_ID, tooltipCtor)
local getHintForObj  = @(obj) getInfoObjForObj(obj, hintPlace, HINT_ID,
  @(sceneObj) sceneObj.getScene().createElementByObject(sceneObj, "gui/tooltips/holdTooltipHint.blk", "holdWaitPlace", null))

local function showWaitIconForObj(obj) {
  local wIcon = getWaitIconForObj(obj)
  if (!wIcon)
    return

  if (waitPlace?.isValid() && !waitPlace.isEqual(wIcon))
    hideWaitIcon()

  local pos = getObjCenteringPosRC(obj)
  wIcon.left = pos[0].tostring()
  wIcon.top = pos[1].tostring()
  ::show_obj(wIcon, true)
  wIcon.findObject("icon")["sector-angle-2"] = "0"
  waitPlace = wIcon
}

local function fillTooltipObj(tooltipObj, tooltipId) {
  local params = ::parse_json(tooltipId)
  if (::type(params) != "table" || !("ttype" in params) || !("id" in params))
    return false

  local tooltipType = getTooltipType(params.ttype)
  return fillTooltip(tooltipObj, null, tooltipType, params.id, params)
}

local function showTooltipForObj(obj) {
  local tooltip = getTooltipForObj(obj)
  if (!tooltip)
    return
  if (tooltipPlace?.isValid() && !tooltipPlace.isEqual(tooltip))
    hideTooltip()

  local isSuccess = fillTooltipObj(tooltip, obj?.tooltipId ?? "")
  ::show_obj(tooltip, isSuccess)
  tooltipPlace = tooltip

  if (!isSuccess)
    return

  local align = obj.getFinalProp("tooltip-align") ?? ALIGN.RIGHT
  tooltip.getScene().applyPendingChanges(false)
  ::g_dagui_utils.setPopupMenuPosAndAlign(obj, align, tooltip)
}

local function showHintForObj(obj) {
  local hObj = getHintForObj(obj)
  if (!hObj)
    return

  if (hintPlace?.isValid() && !hintPlace.isEqual(hObj))
    hideHint()

  local pos = obj.getPosRC()
  local size = obj.getSize()
  hObj.left = (pos[0] + size[0] / 2).tostring()
  hObj.top = pos[1].tostring()
  ::show_obj(hObj, true)
  hintPlace = hObj
}

local function onPush(obj, listObj = null) {
  hideTooltip()
  local has = hasTooltip(obj)
  local propsObj = listObj ?? obj
  propsObj.set_prop_latent(needActionAfterHoldPID, has ? "no" : "yes")
  if (has)
    showWaitIconForObj(obj)
}

local function onHoldStart(obj, listObj = null) {
  hideWaitIcon()
  hideHint()
  if (hasTooltip(obj))
    showTooltipForObj(obj)
}

local function onHoldStop(obj, listObj = null) {
  hideWaitIcon()
  hideTooltip()
}

local hoverHintTask = -1
local function removeHintTask() {
  if (hoverHintTask != -1)
    ::periodic_task_unregister(hoverHintTask)
  hoverHintTask = -1
}
local function restartHintTask(cb, delay = 1) {
  removeHintTask()
  hoverHintTask = ::periodic_task_register({}, cb, delay)
}

local function onHover(obj) {
  local isHovered = obj.isHovered()
  local isSame = hintTgt?.isValid() && hintTgt.isEqual(obj)
  if (isSame ? !isHovered : isHovered) {
    removeHintTask()
    hideHint()
  }
  if (!isHovered)
    return

  startValidateTimer()
  hintTgt = obj
  restartHintTask(function(_) {
    removeHintTask()
    if (hintTgt?.isValid() && hasTooltip(hintTgt))
      showHintForObj(hintTgt)
  })
}

local function getHoveredChild(listObj) {
  local total = listObj.childrenCount()
  for(local i = 0; i < total; i++) {
    local child = listObj.getChild(i)
    if (child?.isValid() && child.isHovered())
      return child
  }
  return null
}

local mkListCb = @(func, emptyObjFunc = null) function(listObj, params) {
  local tgt = getHoveredChild(listObj)
  if (tgt != null)
    func(tgt, listObj)
  else
    emptyObjFunc?(tgt, listObj)
}

local mkChildCb = @(func, emptyObjFunc = null) function(childObj, params) {
  local tgt = childObj.getParent()
  while(tgt != null && "tooltipId" not in tgt)
    tgt = tgt.getParent()
  if (tgt != null)
    func(tgt, childObj)
  else
    emptyObjFunc?(tgt, childObj)
}

local actions = {
  delayedTooltipPush             = @(obj, params) onPush(obj)
  delayedTooltipHoldStart        = @(obj, params) onHoldStart(obj)
  delayedTooltipHoldStop         = @(obj, params) onHoldStop(obj)
  delayedTooltipHover             = @(obj, params) onHover(obj)

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

local paramsListSelf = {
  behavior = "button"
  on_pushed = "::gcb.delayedTooltipPush"
  on_hold_start = "::gcb.delayedTooltipHoldStart"
  on_hold_stop = "::gcb.delayedTooltipHoldStop"
}

local paramsListChild = {
  behavior = "PosNavigator"
  navigatorShortcuts = "yes"
  on_pushed = "::gcb.delayedTooltipListPush"
  on_hold_start = "::gcb.delayedTooltipListHoldStart"
  on_hold_stop = "::gcb.delayedTooltipListHoldStop"
}

local mkMarkup = @(list) " ".join(list.reduce(@(res, val, id) res.append($"{id}:t='{val}';"), []))
local markupTooltipHoldSelf = mkMarkup(paramsListSelf)
local markupTooltipHoldChild = mkMarkup(paramsListChild)

return {
  markupTooltipHoldSelf
  markupTooltipHoldChild
  hideWaitIcon
  hideTooltip
}