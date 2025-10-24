from "%scripts/dagui_library.nut" import *

let { setInterval, clearTimer } = require("dagor.workcycle")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { move_mouse_on_obj } = require("%sqDagui/daguiUtil.nut")
let { isEqual } = require("%sqStdLibs/helpers/u.nut")
let { isActionsListOpen } = require("%scripts/actionsList/actionsListState.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_time_msec } = require("dagor.time")

let watchedObjects = []
local timer = null
local onTimerTick = null
let lastCursorPos = { x = -1, y = -1 }
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

function updateTimer() {
  if (showConsoleButtons.get() || watchedObjects.len() == 0)
    stopTimer()
  else
    startTimer()
}

function updateCloseAllWindowsInfo() {
  if (watchedObjects.len() == 0)
    return
  foreach (idx, obj in watchedObjects) {
    let closeAllWindowsInfo = obj.infoWnd.findObject("closeAllWindowsInfo")
    closeAllWindowsInfo.show(idx != 0 && idx == watchedObjects.len() - 1 && showConsoleButtons.get())
  }
}

function closeLastModalInfo(removeHolder = true) {
  clearTimer(holdTimer)
  if (watchedObjects.len() == 0)
    return

  let { fakeInitiator, infoWndHolder, infoWnd } = watchedObjects.pop()
  let guiScene = infoWndHolder.getScene()
  move_mouse_on_obj(fakeInitiator)
  broadcastEvent("RemoveOpenedModalInfo", { objs = [infoWnd] })
  guiScene.destroyElement(infoWnd)
  if (removeHolder)
    guiScene.destroyElement(infoWndHolder)
  else
    lastHolder = infoWndHolder

  updateCloseAllWindowsInfo()
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

function getInfoWndPosition(initiatorObjBounds, modalInfoObjBounds) {
  let overlapDelta = to_pixels("1@blockInterval")
  let infosPlaceBounds = createInfoPlaceBounds()
  let infoWndPos = [0, 0]

  if (initiatorObjBounds.right + modalInfoObjBounds.width < infosPlaceBounds.right)
    infoWndPos[0] = initiatorObjBounds.right - overlapDelta
  else
    infoWndPos[0] = max(infosPlaceBounds.left, initiatorObjBounds.left - modalInfoObjBounds.width + overlapDelta)

  infoWndPos[1] = initiatorObjBounds.top
  if (infoWndPos[1] + modalInfoObjBounds.height > infosPlaceBounds.bottom) {
    infoWndPos[1] = max(infosPlaceBounds.top, infosPlaceBounds.bottom - modalInfoObjBounds.height)
  }
  modalInfoObjBounds.update(infoWndPos[0], infoWndPos[1])
  return ",".join(infoWndPos)
}

function createInfoHolder(initiatorObj) {
  let content = "modalInfoHolder { id:t = 'modalInfoHolder' }"
  initiatorObj.getScene().appendWithBlk(initiatorObj, content, null)
  return {
    infoWnd = initiatorObj.findObject("modalInfoHolder")
  }
}

function createInfoHolderModal(initiatorObj) {
  let guiScene = initiatorObj.getScene()
  let infoWndHolder = guiScene.loadModal("", "%gui/modalInfo/modalInfoHolder.blk", "tdiv", handlerClass())
  let content = "modalInfoHolder { id:t = 'modalInfoHolder' }"
  guiScene.appendWithBlk(infoWndHolder, content, null)
  return {
    infoWnd = infoWndHolder.findObject("modalInfoHolder")
    infoWndHolder
  }
}

function isCursorInBounds(bounds, cursorPos) {
  return bounds.findindex(@(b) b.isOnObject(cursorPos)) != null
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
  if (showConsoleButtons.get()) {
    let holders = watchedObjects.map(@(t) t.infoWndHolder)
    holders.each(function(infoWndHolder) {
      if (infoWndHolder?.isValid()) {
        let guiScene = infoWndHolder.getScene()
        guiScene.destroyElement(infoWndHolder)
      }
    })
  }
  watchedObjects.clear()
  updateTimer()
}

function getCursorPos() {
  let cursorPosArr = get_dagui_mouse_cursor_pos()
  return {
    x = cursorPosArr[0]
    y = cursorPosArr[1]
  }
}

function removeInvalidWatchedObjects() {
  watchedObjects.replace(watchedObjects.filter(function(objects) {
    let { infoWnd, infoWndHolder } = objects
    return infoWnd?.isValid() && (infoWndHolder?.isValid() ?? true)
  }))
}

local isInAct = false
onTimerTick = function() {
  if (isInAct)
    return

  if (watchedObjects.len() == 0) {
    isInAct = false
    return
  }

  removeInvalidWatchedObjects()

  let cursorPos = getCursorPos()
  if (isEqual(cursorPos, lastCursorPos)) {
    isInAct = false
    return
  }
  isInAct = true
  lastCursorPos.__update(cursorPos)
  let { infoWnd, infoWndHolder, initiatorBounds, infoWndBounds } = watchedObjects[watchedObjects.len() - 1]
  if (!isCursorInBounds([initiatorBounds, infoWndBounds], cursorPos)) {
    watchedObjects.pop()
    if (infoWnd?.isValid()) {
      broadcastEvent("RemoveOpenedModalInfo", { objs = [infoWnd] })
      let guiScene = infoWnd.getScene()
      guiScene.destroyElement(infoWnd)
    }

    if (showConsoleButtons.get() && infoWndHolder?.isValid()) {
      let guiScene = infoWndHolder.getScene()
      guiScene.destroyElement(infoWndHolder)
    }
  }
  isInAct = false
}

function addModalInfo(initiatorObj, handler, tooltipType, id, params) {
  if (watchedObjects.findindex(@(o) o.id == id) != null)
    return null

  let { infoWnd, infoWndHolder = null} = showConsoleButtons.get() ? createInfoHolderModal(initiatorObj) : createInfoHolder(initiatorObj)
  tooltipType.fillTooltip(infoWnd, handler , id, params)
  infoWnd.getScene().applyPendingChanges(false)

  let initiatorBounds = getObjectBounds(initiatorObj)
  let infoWndBounds = getObjectBounds(infoWnd)
  infoWnd["pos"] = getInfoWndPosition(initiatorBounds, infoWndBounds)

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
    initiatorBounds
    infoWndBounds
    fakeInitiator
  })

  updateTimer()
  updateCloseAllWindowsInfo()
  return infoWnd
}

function closeModalInfo(isDelayed = false) {
  if (watchedObjects.len() == 0)
    return
  let bounds = watchedObjects.map(@(t) t.infoWndBounds)
  if (isDelayed)
    bounds.extend(watchedObjects.map(@(t) t.initiatorBounds))

  if (isCursorInBounds(bounds, getCursorPos()))
    return
  broadcastEvent("RemoveOpenedModalInfo", { objs = watchedObjects.map(@(t) t.infoWnd) })
}

function openModalInfo(obj, handler, tooltipType, id, params, initObj = null) {
  if (isActionsListOpen.get() == true)
    return null
  return addModalInfo(initObj ?? obj.getParent(), handler, tooltipType, id, params)
}

isActionsListOpen.subscribe(@(_) destroy())

return {
  openModalInfo
  closeModalInfo
}
