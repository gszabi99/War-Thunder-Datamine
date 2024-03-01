from "%scripts/dagui_natives.nut" import get_file_modify_time_sec
from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { Timer } = require("%sqDagui/timer/timer.nut")
let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let { eventbus_subscribe } = require("eventbus")
let DataBlock = require("DataBlock")
let { getBlkValueByPath, blkOptFromPath } = require("%sqstd/datablock.nut")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let { getHudElementAabb } = require("%scripts/hud/hudElementsAabb.nut")
let { get_current_mission_desc } = require("guiMission")
let { isInFlight } = require("gameplayBinding")

let visibleHTObjects = persist("visibleHTObjects", @() {})
let debugHudTutorState = persist("debugHudTutorState", @() {isDebugMode=false, debugBlkName = null, debugLastModified = -1})

let g_hud_tutorial_elements = {
  active = false
  nest  = null
  scene = null
  timersNest = null
  timers = {}
  visibleHTObjects
  needUpdateAabb = false
}

g_hud_tutorial_elements.init <- function init(v_nest) {
  let blkPath = this.getCurBlkName()
  this.active = !!blkPath

  if (!checkObj(v_nest))
    return
  this.nest  = v_nest

  this.initNestObjects()
  if (!checkObj(this.scene))
    return

  this.scene.show(this.active)
  if (!this.active)
    return

  if (u.isEmpty(blkOptFromPath(blkPath))) {
    let msg = $"Hud_tutorial_elements: blk file is empty. (blkPath = {blkPath})"
    log(msg)
    assert(false, msg)
    return
  }

  log($"Hud_tutorial_elements: loaded {blkPath}")

  let guiScene = this.scene.getScene()
  guiScene.replaceContent(this.scene, blkPath, this)

  for (local i = 0; i < this.scene.childrenCount(); i++) {
    let childObj = this.scene.getChild(i)
    if (debugHudTutorState.isDebugMode && childObj?.id)
      this.updateVisibleObject(childObj.id, childObj.isVisible(), -1)
    else
      childObj.show(false)
  }

  guiScene.performDelayed(this, function() { this.refreshObjects() })

  if (debugHudTutorState.isDebugMode)
    this.addDebugTimer()
}

g_hud_tutorial_elements.initNestObjects <- function initNestObjects() {
  this.scene = this.nest.findObject("tutorial_elements_nest")
  this.timersNest = this.nest.findObject("hud_message_timers")
}

g_hud_tutorial_elements.getCurBlkName <- function getCurBlkName() {
  if (debugHudTutorState.isDebugMode)
    return debugHudTutorState.debugBlkName

  return this.getBlkNameByCurMission()
}

g_hud_tutorial_elements.getBlkNameByCurMission <- function getBlkNameByCurMission() {
  let misBlk = DataBlock()
  get_current_mission_desc(misBlk)

  let fullMisBlk = misBlk?.mis_file ? blkOptFromPath(misBlk.mis_file) : null
  let res = fullMisBlk  && getBlkValueByPath(fullMisBlk, "mission_settings/mission/tutorialObjectsFile")
  return u.isString(res) ? res : null
}

g_hud_tutorial_elements.reinit <- function reinit() {
  if (!this.active || !checkObj(this.nest))
    return

  this.initNestObjects()
  if (!(this.scene?.isValid() ?? false))
    return
  this.refreshObjects()
}

g_hud_tutorial_elements.updateVisibleObject <- function updateVisibleObject(id, show, timeSec = -1) {
  local htObj = getTblValue(id, this.visibleHTObjects)
  if (!show) {
    if (htObj) {
      htObj.show(false)
      this.visibleHTObjects.$rawdelete(id)
    }
    return null
  }

  if (!htObj || !htObj.isValid()) {
    htObj = ::HudTutorialObject(id, this.scene)
    if (!htObj.isValid())
      return null

    this.visibleHTObjects[id] <- htObj
  }

  if (timeSec >= 0)
    htObj.setTime(timeSec)
  return htObj
}

g_hud_tutorial_elements.updateObjTimer <- function updateObjTimer(objId, htObj) {
  let curTimer = getTblValue(objId, this.timers)
  if (!htObj || !htObj.hasTimer() || !htObj.isVisibleByTime()) {
    if (curTimer) {
      curTimer.destroy()
      this.timers.$rawdelete(objId)
    }
    return
  }

  let timeLeft = htObj.getTimeLeft()
  if (curTimer && curTimer.isValid()) {
    curTimer.setDelay(timeLeft)
    return
  }

  if (!checkObj(this.timersNest))
    return

  this.timers[objId] <- Timer(this.timersNest, timeLeft, function () {
    this.updateVisibleObject(objId, false)
    this.timers?.$rawdelete(objId)
  }, this)
}

g_hud_tutorial_elements.onElementToggle <- function onElementToggle(data) {
  if (!this.active || !checkObj(this.scene))
    return

  let objId   = getTblValue("element", data, null)
  let show  = getTblValue("show", data, false)
  let timeSec = getTblValue("time", data, 0)

  let htObj = this.updateVisibleObject(objId, show, timeSec)
  this.updateObjTimer(objId, htObj)
}

g_hud_tutorial_elements.getAABB <- function getAABB(name) {
  return getHudElementAabb(name)
}

g_hud_tutorial_elements.refreshObjects <- function refreshObjects() {
  let invalidObjects = []
  foreach (id, htObj in this.visibleHTObjects) {
    let isVisible = htObj.isVisibleByTime()
    if (isVisible)
      if (!htObj.isValid())
        htObj.refreshObj(id, this.scene)
      else if (this.needUpdateAabb)
        htObj.updateAabb()

    if (!isVisible || !htObj.isValid())
      invalidObjects.append(id)
  }

  foreach (id in invalidObjects) {
    let htObj = this.visibleHTObjects[id]
    this.visibleHTObjects.$rawdelete(id)
    this.updateObjTimer(id, htObj)
  }

  this.needUpdateAabb = false
}

g_hud_tutorial_elements.onEventHudIndicatorChangedSize <- function onEventHudIndicatorChangedSize(_params) {
  this.needUpdateAabb = true
}

g_hud_tutorial_elements.onEventLoadingStateChange <- function onEventLoadingStateChange(_params) {
  if (isInFlight())
    return

  //all guiScenes destroy on loading so no need check objects one by one
  this.visibleHTObjects.clear()
  this.timers.clear()
  debugHudTutorState.isDebugMode = false
}

g_hud_tutorial_elements.addDebugTimer <- function addDebugTimer() {
  SecondsUpdater(this.scene,
                   function(...) {
                     return g_hud_tutorial_elements.onDbgUpdate()
                   },
                   false)
}

g_hud_tutorial_elements.onDbgUpdate <- function onDbgUpdate() {
  if (!debugHudTutorState.isDebugMode)
    return true
  let modified = get_file_modify_time_sec(debugHudTutorState.debugBlkName)
  if (modified < 0)
    return

  if (debugHudTutorState.debugLastModified < 0) {
    debugHudTutorState.debugLastModified = modified
    return
  }

  if (debugHudTutorState.debugLastModified == modified)
    return

  debugHudTutorState.debugLastModified = modified
  this.init(this.nest)
}

 //blkName = null to switchOff, blkName = "" to autodetect
g_hud_tutorial_elements.debug <- function debug(blkName = "") {
  if (blkName == "")
    blkName = this.getBlkNameByCurMission()

  debugHudTutorState.isDebugMode = u.isString(blkName) && blkName.len()
  debugHudTutorState.debugBlkName = blkName
  debugHudTutorState.debugLastModified = -1
  this.init(this.nest)
  return debugHudTutorState.debugBlkName
}

subscribe_handler(g_hud_tutorial_elements, g_listener_priority.DEFAULT_HANDLER)
eventbus_subscribe("hudElementShow", @(data) g_hud_tutorial_elements.onElementToggle(data))

return { g_hud_tutorial_elements }