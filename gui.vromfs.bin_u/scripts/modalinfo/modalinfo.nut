from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import is_mouse_last_time_used
let { setInterval, clearTimer } = require("dagor.workcycle")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { move_mouse_on_obj } = require("%sqDagui/daguiUtil.nut")
let { isActionsListOpen } = require("%scripts/actionsList/actionsListState.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_time_msec } = require("dagor.time")

const MODAL_INFO_HOLDER_PATH = "%gui/modalInfo/modalInfoHolder.blk"

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

let isUseGamePad = @() !is_mouse_last_time_used() && showConsoleButtons.get()

function updateTimer() {
  if (isUseGamePad() || watchedObjects.len() == 0)
    stopTimer()
  else
    startTimer()
}

function closeLastModalInfo(removeHolder = true) {
  clearTimer(holdTimer)
  if (watchedObjects.len() == 0)
    return

  let { fakeInitiator, infoWndHolder, infoWnd } = watchedObjects.pop()
  broadcastEvent("RemoveOpenedModalInfo", { objs = [infoWnd] })

  local guiScene = null
  if (infoWnd.isValid()) {
    guiScene = infoWnd.getScene()
    guiScene.destroyElement(infoWnd)
  }
  if (fakeInitiator.isValid())
    move_mouse_on_obj(fakeInitiator)

  if (infoWndHolder?.isValid()) {
    if (removeHolder) {
      guiScene = guiScene ?? infoWndHolder.getScene()
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
      ? mainObjTop - infoObjHgt
      : mainObjBtm
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

function createInfoHolder(initiatorObj) {
  let holderParent = watchedObjects.len() > 0 ? watchedObjects[watchedObjects.len() - 1].infoWnd : null
  let parentObj = holderParent ?? initiatorObj
  parentObj.getScene().createElementByObject(parentObj, MODAL_INFO_HOLDER_PATH, "modalInfoHolder", null)
  return {
    infoWnd = parentObj.findObject("modalInfoHolder")
  }
}

function createInfoHolderModal(initiatorObj) {
  let guiScene = initiatorObj.getScene()
  let infoWndHolder = guiScene.loadModal("", "%gui/modalInfo/modalInfoHolderContent.blk", "tdiv", handlerClass())
  guiScene.createElementByObject(infoWndHolder, MODAL_INFO_HOLDER_PATH, "modalInfoHolder", null)
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

  let infoWnds = watchedObjects.map(@(t) t.infoWnd)
  infoWnds.each(function(infoWnd) {
    if (infoWnd?.isValid()) {
      let guiScene = infoWnd.getScene()
      broadcastEvent("RemoveOpenedModalInfo", { objs = [infoWnd] })
      guiScene.destroyElement(infoWnd)
    }
  })

  let holders = watchedObjects.map(@(t) t.infoWndHolder)
  holders.each(function(infoWndHolder) {
    if (infoWndHolder?.isValid()) {
      let guiScene = infoWndHolder.getScene()
      guiScene.destroyElement(infoWndHolder)
    }
  })

  watchedObjects.clear()
  updateTimer()
}

function removeInvalidWatchedObjects() {
  watchedObjects.replace(watchedObjects.filter(function(objects) {
    let { infoWnd, infoWndHolder, initiatorObj } = objects
    return infoWnd?.isValid() && (infoWndHolder?.isValid() ?? true) && initiatorObj?.isValid()
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

  let { infoWnd, infoWndHolder, initiatorObj, infoWndBounds, isCursorInBoundsOptional } = watchedObjects[watchedObjects.len() - 1]
  let boundsArr = [infoWndBounds]
  if (initiatorObj.isValid())
    boundsArr.append(getObjectBounds(initiatorObj))
  if (!isCursorInBounds(boundsArr, cursorPos) && !(isCursorInBoundsOptional?() ?? false)) {
    watchedObjects.pop()
    if (infoWnd?.isValid()) {
      broadcastEvent("RemoveOpenedModalInfo", { objs = [infoWnd] })
      let guiScene = infoWnd.getScene()
      guiScene.destroyElement(infoWnd)
    }

    if (infoWndHolder?.isValid()) {
      let guiScene = infoWndHolder.getScene()
      guiScene.destroyElement(infoWndHolder)
    }
  }
  isInAct = false
}

function addModalInfo(initiatorObj, handler, tooltipType, id, params, isCursorInBoundsOptional) {
  if (watchedObjects.findindex(@(o) o.id == id && o.initiatorObj?.isValid() && o.initiatorObj.isEqual(initiatorObj)) != null)
    return null

  let initiatorBounds = getObjectBounds(initiatorObj)
  let infosPlaceBounds = createInfoPlaceBounds()
  let { infoWnd, infoWndHolder = null} = isUseGamePad()
    ? createInfoHolderModal(initiatorObj)
    : createInfoHolder(initiatorObj)

  let prefSide = params?.modalPreferredSide ?? tooltipType.modalPreferredSide
  let maxHeight = prefSide != "center" ? null
    : max(initiatorBounds.top - infosPlaceBounds.top,
        infosPlaceBounds.bottom - initiatorBounds.bottom)

  tooltipType.fillTooltip(infoWnd, handler, id, params.__update({ maxHeight }))
  infoWnd.getScene().applyPendingChanges(false)

  let infoWndBounds = getObjectBounds(infoWnd)
  let offsetX = tooltipType.modalOffsetX != "" ? to_pixels(tooltipType.modalOffsetX) : 0
  let offsetY = tooltipType.modalOffsetY != "" ? to_pixels(tooltipType.modalOffsetY) : 0
  infoWnd["pos"] = getInfoWndPosition(initiatorBounds, infoWndBounds, prefSide, offsetX, offsetY)
  local fakeInitiator = null
  if (infoWndHolder != null) {
    fakeInitiator = infoWndHolder.findObject("fakeInitiator")
    fakeInitiator["pos"] = $"{initiatorBounds.left}, {initiatorBounds.top}"
    fakeInitiator["size"] = $"{initiatorBounds.width}, {initiatorBounds.height}"
  }

  watchedObjects.append({
    id
    infoWnd
    infoWndHolder
    initiatorObj
    infoWndBounds
    fakeInitiator
    isCursorInBoundsOptional
  })

  updateTimer()
  return infoWnd
}

function closeModalInfo(isDelayed = false) {
  if (watchedObjects.len() == 0)
    return
  let bounds = watchedObjects.map(@(t) t.infoWndBounds)
  if (isDelayed)
    bounds.extend(watchedObjects.map(@(t) t.initiatorObj.isValid()
      ? getObjectBounds(t.initiatorObj)
      : null
    ))

  if (isCursorInBounds(bounds, getCursorPos()))
    return
  broadcastEvent("RemoveOpenedModalInfo", { objs = watchedObjects.map(@(t) t.infoWnd) })
}

function openModalInfo(obj, handler, tooltipType, id, params, initObj = null, isCursorInBoundsOptional = @() null) {
  if (isActionsListOpen.get() == true)
    return null
  return addModalInfo(initObj ?? obj.getParent(), handler, tooltipType, id, params, isCursorInBoundsOptional)
}

isActionsListOpen.subscribe(@(_) destroy())

return {
  openModalInfo
  closeModalInfo
  destroyModalInfo = destroy
  getModalInfoByUnitId = @(id) watchedObjects.findvalue(@(o) o.id == id)
  isUseGamePad
}
