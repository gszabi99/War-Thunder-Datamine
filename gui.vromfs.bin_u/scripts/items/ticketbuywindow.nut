//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { setDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getEventEconomicName } = require("%scripts/events/eventInfo.nut")

gui_handlers.TicketBuyWindow <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  afterBuyFunc = null
  event = null
  tickets = null
  activeTicket = null

  function initScreen() {
    let view = {
      headerText = loc("ticketBuyWindow/header")
      tickets = handyman.renderCached("%gui/items/item.tpl", this.createTicketsView(this.tickets))
      windowMainText = this.createMainText()
      ticketCaptions = this.createTicketCaptionsView()
      activeTicketText = this.createActiveTicketText()
      hasActiveTicket = this.activeTicket != null
    }
    let data = handyman.renderCached("%gui/items/ticketBuyWindow.tpl", view)
    this.guiScene.replaceContentFromText(this.scene, data, data.len(), this)
    this.updateTicketCaptionsPosition()
    this.updateBuyButtonText()

    foreach (ticket in this.tickets)
      ::g_item_limits.enqueueItem(ticket.id)
    ::g_item_limits.requestLimits()
  }

  function onEventItemLimitsUpdated(_params) {
    this.updateTicketCaptionsText()
    this.updateTicketCaptionsPosition()
  }

  function onTicketDoubleClicked(_obj) {
    this.doMainAction()
  }

  function onBuyClicked(_obj) {
    this.doMainAction()
  }

  function createTicketsView(ticketsList) {
    let view = { items = [] }
    for (local i = 0; i < ticketsList.len(); ++i) {
      view.items.append(ticketsList[i].getViewData({
        itemIndex = i.tostring()
        ticketBuyWindow = true
      }))
    }
    return view
  }

  function createTicketCaptionsView() {
    let view = []
    for (local i = 0; i < this.tickets.len(); ++i) {
      view.append({
        captionId = this.getTicketCaptionId(i)
        captionText = this.getTicketCaptionText(this.tickets[i])
      })
    }
    return view
  }

  function updateTicketCaptionsText() {
    for (local i = 0; i < this.tickets.len(); ++i) {
      let captionObj = this.scene.findObject(this.getTicketCaptionId(i))
      if (checkObj(captionObj))
        captionObj.setValue(this.getTicketCaptionText(this.tickets[i]))
    }
  }

  function getTicketCaptionText(ticket) {
    local captionText = ticket.getAvailableDefeatsText(getEventEconomicName(this.event))
    let limitText = ticket.getGlobalLimitText()
    if (limitText.len() > 0)
      captionText += "\n" + limitText
    return captionText
  }

  function getTicketCaptionId(ticketIndex) {
    return "ticket_caption_" + ticketIndex.tostring()
  }

  function onItemAction(obj) {
    let itemIdx = (obj?.holderId ?? "-1").tointeger()
    let item = this.tickets?[itemIdx]
    if (item != this.getCurItem())
      this.getItemsListObj().setValue(itemIdx)

    this.doMainAction(item)
  }

  function onTicketSelected(_obj) {
    this.updateBuyButtonText()
  }

  function getCurItem() {
    local value = this.getItemsListObj().getValue()
    return getTblValue(value, this.tickets)
  }

  function getItemsListObj() {
    return this.scene.findObject("items_list")
  }

  function getTicketCaptionObj() {
    return this.scene.findObject("ticket_caption")
  }

  function doMainAction(item = null) {
    item = item ?? this.getCurItem()
    if (item != null)
      item.doMainAction(Callback(@(result) result.success && this.goBack(), this), this)
  }

  function updateTicketCaptionsPosition() {
    let itemsListObj = this.getItemsListObj()
    for (local i = 0; i < this.tickets.len(); ++i) {
      let itemObj = itemsListObj.getChild(i)
      let captionObj = this.scene.findObject("ticket_caption_" + i.tostring())
      this.updateTicketCaptionPosition(captionObj, itemObj)
    }
  }

  function updateTicketCaptionPosition(captionObj, itemObj) {
    if (!checkObj(captionObj))
      return
    if (!checkObj(itemObj))
      return
    let objCenterX = itemObj.getPosRC()[0] + 0.5 * itemObj.getSize()[0]
    let position = objCenterX - 0.5 * captionObj.getSize()[0] - captionObj.getParent().getPosRC()[0]
    captionObj.left = position.tointeger().tostring()
  }

  function updateBuyButtonText() {
    let mainActionData = this.getCurItem().getMainActionData()
    if (mainActionData)
      setDoubleTextToButton(
        this.scene,
        "btn_apply",
        mainActionData.btnName,
        mainActionData?.btnColoredName || mainActionData.btnName)
  }

  function createMainText() {
    local text = loc("ticketBuyWindow/mainText")
    if (this.tickets.len() > 1)
      text += "\n" + loc("ticketBuyWindow/optionalText")
    return text
  }

  function createActiveTicketText() {
    if (this.activeTicket == null)
      return ""
    local text = loc("ticketBuyWindow/activeTicketText") + "\n"
    let tournamentData = this.activeTicket.getTicketTournamentData(getEventEconomicName(this.event))
    let textParts = []
    textParts.append(loc("ticketBuyWindow/unfinishedSessions", tournamentData))
    textParts.append(this.activeTicket.getDefeatCountText(tournamentData))
    textParts.append(this.activeTicket.getSequenceDefeatCountText(tournamentData))
    text += "\n".join(textParts, true)
    return text
  }
}
