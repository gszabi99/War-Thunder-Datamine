
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

g_popups.add <- function add(title, msg, onClickPopupAction = null, buttons = null, handler = null, groupName = null, lifetime = 0)
{
  savePopup(
    ::Popup({
        title = title
        msg = msg
        onClickPopupAction = onClickPopupAction
        buttons = buttons
        handler = handler
        groupName = groupName
        lifetime = lifetime
      }
    )
  )

  performDelayedFlushPopupsIfCan()
}

g_popups.removeByHandler <- function removeByHandler(handler)
{
  if (handler == null)
    return

  foreach(idx, popup in popupsList)
    if (popup.handler == handler)
    {
      popup.destroy(true)
      remove(popup)
    }

  for(local i = suspendedPopupsList.len()-1; i >= 0; i--)
    if (suspendedPopupsList[i].handler == handler)
      suspendedPopupsList.remove(i)
}

//********** PRIVATE **********//
g_popups.performDelayedFlushPopupsIfCan <- function performDelayedFlushPopupsIfCan()
{
  let curTime = ::dagor.getCurTime()
  if (curTime - lastPerformDelayedCallTime < LOST_DELAYED_ACTION_MSEC)
    return

  lastPerformDelayedCallTime = curTime
  let guiScene = ::get_cur_gui_scene()
  guiScene.performDelayed(
    this,
    function() {
      lastPerformDelayedCallTime = 0

      removeInvalidPopups()
      if (suspendedPopupsList.len() == 0)
        return

      for(local i = suspendedPopupsList.len()-1; i >= 0; i--)
      {
        let popup = suspendedPopupsList[i]
        if (canShowPopup())
        {
          ::u.removeFrom(suspendedPopupsList, popup)
          show(popup)
          if (getPopupCount() > MAX_POPUPS_ON_SCREEN)
            popupsList.remove(0).destroy(true)
        }
      }
    }
  )
}

g_popups.show <- function show(popup)
{
  let popupByGroup = getByGroup(popup)
  if (popupByGroup)
  {
    popupByGroup.destroy(true)
    remove(popupByGroup, false)
  }

  let popupNestObj = ::get_active_gc_popup_nest_obj()
  popup.show(popupNestObj)
  popupsList.append(popup)
}

g_popups.getPopupCount <- function getPopupCount()
{
  return popupsList.len()
}

g_popups.remove <- function remove(popup, needFlushSuspended = true)
{
  for(local i = 0; i < popupsList.len(); i++)
  {
    let checkedPopup = popupsList[i]
    if (checkedPopup == popup)
    {
      popupsList.remove(i)
      break
    }
  }

  if (needFlushSuspended)
    performDelayedFlushPopupsIfCan()
}

g_popups.getByGroup <- function getByGroup(sourcePopup)
{
  if (!sourcePopup.groupName)
    return null

  return ::u.search(
    popupsList,
    @(popup) popup.groupName == sourcePopup.groupName
  )
}

g_popups.savePopup <- function savePopup(newPopup)
{
  local index = -1
  if (newPopup.groupName)
    index = suspendedPopupsList.findindex( @(popup) popup.groupName == newPopup.groupName) ?? -1

  if (index >= 0)
    suspendedPopupsList.remove(index)

  suspendedPopupsList.insert(::max(index, 0), newPopup)
}

g_popups.canShowPopup <- function canShowPopup()
{
  let popupNestObj = ::get_active_gc_popup_nest_obj()
  if (!::check_obj(popupNestObj))
    return false

  return popupNestObj.getModalCounter() == 0
}

g_popups.removeInvalidPopups <- function removeInvalidPopups()
{
  for(local i = popupsList.len()-1; i >= 0; i--)
    if (!popupsList[i].isValidView())
      popupsList.remove(i)
}

//********** EVENT HANDLERDS ***********//

g_popups.onEventActiveHandlersChanged <- function onEventActiveHandlersChanged(params)
{
  performDelayedFlushPopupsIfCan()
}

::subscribe_handler(::g_popups, ::g_listener_priority.DEFAULT_HANDLER)