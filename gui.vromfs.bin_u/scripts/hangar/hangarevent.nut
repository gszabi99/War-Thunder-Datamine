from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { eventbus_subscribe } = require("eventbus")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getEventDisplayType } = require("%scripts/events/eventInfo.nut")
let { guiStartModalEvents } = require("%scripts/events/eventsHandler.nut")
let { reqUnlockByClient, isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { isProfileReceived } = require("%scripts/login/loginStates.nut")

function startGameMode(params) {
  if(handlersManager.findHandlerClassInScene(gui_handlers.MainMenu) == null)
    return

  let gameModeName = params?.gameModeName
  if(gameModeName == null)
    return

  let event = ::events.getEvent(gameModeName)
  if(event == null)
    return

  if(!getEventDisplayType(event).showInEventsWindow)
    return

  guiStartModalEvents({ event = gameModeName, autoJoin = true })
}

let clickToReqUnlockHint = @"textareaNoTab {
  id:t='clickToReqUnlockCount'
  width:t='200@sf/@pf'
  position:t='absolute'
  pos:t='{pos}'
  text:t='{count}'
  text-align:t='right'
  overlayTextColor:t='userlog'
  shadeStyle:t='shadowed'
  order-popup:t='yes'

  behaviour:t='basicTransparency'
  transp-base:t='255'
  transp-end:t='0'
  transp-func:t='delayed_square'
  transp-time:t='600'
  behaviour:t='basicTransparency'
  selfRemoveOnFinish:t='1'
}"

let animTimerPid = dagui_propid_add_name_id("_transp-timer")

local clickCountByUnlock = {
}

function getObjPos() {
  let cursorPos = get_dagui_mouse_cursor_pos_RC()
  let posX = $"({cursorPos[0]} - 1@blockInterval - 200@sf/@pf) $max 2@blockInterval"
  let posY = $"({cursorPos[1]} - 1@blockInterval - 1@fontHeightNormal) $max (1@titleLogoPlateHeight + 1@bh)"
  return $"{posX}, {posY}"
}

function showCountObj(count) {
  let handler = handlersManager.getActiveBaseHandler()
  if (!(handler?.isValid() ?? false))
    return null

  let { scene, guiScene } = handler
  let obj = scene.findObject("clickToReqUnlockCount")
  if (obj?.isValid()) {
    obj.pos = getObjPos()
    obj.setValue(count.tostring())
    obj.setFloatProp(animTimerPid, 0.0)
    return
  }

  guiScene.appendWithBlk(scene, clickToReqUnlockHint.subst({count, pos= getObjPos()}), {})
}

function clickToReqUnlock(params) {
  let { unlockName = "", clickCount = 0 } = params
  if (unlockName not in clickCountByUnlock)
    clickCountByUnlock[unlockName] <- { isUnlocked = null, curCount = 0 }
  local { isUnlocked, curCount } = clickCountByUnlock[unlockName]
  curCount++
  showCountObj(curCount)
  clickCountByUnlock[unlockName].curCount = curCount
  if (!isProfileReceived.get() || unlockName == "" || clickCount <= 0 || isUnlocked || curCount < clickCount)
    return

  isUnlocked = isUnlocked ?? isUnlockOpened(unlockName)
  clickCountByUnlock[unlockName].isUnlocked = true //Always set to true to avoid sending a second request to open unlock
  if (isUnlocked)
    return

  reqUnlockByClient(unlockName)
}

addListenersWithoutEnv({
  SignOut = @(_) clickCountByUnlock.clear()
})

eventbus_subscribe("startGameMode", @(param) startGameMode(param))
eventbus_subscribe("clickToReqUnlock", @(param) clickToReqUnlock(param))

