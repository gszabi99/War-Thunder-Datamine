from "%scripts/dagui_library.nut" import *
from "%scripts/hud/hudConsts.nut" import HUD_TYPE

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { frnd } = require("dagor.random")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

let { register_command } = require("console")
let dbgHudObjectTypes = require("%scripts/debugTools/dbgHudObjectTypes.nut")

// warning disable: -file:forbidden-function

local eventsPerSec = 0
local curTimerObj = null
local activeObjectTypes = []
local totalChance = 0

function genRandomEvent() {
  if (!totalChance)
    return

  local chance = frnd() * totalChance
  foreach (oType in activeObjectTypes) {
    chance -= oType.eventChance
    if (chance > 0)
      continue
    oType.genNewEvent()
    break
  }
}

function onUpdate(_obj, dt) {
  if (!eventsPerSec || dt < 0.0001)
    return

  local eventChance = dt * eventsPerSec
  for (eventChance; eventChance > 0; eventChance--)
    if (eventChance >= 1 || eventChance > frnd())
      genRandomEvent()
}

function createTimerObjOnce() {
   if (checkObj(curTimerObj))
     return

  let hudHandler = handlersManager.findHandlerClassInScene(gui_handlers.Hud)
  if (!hudHandler) {
    dlog("Error: not found active hud")
    return
  }

  let blkText = "timer { id:t = 'hud_debug_objects_timer'; timer_handler_func:t = 'onUpdate' }"
  hudHandler.guiScene.appendWithBlk(hudHandler.scene, blkText, null)
  curTimerObj = hudHandler.scene.findObject("hud_debug_objects_timer")
  curTimerObj.setUserData({ onUpdate })
}

function stop() {
  if (checkObj(curTimerObj))
    curTimerObj.getScene().destroyElement(curTimerObj)
}

function getCurHudType() {
  let hudHandler = handlersManager.findHandlerClassInScene(gui_handlers.Hud)
  if (!hudHandler)
    return HUD_TYPE.NONE
  return hudHandler.hudType
}

function updateActiveObjectsTypes() {
  let hudType = getCurHudType()
  activeObjectTypes.clear()
  totalChance = 0.0
  foreach (oType in dbgHudObjectTypes.types) {
    if (!oType.isVisible(hudType))
      continue
    activeObjectTypes.append(oType)
    totalChance += oType.eventChance
  }
}

function start(newEventsPerSec) {
  eventsPerSec = newEventsPerSec
  if (eventsPerSec == 0)
    stop()
  else
    createTimerObjOnce()

  updateActiveObjectsTypes()
}

register_command(start, "debug.hud.objects_start")
register_command(stop, "debug.hud.objects_stop")
