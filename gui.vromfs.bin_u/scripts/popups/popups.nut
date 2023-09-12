//checked for plus_string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")



let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_time_msec } = require("dagor.time")
let Popup = require("%scripts/popups/popup.nut")

/*
API:

add(title, msg, onClickPopupAction = null, buttons = null, handler = null, groupName = null)
  title - header text
  msg - mainText
  onClickPopupAction - callback which call on popup clicked
  buttons - array of buttons config
    first buttons function bindes on click on popup
    !!all buttons params are required!!
  [
    {id = button_id, text = buttonText, func = function (){}}
    {id = button_id, text = buttonText, func = function (){}}
    {id = button_id, text = buttonText, func = function (){}}
    {id = button_id, text = buttonText, func = function (){}}
  ]
  handler - pointer to handler, in the context of which will be called buttons functions.
    if not specified, functions will be called in global scope
  lifetime - popup showing time
  groupName - group of popups. Only one popup by group can be showed at the same time

removeByHandler(handler) - Remove all popups associated with the handler, which is set in the add method
*/

::g_popups <- {
  MAX_POPUPS_ON_SCREEN = 3

  popupsList = []
  suspendedPopupsList = []

  lastPerformDelayedCallTime = 0
}

//********** PUBLIC **********//

::g_popups.add <- function add(title, msg, onClickPopupAction = null, buttons = null, handler = null, groupName = null, lifetime = 0) {
  this.savePopup(
    Popup({ title, msg, onClickPopupAction, buttons, handler, groupName, lifetime })
  )

  this.performDelayedFlushPopupsIfCan()
}

::g_popups.removeByHandler <- function removeByHandler(handler) {
  if (handler == null)
    return

  foreach (_idx, popup in this.popupsList)
    if (popup.handler == handler) {
      popup.destroy(true)
      this.remove(popup)
    }

  for (local i = this.suspendedPopupsList.len() - 1; i >= 0; i--)
    if (this.suspendedPopupsList[i].handler == handler)
      this.suspendedPopupsList.remove(i)
}

//********** PRIVATE **********//
::g_popups.performDelayedFlushPopupsIfCan <- function performDelayedFlushPopupsIfCan() {
  let curTime = get_time_msec()
  if (curTime - this.lastPerformDelayedCallTime < LOST_DELAYED_ACTION_MSEC)
    return

  this.lastPerformDelayedCallTime = curTime
  let guiScene = get_cur_gui_scene()
  guiScene.performDelayed(
    this,
    function() {
      this.lastPerformDelayedCallTime = 0

      this.removeInvalidPopups()
      if (this.suspendedPopupsList.len() == 0)
        return

      for (local i = this.suspendedPopupsList.len() - 1; i >= 0; i--) {
        let popup = this.suspendedPopupsList[i]
        if (this.canShowPopup()) {
          u.removeFrom(this.suspendedPopupsList, popup)
          this.show(popup)
          if (this.getPopupCount() > this.MAX_POPUPS_ON_SCREEN)
            this.popupsList.remove(0).destroy(true)
        }
      }
    }
  )
}

::g_popups.show <- function show(popup) {
  let popupByGroup = this.getByGroup(popup)
  if (popupByGroup) {
    popupByGroup.destroy(true)
    this.remove(popupByGroup, false)
  }

  let popupNestObj = ::get_active_gc_popup_nest_obj()
  popup.show(popupNestObj)
  this.popupsList.append(popup)
}

::g_popups.getPopupCount <- function getPopupCount() {
  return this.popupsList.len()
}

::g_popups.remove <- function remove(popup, needFlushSuspended = true) {
  for (local i = 0; i < this.popupsList.len(); i++) {
    let checkedPopup = this.popupsList[i]
    if (checkedPopup == popup) {
      this.popupsList.remove(i)
      break
    }
  }

  if (needFlushSuspended)
    this.performDelayedFlushPopupsIfCan()
}

::g_popups.getByGroup <- function getByGroup(sourcePopup) {
  if (!sourcePopup.groupName)
    return null

  return u.search(
    this.popupsList,
    @(popup) popup.groupName == sourcePopup.groupName
  )
}

::g_popups.savePopup <- function savePopup(newPopup) {
  local index = -1
  if (newPopup.groupName)
    index = this.suspendedPopupsList.findindex(@(popup) popup.groupName == newPopup.groupName) ?? -1

  if (index >= 0)
    this.suspendedPopupsList.remove(index)

  this.suspendedPopupsList.insert(max(index, 0), newPopup)
}

::g_popups.canShowPopup <- function canShowPopup() {
  let popupNestObj = ::get_active_gc_popup_nest_obj()
  if (!checkObj(popupNestObj))
    return false

  return popupNestObj.getModalCounter() == 0
}

::g_popups.removeInvalidPopups <- function removeInvalidPopups() {
  for (local i = this.popupsList.len() - 1; i >= 0; i--)
    if (!this.popupsList[i].isValidView())
      this.popupsList.remove(i)
}

//********** EVENT HANDLERDS ***********//

::g_popups.onEventActiveHandlersChanged <- function onEventActiveHandlersChanged(_params) {
  this.performDelayedFlushPopupsIfCan()
}

subscribe_handler(::g_popups, ::g_listener_priority.DEFAULT_HANDLER)