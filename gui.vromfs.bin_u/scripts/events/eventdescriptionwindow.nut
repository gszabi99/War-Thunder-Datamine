from "%scripts/dagui_library.nut" import *

let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { create_event_description } = require("%scripts/events/eventDescription.nut")

let { events } = require("%scripts/events/eventsManager.nut")

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
