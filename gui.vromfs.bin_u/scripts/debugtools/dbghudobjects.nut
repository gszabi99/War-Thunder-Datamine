// warning disable: -file:forbidden-function

::g_hud_debug_objects <- {
  eventsPerSec = 0
  curTimerObj = null

  activeObjectTypes = []
  totalChance = 0
}

g_hud_debug_objects.start <- function start(newEventsPerSec = 10.0)
{
  eventsPerSec = newEventsPerSec

  if (eventsPerSec == 0)
    stop()
  else
    createTimerObjOnce()

  updateActiveObjectsTypes()
}

g_hud_debug_objects.stop <- function stop()
{
  if (::checkObj(curTimerObj))
    curTimerObj.getScene().destroyElement(curTimerObj)
}

g_hud_debug_objects.createTimerObjOnce <- function createTimerObjOnce()
{
   if (::checkObj(curTimerObj))
     return

  local hudHandler = ::handlersManager.findHandlerClassInScene(::gui_handlers.Hud)
  if (!hudHandler)
  {
    dlog("Error: not found active hud")
    return
  }

  local blkText = "timer { id:t = 'g_hud_debug_objects_timer'; timer_handler_func:t = 'onUpdate' }"
  hudHandler.guiScene.appendWithBlk(hudHandler.scene, blkText, null)
  curTimerObj = hudHandler.scene.findObject("g_hud_debug_objects_timer")
  curTimerObj.setUserData(this)
}

g_hud_debug_objects.getCurHudType <- function getCurHudType()
{
  local hudHandler = ::handlersManager.findHandlerClassInScene(::gui_handlers.Hud)
  if (!hudHandler)
    return HUD_TYPE.NONE
  return hudHandler.hudType
}

g_hud_debug_objects.updateActiveObjectsTypes <- function updateActiveObjectsTypes()
{
  local hudType = getCurHudType()
  activeObjectTypes.clear()
  totalChance = 0.0
  foreach(oType in ::g_dbg_hud_object_type.types)
  {
    if (!oType.isVisible(hudType))
      continue
    activeObjectTypes.append(oType)
    totalChance += oType.eventChance
  }
}

g_hud_debug_objects.onUpdate <- function onUpdate(obj, dt)
{
  if (!eventsPerSec || dt < 0.0001)
    return

  local eventChance = dt * eventsPerSec
  for(eventChance; eventChance > 0; eventChance--)
    if (eventChance >= 1 || eventChance > ::math.frnd())
      genRandomEvent()
}

g_hud_debug_objects.genRandomEvent <- function genRandomEvent()
{
  if (!totalChance)
    return

  local chance = ::math.frnd() * totalChance
  foreach(oType in activeObjectTypes)
  {
    chance -= oType.eventChance
    if (chance > 0)
      continue
    oType.genNewEvent()
    break
  }
}
