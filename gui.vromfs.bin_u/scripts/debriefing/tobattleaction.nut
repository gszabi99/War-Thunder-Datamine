local goToBattleAction = function() {
  ::get_cur_gui_scene().performDelayed({}, function() {
    if (::g_squad_manager.isSquadMember() && !::g_squad_manager.isMeReady()) {
      ::g_squad_manager.setReadyFlag(true)
      return
    }

    local lastEvent = ::events.getEvent(::SessionLobby.lastEventName)
    local eventDisplayType = ::events.getEventDisplayType(lastEvent)
    local handlerClass = eventDisplayType.showInGamercardDrawer ? ::gui_handlers.MainMenu
      : eventDisplayType.showInEventsWindow ? ::gui_handlers.EventsHandler
      : null
    if (!handlerClass)
      return

    local handler = ::handlersManager.findHandlerClassInScene(handlerClass)
    if (handler) {
      handler.goToBattleFromDebriefing()
      return
    }

    if (!handler && eventDisplayType.showInEventsWindow) {
      ::gui_start_modal_events()
      ::get_cur_gui_scene().performDelayed(::getroottable(), function() {
        handler = ::handlersManager.findHandlerClassInScene(::gui_handlers.EventsHandler)
        if (handler)
          handler.goToBattleFromDebriefing()
      })
    }
  })
}

return {
  getGoToBattleAction = @() goToBattleAction
  overrideGoToBattleAction = @(func) goToBattleAction = func
}
