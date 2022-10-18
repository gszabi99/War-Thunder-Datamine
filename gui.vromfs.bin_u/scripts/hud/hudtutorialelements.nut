from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { get_blk_value_by_path, blkOptFromPath } = require("%sqStdLibs/helpers/datablockUtils.nut")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let hudElementsAabb = require("%scripts/hud/hudElementsAabb.nut")
let { PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")

::g_hud_tutorial_elements <- {
  [PERSISTENT_DATA_PARAMS] = ["visibleHTObjects", "isDebugMode", "debugBlkName"]

  active = false
  nest  = null
  scene = null
  timersNest = null
  timers = {}

  visibleHTObjects = {}

  needUpdateAabb = false

  isDebugMode = false
  debugBlkName = null
  debugLastModified = -1
}

::g_hud_tutorial_elements.init <- function init(v_nest)
{
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

  if (::u.isEmpty(blkOptFromPath(blkPath)))
  {
    let msg = $"Hud_tutorial_elements: blk file is empty. (blkPath = {blkPath})"
    log(msg)
    assert(false, msg)
    return
  }

  log($"Hud_tutorial_elements: loaded {blkPath}")

  let guiScene = this.scene.getScene()
  guiScene.replaceContent(this.scene, blkPath, this)

  for (local i = 0; i < this.scene.childrenCount(); i++)
  {
    let childObj = this.scene.getChild(i)
    if (this.isDebugMode && childObj?.id)
      this.updateVisibleObject(childObj.id, childObj.isVisible(), -1)
    else
      childObj.show(false)
  }

  guiScene.performDelayed(this, function() { this.refreshObjects() })

  if (this.isDebugMode)
    this.addDebugTimer()
  else
    ::g_hud_event_manager.subscribe("hudElementShow", function(data) {
      this.onElementToggle(data)
    }, this)
}

::g_hud_tutorial_elements.initNestObjects <- function initNestObjects()
{
  this.scene = this.nest.findObject("tutorial_elements_nest")
  this.timersNest = this.nest.findObject("hud_message_timers")
}

::g_hud_tutorial_elements.getCurBlkName <- function getCurBlkName()
{
  if (this.isDebugMode)
    return this.debugBlkName

  return this.getBlkNameByCurMission()
}

::g_hud_tutorial_elements.getBlkNameByCurMission <- function getBlkNameByCurMission()
{
  let misBlk = ::DataBlock()
  ::get_current_mission_desc(misBlk)

  let fullMisBlk = misBlk?.mis_file ? blkOptFromPath(misBlk.mis_file) : null
  let res = fullMisBlk  && get_blk_value_by_path(fullMisBlk, "mission_settings/mission/tutorialObjectsFile")
  return ::u.isString(res) ? res : null
}

::g_hud_tutorial_elements.reinit <- function reinit()
{
  if (!this.active || !checkObj(this.nest))
    return

  initNestObjects()
  this.refreshObjects()
}

::g_hud_tutorial_elements.updateVisibleObject <- function updateVisibleObject(id, show, timeSec = -1)
{
  local htObj = getTblValue(id, this.visibleHTObjects)
  if (!show)
  {
    if (htObj)
    {
      htObj.show(false)
      delete this.visibleHTObjects[id]
    }
    return null
  }

  if (!htObj || !htObj.isValid())
  {
    htObj = ::HudTutorialObject(id, this.scene)
    if (!htObj.isValid())
      return null

    this.visibleHTObjects[id] <- htObj
  }

  if (timeSec >= 0)
    htObj.setTime(timeSec)
  return htObj
}

::g_hud_tutorial_elements.updateObjTimer <- function updateObjTimer(objId, htObj)
{
  let curTimer = getTblValue(objId, this.timers)
  if (!htObj || !htObj.hasTimer() || !htObj.isVisibleByTime())
  {
    if (curTimer)
    {
      curTimer.destroy()
      delete this.timers[objId]
    }
    return
  }

  let timeLeft = htObj.getTimeLeft()
  if (curTimer && curTimer.isValid())
  {
    curTimer.setDelay(timeLeft)
    return
  }

  if (!checkObj(this.timersNest))
    return

  this.timers[objId] <- ::Timer(this.timersNest, timeLeft, (@(objId) function () {
    updateVisibleObject(objId, false)
    if (objId in this.timers)
      delete this.timers[objId]
  })(objId), this)
}

::g_hud_tutorial_elements.onElementToggle <- function onElementToggle(data)
{
  if (!this.active || !checkObj(this.scene))
    return

  let objId   = getTblValue("element", data, null)
  let show  = getTblValue("show", data, false)
  let timeSec = getTblValue("time", data, 0)

  let htObj = updateVisibleObject(objId, show, timeSec)
  updateObjTimer(objId, htObj)
}

::g_hud_tutorial_elements.getAABB <- function getAABB(name)
{
  return hudElementsAabb(name)
}

::g_hud_tutorial_elements.refreshObjects <- function refreshObjects()
{
  let invalidObjects = []
  foreach(id, htObj in this.visibleHTObjects)
  {
    let isVisible = htObj.isVisibleByTime()
    if (isVisible)
      if (!htObj.isValid())
        htObj.refreshObj(id, this.scene)
      else if (this.needUpdateAabb)
        htObj.updateAabb()

    if (!isVisible || !htObj.isValid())
      invalidObjects.append(id)
  }

  foreach(id in invalidObjects)
  {
    let htObj = this.visibleHTObjects[id]
    delete this.visibleHTObjects[id]
    updateObjTimer(id, htObj)
  }

  this.needUpdateAabb = false
}

::g_hud_tutorial_elements.onEventHudIndicatorChangedSize <- function onEventHudIndicatorChangedSize(_params)
{
  this.needUpdateAabb = true
}

::g_hud_tutorial_elements.onEventLoadingStateChange <- function onEventLoadingStateChange(_params)
{
  if (::is_in_flight())
    return

  //all guiScenes destroy on loading so no need check objects one by one
  this.visibleHTObjects.clear()
  this.timers.clear()
  this.isDebugMode = false
}

::g_hud_tutorial_elements.addDebugTimer <- function addDebugTimer()
{
  SecondsUpdater(this.scene,
                   function(...)
                   {
                     return ::g_hud_tutorial_elements.onDbgUpdate()
                   },
                   false)
}

::g_hud_tutorial_elements.onDbgUpdate <- function onDbgUpdate()
{
  if (!this.isDebugMode)
    return true
  let modified = ::get_file_modify_time_sec(this.debugBlkName)
  if (modified < 0)
    return

  if (this.debugLastModified < 0)
  {
    this.debugLastModified = modified
    return
  }

  if (this.debugLastModified == modified)
    return

  this.debugLastModified = modified
  init(this.nest)
}

 //blkName = null to switchOff, blkName = "" to autodetect
::g_hud_tutorial_elements.debug <- function debug(blkName = "")
{
  if (blkName == "")
    blkName = getBlkNameByCurMission()

  this.isDebugMode = ::u.isString(blkName) && blkName.len()
  this.debugBlkName = blkName
  this.debugLastModified = -1
  init(this.nest)
  return this.debugBlkName
}

::g_script_reloader.registerPersistentDataFromRoot("g_hud_tutorial_elements")
::subscribe_handler(::g_hud_tutorial_elements, ::g_listener_priority.DEFAULT_HANDLER)
