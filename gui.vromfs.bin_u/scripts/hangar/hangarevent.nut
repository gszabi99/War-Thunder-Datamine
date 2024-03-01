from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { eventbus_subscribe } = require("eventbus")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getEventDisplayType } = require("%scripts/events/eventInfo.nut")
let { guiStartModalEvents } = require("%scripts/events/eventsHandler.nut")

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

eventbus_subscribe("startGameMode", @(param) startGameMode(param))