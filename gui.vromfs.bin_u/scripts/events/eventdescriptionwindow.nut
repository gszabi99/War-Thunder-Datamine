class ::gui_handlers.EventDescriptionWindow extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  event = null

  eventDescription = null

  function initScreen()
  {
    if (!checkEvent(event))
    {
      goBack()
      return
    }

    local view = {
      eventHeader = {
        difficultyImage = ::events.getDifficultyImg(event.name)
        difficultyTooltip = ::events.getDifficultyTooltip(event.name)
        eventName = ::events.getEventNameText(event) + " " + ::events.getRespawnsText(event)
      }
      showOkButton = false
    }
    local data = ::handyman.renderCached("gui/events/eventDescriptionWindow", view)
    guiScene.replaceContentFromText(scene, data, data.len(), this)
    eventDescription = ::create_event_description(scene, event, false)
  }

  function checkEvent(ev)
  {
    return ev != null
  }
}
