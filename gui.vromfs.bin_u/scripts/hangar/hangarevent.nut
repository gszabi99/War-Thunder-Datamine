from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { subscribe } = require("eventbus")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

let function startGameMode(params) {
  if(handlersManager.findHandlerClassInScene(gui_handlers.MainMenu) == null)
    return

  let gameModeName = params?.gameModeName
  if(gameModeName == null)
    return

  let event = ::events.getEvent(gameModeName)
  if(event == null)
    return

  if(!::events.getEventDisplayType(event).showInEventsWindow)
    return

  ::gui_start_modal_events({ event = gameModeName, autoJoin = true })
}

subscribe("startGameMode", @(param) startGameMode(param))