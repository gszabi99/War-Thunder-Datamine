let { get_blk_value_by_path, blkOptFromPath } = require("%sqStdLibs/helpers/datablockUtils.nut")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let hudElementsAabb = require("%scripts/hud/hudElementsAabb.nut")

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

g_hud_tutorial_elements.init <- function init(_nest)
{
  let blkPath = getCurBlkName()
  active = !!blkPath

  if (!::checkObj(_nest))
    return
  nest  = _nest

  initNestObjects()
  if (!::checkObj(scene))
    return

  scene.show(active)
  if (!active)
    return

  if (::u.isEmpty(blkOptFromPath(blkPath)))
  {
    let msg = $"Hud_tutorial_elements: blk file is empty. (blkPath = {blkPath})"
    dagor.debug(msg)
    ::dagor.assertf(false, msg)
    return
  }

  dagor.debug($"Hud_tutorial_elements: loaded {blkPath}")

  let guiScene = scene.getScene()
  guiScene.replaceContent(scene, blkPath, this)

  for (local i = 0; i < scene.childrenCount(); i++)
  {
    let childObj = scene.getChild(i)
    if (isDebugMode && childObj?.id)
      updateVisibleObject(childObj.id, childObj.isVisible(), -1)
    else
      childObj.show(false)
  }

  guiScene.performDelayed(this, function() { refreshObjects() })

  if (isDebugMode)
    addDebugTimer()
  else
    ::g_hud_event_manager.subscribe("hudElementShow", function(data) {
      onElementToggle(data)
    }, this)
}

g_hud_tutorial_elements.initNestObjects <- function initNestObjects()
{
  scene = nest.findObject("tutorial_elements_nest")
  timersNest = nest.findObject("hud_message_timers")
}

g_hud_tutorial_elements.getCurBlkName <- function getCurBlkName()
{
  if (isDebugMode)
    return debugBlkName

  return getBlkNameByCurMission()
}

g_hud_tutorial_elements.getBlkNameByCurMission <- function getBlkNameByCurMission()
{
  let misBlk = ::DataBlock()
  ::get_current_mission_desc(misBlk)

  let fullMisBlk = misBlk?.mis_file ? blkOptFromPath(misBlk.mis_file) : null
  let res = fullMisBlk  && get_blk_value_by_path(fullMisBlk, "mission_settings/mission/tutorialObjectsFile")
  return ::u.isString(res) ? res : null
}

g_hud_tutorial_elements.reinit <- function reinit()
{
  if (!active || !::checkObj(nest))
    return

  initNestObjects()
  refreshObjects()
}

g_hud_tutorial_elements.updateVisibleObject <- function updateVisibleObject(id, show, timeSec = -1)
{
  local htObj = ::getTblValue(id, visibleHTObjects)
  if (!show)
  {
    if (htObj)
    {
      htObj.show(false)
      delete visibleHTObjects[id]
    }
    return null
  }

  if (!htObj || !htObj.isValid())
  {
    htObj = ::HudTutorialObject(id, scene)
    if (!htObj.isValid())
      return null

    visibleHTObjects[id] <- htObj
  }

  if (timeSec >= 0)
    htObj.setTime(timeSec)
  return htObj
}

g_hud_tutorial_elements.updateObjTimer <- function updateObjTimer(objId, htObj)
{
  let curTimer = ::getTblValue(objId, timers)
  if (!htObj || !htObj.hasTimer() || !htObj.isVisibleByTime())
  {
    if (curTimer)
    {
      curTimer.destroy()
      delete timers[objId]
    }
    return
  }

  let timeLeft = htObj.getTimeLeft()
  if (curTimer && curTimer.isValid())
  {
    curTimer.setDelay(timeLeft)
    return
  }

  if (!::checkObj(timersNest))
    return

  timers[objId] <- ::Timer(timersNest, timeLeft, (@(objId) function () {
    updateVisibleObject(objId, false)
    if (objId in timers)
      delete timers[objId]
  })(objId), this)
}

g_hud_tutorial_elements.onElementToggle <- function onElementToggle(data)
{
  if (!active || !::checkObj(scene))
    return

  let objId   = ::getTblValue("element", data, null)
  let show  = ::getTblValue("show", data, false)
  let timeSec = ::getTblValue("time", data, 0)

  let htObj = updateVisibleObject(objId, show, timeSec)
  updateObjTimer(objId, htObj)
}

g_hud_tutorial_elements.getAABB <- function getAABB(name)
{
  return hudElementsAabb(name)
}

g_hud_tutorial_elements.refreshObjects <- function refreshObjects()
{
  let invalidObjects = []
  foreach(id, htObj in visibleHTObjects)
  {
    let isVisible = htObj.isVisibleByTime()
    if (isVisible)
      if (!htObj.isValid())
        htObj.refreshObj(id, scene)
      else if (needUpdateAabb)
        htObj.updateAabb()

    if (!isVisible || !htObj.isValid())
      invalidObjects.append(id)
  }

  foreach(id in invalidObjects)
  {
    let htObj = visibleHTObjects[id]
    delete visibleHTObjects[id]
    updateObjTimer(id, htObj)
  }

  needUpdateAabb = false
}

g_hud_tutorial_elements.onEventHudIndicatorChangedSize <- function onEventHudIndicatorChangedSize(params)
{
  needUpdateAabb = true
}

g_hud_tutorial_elements.onEventLoadingStateChange <- function onEventLoadingStateChange(params)
{
  if (::is_in_flight())
    return

  //all guiScenes destroy on loading so no need check objects one by one
  visibleHTObjects.clear()
  timers.clear()
  isDebugMode = false
}

g_hud_tutorial_elements.addDebugTimer <- function addDebugTimer()
{
  SecondsUpdater(scene,
                   function(...)
                   {
                     return ::g_hud_tutorial_elements.onDbgUpdate()
                   },
                   false)
}

g_hud_tutorial_elements.onDbgUpdate <- function onDbgUpdate()
{
  if (!isDebugMode)
    return true
  let modified = ::get_file_modify_time_sec(debugBlkName)
  if (modified < 0)
    return

  if (debugLastModified < 0)
  {
    debugLastModified = modified
    return
  }

  if (debugLastModified == modified)
    return

  debugLastModified = modified
  init(nest)
}

 //blkName = null to switchOff, blkName = "" to autodetect
g_hud_tutorial_elements.debug <- function debug(blkName = "")
{
  if (blkName == "")
    blkName = getBlkNameByCurMission()

  isDebugMode = ::u.isString(blkName) && blkName.len()
  debugBlkName = blkName
  debugLastModified = -1
  init(nest)
  return debugBlkName
}

::g_script_reloader.registerPersistentDataFromRoot("g_hud_tutorial_elements")
::subscribe_handler(::g_hud_tutorial_elements, ::g_listener_priority.DEFAULT_HANDLER)
