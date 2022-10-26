from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")

::gui_handlers.EventDescriptionWindow <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  event = null

  eventDescription = null

  function initScreen()
  {
    if (!this.checkEvent(this.event))
    {
      this.goBack()
      return
    }

    let view = {
      eventHeader = {
        difficultyImage = ::events.getDifficultyImg(this.event.name)
        difficultyTooltip = ::events.getDifficultyTooltip(this.event.name)
        eventName = ::events.getEventNameText(this.event) + " " + ::events.getRespawnsText(this.event)
      }
      showOkButton = false
    }
    let data = ::handyman.renderCached("%gui/events/eventDescriptionWindow.tpl", view)
    this.guiScene.replaceContentFromText(this.scene, data, data.len(), this)
    this.eventDescription = ::create_event_description(this.scene, this.event, false)
  }

  function checkEvent(ev)
  {
    return ev != null
  }
}
