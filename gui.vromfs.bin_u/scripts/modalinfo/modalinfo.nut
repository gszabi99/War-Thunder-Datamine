from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "dagor.workcycle" import setInterval, clearTimer
from "dagor.time" import get_time_msec
from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import is_mouse_last_time_used

let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { move_mouse_on_obj } = require("%scripts/sqDagui/daguiUtil.nut")
let { isActionsListOpen } = require("%scripts/actionsList/actionsListState.nut")

const MODAL_INFO_HOLDER_PATH = "%gui/modalInfo/modalInfoHolder.blk"
const MODAL_TOOLTIP_ID = "__delayed_modal_tooltip_obj__"
let modalTooltipObjMarkup = "tooltipObj { id:t='{0}'; position:t='root'; order-popup:t='yes' }"
  .subst(MODAL_TOOLTIP_ID)

let watchedObjects = []
local timer = null
local onTimerTick = null
local lastHolder = null

const HOLD_DELAY = 700
local holdTimer = null
local beginHoldTime = 0

function stopTimer() {
  if (timer != null)
    clearTimer(timer)
  timer = null
}

function startTimer() {
  if (timer == null)
    timer = setInterval(0.05, onTimerTick)
}

function getModalTooltipParent(obj) {
  if (obj?.isValid() && obj?.id == MODAL_TOOLTIP_ID)
    return obj

  let rootObj = obj.getScene().getRoot()
  local sceneObj = obj
  while (true) {
    let parentObj = sceneObj.getParent()
    if (!parentObj?.isValid() || parentObj.isEqual(rootObj))
      break
    sceneObj = parentObj
  }

  let res = sceneObj.findObject(MODAL_TOOLTIP_ID)
  if (res?.isValid())
    return res

  sceneObj.getScene().appendWithBlk(sceneObj, modalTooltipObjMarkup)
  return sceneObj.findObject(MODAL_TOOLTIP_ID)
}

let isUseGamePad = @() !is_mouse_last_time_used() && showConsoleButtons.get()

function updateTimer() {
  if (isUseGamePad() || watchedObjects.len() == 0)
    stopTimer()
  else
    startTimer()
}

function destroyOneModalInfo(modalData, removeHolder = true) {
  let { infoWnd, infoWndHolder } = modalData
  if (infoWnd?.isValid()) {
    let guiScene = infoWnd.getScene()
    broadcastEvent("RemoveOpenedModalInfo", { objs = [infoWnd] })
    guiScene.destroyElement(infoWnd)
  }
  if (removeHolder && infoWndHolder?.isValid()) {
    let guiScene = infoWndHolder.getScene()
    guiScene.destroyElement(infoWndHolder)
  }
}

function closeLastModalInfo(removeHolder = true) {
  clearTimer(holdTimer)
  if (watchedObjects.len() == 0)
    return

  let modalData = watchedObjects.pop()
  let { fakeInitiator, infoWndHolder } = modalData
  destroyOneModalInfo(modalData, false)
  if (fakeInitiator?.isValid())
    move_mouse_on_obj(fakeInitiator)

  if (infoWndHolder?.isValid()) {
    if (removeHolder) {
      let guiScene = infoWndHolder.getScene()
      guiScene.destroyElement(infoWndHolder)
    } else
      lastHolder = infoWndHolder
  }
}

function onHoldTimerTick() {
  if (get_time_msec() - beginHoldTime < HOLD_DELAY)
    return

  clearTimer(holdTimer)
  while (watchedObjects.len() > 0)
    closeLastModalInfo(watchedObjects.len() > 1)
}

function startHoldTimer() {
  beginHoldTime = get_time_msec()
  clearTimer(holdTimer)
  holdTimer = setInterval(0.05, onHoldTimerTick)
}

let handlerClass = class {
  constructor() {
  }

  function onBackPushed(_) {
    startHoldTimer()
  }

  function onBackClicked(_) {
    if (watchedObjects.len() == 0 && lastHolder != null) {
      let guiScene = lastHolder.getScene()
      guiScene.destroyElement(lastHolder)
      return
    }
    closeLastModalInfo()
  }
}

function createInfoPlaceBounds() {
  let width = to_pixels("@rw")
  let height = to_pixels("@rh")
  let left = to_pixels("@bw")
  let top = to_pixels("@bh")
  let right = left + width
  let bottom = top + height
  return {
    left, top, right, bottom, width, height,
  }
}

function getObjectBounds(obj) {
  let objPos = obj.getPosRC()
  let objSize = obj.getSize()
  let [ left, top ] = objPos
  let [ width, height ] = objSize
  let right = left + width
  let bottom = top + height
  return {
    id = obj.tag
    left, top, right, bottom, width, height,
    isOnObject = @(pos) !(pos.x < this.left || pos.y < this.top || pos.x > this.right || pos.y > this.bottom)
    update = function(l, t) {
      this.left = l
      this.top = t
      this.right = this.left + this.width
      this.bottom = this.top + this.height
    }
  }
}

function getCursorPos() {
  let cursorPosArr = get_dagui_mouse_cursor_pos()
  return {
    x = cursorPosArr[0]
    y = cursorPosArr[1]
  }
}

function getInfoWndPosition(initiatorObjBounds, modalInfoObjBounds, preferredSide, offsetX, offsetY) {
  let overlapDelta = to_pixels("1@blockInterval")
  let nestPlaceBounds = createInfoPlaceBounds()

  let nestObjTop = nestPlaceBounds.top
  let nestObjBtm = nestPlaceBounds.bottom
  let nestObjLft = nestPlaceBounds.left
  let nestObjRgt = nestPlaceBounds.right

  let mainObjTop = initiatorObjBounds.top
  let mainObjBtm = initiatorObjBounds.bottom
  let mainObjLft = initiatorObjBounds.left
  let mainObjRgt = initiatorObjBounds.right
  let mainObjWdh = initiatorObjBounds.width

  let infoObjHgt = modalInfoObjBounds.height
  let infoObjWdh = modalInfoObjBounds.width

  let maxX = max(nestObjLft, nestObjRgt - infoObjWdh)
  let maxY = max(nestObjTop, nestObjBtm - infoObjHgt)

  if (preferredSide == "center") {
    let posX = mainObjLft - (infoObjWdh - mainObjWdh) / 2
    let posY = mainObjTop - nestObjTop > nestObjBtm - mainObjBtm
      ? max(nestObjTop, mainObjTop - infoObjHgt)
      : min(nestObjBtm - infoObjHgt, mainObjBtm)
    let infoWndPos = [ clamp(posX + offsetX, nestObjLft, maxX), posY ]

    modalInfoObjBounds.update(infoWndPos[0], infoWndPos[1])
    return ",".join(infoWndPos)
  }

  let posRight = mainObjRgt - overlapDelta
  let posLeft = mainObjLft - infoObjWdh + overlapDelta
  let isFitsRight = posRight + infoObjWdh  < nestObjRgt
  let isFitsLeft = posLeft > nestObjLft
  let posX = preferredSide == "left"
    ? isFitsLeft ? posLeft : max(nestObjLft, posRight)
    : isFitsRight ? posRight : max(nestObjLft, posLeft)

  let isOverflowBottom = mainObjTop + infoObjHgt > nestObjBtm
  let posY = !isOverflowBottom ? mainObjTop : max(nestObjTop, nestObjBtm - infoObjHgt)

  let infoWndPos = [
    clamp(posX + offsetX, nestObjLft, maxX)
    clamp(posY + offsetY, nestObjTop, maxY)
  ]

  modalInfoObjBounds.update(infoWndPos[0], infoWndPos[1])
  return ",".join(infoWndPos)
}

function createInfoHolder(initiatorObj, handler) {
  initiatorObj.getScene().createElementByObject(initiatorObj, MODAL_INFO_HOLDER_PATH, "modalInfoHolder", handler)
  return {
    infoWnd = initiatorObj.findObject("modalInfoHolder")
  }
}

function createInfoHolderModal(initiatorObj, handler) {
  let guiScene = initiatorObj.getScene()
  let infoWndHolder = guiScene.loadModal("", "%gui/modalInfo/modalInfoHolderContent.blk", "tdiv", handlerClass())
  guiScene.createElementByObject(infoWndHolder, MODAL_INFO_HOLDER_PATH, "modalInfoHolder", handler)
  return {
    infoWnd = infoWndHolder.findObject("modalInfoHolder")
    infoWndHolder
  }
}

function isCursorInBounds(bounds, cursorPos) {
  return bounds.findindex(@(b) b?.isOnObject(cursorPos) ?? false) != null
}

function destroy() {
  if (watchedObjects.len() == 0)
    return

  while (watchedObjects.len() > 0)
    destroyOneModalInfo(watchedObjects.pop())

  updateTimer()
}

function removeInvalidWatchedObjects() {
  watchedObjects.replace(watchedObjects.filter(function(modalData) {
    let { infoWnd, infoWndHolder, initiatorObj } = modalData
    let isValidInitiator = initiatorObj?.isValid() && initiatorObj?.isVisible()
    let needRemove = !isValidInitiator || !infoWnd?.isValid() || !(infoWndHolder?.isValid() ?? true)
    if (needRemove)
      destroyOneModalInfo(modalData)
    return !needRemove
  }))
}


local isInAct = false
onTimerTick = function() {
  if (isInAct)
    return

  removeInvalidWatchedObjects()

  if (watchedObjects.len() == 0) {
    isInAct = false
    return
  }

  let cursorPos = getCursorPos()
  isInAct = true

  let modalData = watchedObjects[watchedObjects.len() - 1]
  let { initiatorObj, infoWndBounds, isCursorInBoundsOptional } = modalData
  let boundsArr = [infoWndBounds]
  if (initiatorObj.isValid())
    boundsArr.append(getObjectBounds(initiatorObj))
  if (!isCursorInBounds(boundsArr, cursorPos) && !(isCursorInBoundsOptional?() ?? false)) {
    watchedObjects.pop()
    destroyOneModalInfo(modalData)
  }
  isInAct = false
}

function addModalInfo(initiatorObj, tooltipNest, handler, tooltipType, id, params, isCursorInBoundsOptional) {
  let index = watchedObjects.findindex(@(o) o.initiatorObj?.isValid() &&
    (((o.params?.tooltipId != null) && (o.params.tooltipId == params?.tooltipId))
    || (o.id == id && o.initiatorObj.isEqual(initiatorObj))))
  if (index != null) {
    return { oldWnd = watchedObjects[index].infoWnd }
  }

  local parentIndex = -1
  let watchedCount = watchedObjects.len()
  for (local i = watchedCount-1; i >= 0; i--) {
    let data = watchedObjects[i]
    if (data.infoWnd.isValid() && data.infoWnd.isObjExist(initiatorObj)) {
      parentIndex = i
      break
    }
  }

  let isChildTooltip = parentIndex >= 0
  if (isChildTooltip) {
    tooltipNest = watchedObjects[parentIndex].infoWnd.findObject("next_modal_hints") ?? tooltipNest
  }

  let initiatorBounds = getObjectBounds(initiatorObj)
  let infosPlaceBounds = createInfoPlaceBounds()
  let needModalWindow = isUseGamePad()
  let { infoWnd, infoWndHolder = null } = needModalWindow
    ? createInfoHolderModal(tooltipNest, handler)
    : createInfoHolder(tooltipNest, handler)

  let prefSide = params?.modalPreferredSide ?? tooltipType.modalPreferredSide
  let maxHeight = prefSide != "center" ? null
    : max(initiatorBounds.top - infosPlaceBounds.top,
        infosPlaceBounds.bottom - initiatorBounds.bottom)

  let contentObj = infoWnd.findObject("modal_tooltip_content") ?? infoWnd
  tooltipType.fillTooltip(contentObj, handler, id, params.__update({ maxHeight, infoWnd }))
  infoWnd.getScene().applyPendingChanges(false)

  let infoWndBounds = getObjectBounds(infoWnd)
  let offsetX = tooltipType.modalOffsetX != "" ? to_pixels(tooltipType.modalOffsetX) : 0
  let offsetY = tooltipType.modalOffsetY != "" ? to_pixels(tooltipType.modalOffsetY) : 0
  infoWnd["pos"] = getInfoWndPosition(initiatorBounds, infoWndBounds, prefSide, offsetX, offsetY)
  broadcastEvent("ModalInfoPositioned", { infoWnd })
  local fakeInitiator = null
  if (infoWndHolder != null) {
    fakeInitiator = infoWndHolder.findObject("fakeInitiator")
    fakeInitiator["pos"] = $"{initiatorBounds.left}, {initiatorBounds.top}"
    fakeInitiator["size"] = $"{initiatorBounds.width}, {initiatorBounds.height}"
  }

  let watchedObj = {
    id
    infoWnd
    infoWndHolder
    initiatorObj
    infoWndBounds
    fakeInitiator
    isCursorInBoundsOptional
    params
    isChildTooltip
  }
  watchedObjects.append(watchedObj)
  updateTimer()
  return watchedObj
}

function closeModalInfo(isDelayed = false) {
  if (watchedObjects.len() == 0)
    return
  let bounds = watchedObjects.map(@(t) (t.infoWnd?.isValid() && t.infoWnd.isVisible()) ? t.infoWndBounds : null)
  if (isDelayed)
    bounds.extend(watchedObjects.map(@(t) (t.initiatorObj.isValid() && t.infoWnd?.isValid() && t.infoWnd.isVisible())
      ? getObjectBounds(t.initiatorObj)
      : null
    ))
  let isBounds = isCursorInBounds(bounds, getCursorPos())
  if (isBounds)
    return
  broadcastEvent("RemoveOpenedModalInfo", { objs = watchedObjects.map(@(t) t.infoWnd) })
}

function openModalInfo(initObj, handler, tooltipType, id, params, tooltipNest = null, isCursorInBoundsOptional = @() null) {
  if (isActionsListOpen.get() == true)
    return null

  return addModalInfo(initObj, tooltipNest ?? initObj.getParent(), handler, tooltipType, id, params, isCursorInBoundsOptional)
}

isActionsListOpen.subscribe(@(_) destroy())

return {
  openModalInfo
  closeModalInfo
  destroyModalInfo = destroy
  getModalInfoByUnitId = @(id) watchedObjects.findvalue(@(o) o.id == id)
  isUseGamePad
  getModalTooltipParent
}
