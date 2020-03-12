class ::gui_handlers.TicketBuyWindow extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  afterBuyFunc = null
  event = null
  tickets = null
  activeTicket = null

  function initScreen()
  {
    local view = {
      headerText = ::loc("ticketBuyWindow/header")
      tickets = ::handyman.renderCached("gui/items/item", createTicketsView(tickets))
      windowMainText = createMainText()
      ticketCaptions = createTicketCaptionsView()
      activeTicketText = createActiveTicketText()
      hasActiveTicket = activeTicket != null
    }
    local data = ::handyman.renderCached("gui/items/ticketBuyWindow", view)
    guiScene.replaceContentFromText(scene, data, data.len(), this)
    initFocusArray()
    updateTicketCaptionsPosition()
    updateBuyButtonText()

    foreach (ticket in tickets)
      ::g_item_limits.enqueueItem(ticket.id)
    ::g_item_limits.requestLimits()
  }

  function onEventItemLimitsUpdated(params)
  {
    updateTicketCaptionsText()
    updateTicketCaptionsPosition()
  }

  function onTicketDoubleClicked(obj)
  {
    doMainAction()
  }

  function onBuyClicked(obj)
  {
    doMainAction()
  }

  function createTicketsView(ticketsList)
  {
    local view = { items = [] }
    for (local i = 0; i < ticketsList.len(); ++i)
    {
      view.items.append(ticketsList[i].getViewData({
        itemIndex = i.tostring()
        ticketBuyWindow = true
      }))
    }
    return view
  }

  function createTicketCaptionsView()
  {
    local view = []
    for (local i = 0; i < tickets.len(); ++i)
    {
      view.append({
        captionId = getTicketCaptionId(i)
        captionText = getTicketCaptionText(tickets[i])
      })
    }
    return view
  }

  function updateTicketCaptionsText()
  {
    for (local i = 0; i < tickets.len(); ++i)
    {
      local captionObj = scene.findObject(getTicketCaptionId(i))
      if (::checkObj(captionObj))
        captionObj.setValue(getTicketCaptionText(tickets[i]))
    }
  }

  function getTicketCaptionText(ticket)
  {
    local captionText = ticket.getAvailableDefeatsText(::events.getEventEconomicName(event))
    local limitText = ticket.getGlobalLimitText()
    if (limitText.len() > 0)
      captionText += "\n" + limitText
    return captionText
  }

  function getTicketCaptionId(ticketIndex)
  {
    return "ticket_caption_" + ticketIndex.tostring()
  }

  function onItemAction(obj)
  {
    local itemIdx = (obj?.holderId ?? "-1").tointeger()
    local item = tickets?[itemIdx]
    if (item != getCurItem())
      getItemsListObj().setValue(itemIdx)

    doMainAction(item)
  }

  function onTicketSelected(obj)
  {
    updateBuyButtonText()
  }

  function getMainFocusObj()
  {
    return getItemsListObj()
  }

  function getCurItem()
  {
    local value = getItemsListObj().getValue()
    return ::getTblValue(value, tickets)
  }

  function getItemsListObj()
  {
    return scene.findObject("items_list")
  }

  function getTicketCaptionObj()
  {
    return scene.findObject("ticket_caption")
  }

  function doMainAction(item = null)
  {
    item = item ?? getCurItem()
    if (item != null)
      item.doMainAction(::Callback(@(result) result.success && goBack(), this), this)
  }

  function updateTicketCaptionsPosition()
  {
    local itemsListObj = getItemsListObj()
    for (local i = 0; i < tickets.len(); ++i)
    {
      local itemObj = itemsListObj.getChild(i)
      local captionObj = scene.findObject("ticket_caption_" + i.tostring())
      updateTicketCaptionPosition(captionObj, itemObj)
    }
  }

  function updateTicketCaptionPosition(captionObj, itemObj)
  {
    if (!::checkObj(captionObj))
      return
    if (!::checkObj(itemObj))
      return
    local objCenterX = itemObj.getPosRC()[0] + 0.5 * itemObj.getSize()[0]
    local position = objCenterX - 0.5 * captionObj.getSize()[0] - captionObj.getParent().getPosRC()[0]
    captionObj.left = position.tointeger().tostring()
  }

  function updateBuyButtonText()
  {
    local mainActionData = getCurItem().getMainActionData()
    if (mainActionData)
      ::setDoubleTextToButton(
        scene,
        "btn_apply",
        mainActionData.btnName,
        mainActionData?.btnColoredName || mainActionData.btnName)
  }

  function createMainText()
  {
    local text = ::loc("ticketBuyWindow/mainText")
    if (tickets.len() > 1)
      text += "\n" + ::loc("ticketBuyWindow/optionalText")
    return text
  }

  function createActiveTicketText()
  {
    if (activeTicket == null)
      return ""
    local text = ::loc("ticketBuyWindow/activeTicketText") + "\n"
    local tournamentData = activeTicket.getTicketTournamentData(::events.getEventEconomicName(event))
    local textParts = []
    textParts.append(::loc("ticketBuyWindow/unfinishedSessions", tournamentData))
    textParts.append(activeTicket.getDefeatCountText(tournamentData))
    textParts.append(activeTicket.getSequenceDefeatCountText(tournamentData))
    text += ::g_string.implode(textParts, "\n")
    return text
  }
}
