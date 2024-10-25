from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")

gui_handlers.EventDescriptionWindow <- class (gui_handlers.BaseGuiHandlerWT) {
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
    this.eventDescription = ::create_event_description(this.scene, this.event, false)
  }

  function checkEvent(ev) {
    return ev != null
  }
}
