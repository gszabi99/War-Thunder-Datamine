from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/events/eventDescription.nut" import create_event_description
from "%scripts/events/eventsManager.nut" import events
from "%scripts/dagui_library.nut" import *

register_gui_handler("EventDescriptionWindow", class (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  event = null

  eventDescription = null

  function initScreen() {
    if (!this.checkEvent(this.event)) {
      this.goBack()
      return
    }

    let view = {
      eventHeader = {
        difficultyImage = events.getDifficultyImg(this.event.name)
        difficultyTooltip = events.getDifficultyTooltip(this.event.name)
        eventName = " ".concat(events.getEventNameText(this.event), events.getRespawnsText(this.event))
      }
      showOkButton = false
    }
    let data = handyman.renderCached("%gui/events/eventDescriptionWindow.tpl", view)
    this.guiScene.replaceContentFromText(this.scene, data, data.len(), this)
    this.eventDescription = create_event_description(this.scene, this.event, false)
  }

  function checkEvent(ev) {
    return ev != null
  }
})
