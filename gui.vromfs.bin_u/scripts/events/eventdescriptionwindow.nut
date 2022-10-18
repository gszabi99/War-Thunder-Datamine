from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")

::gui_handlers.EventDescriptionWindow <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  event = null

  eventDescription = null

  function initScreen()
  {
    if (!checkEvent(event))
    {
      this.goBack()
      return
    }

    let view = {
      eventHeader = {
        difficultyImage = ::events.getDifficultyImg(event.name)
        difficultyTooltip = ::events.getDifficultyTooltip(event.name)
        eventName = ::events.getEventNameText(event) + " " + ::events.getRespawnsText(event)
      }
      showOkButton = false
    }
    let data = ::handyman.renderCached("%gui/events/eventDescriptionWindow", view)
    this.guiScene.replaceContentFromText(this.scene, data, data.len(), this)
    eventDescription = ::create_event_description(this.scene, event, false)
  }

  function checkEvent(ev)
  {
    return ev != null
  }
}
