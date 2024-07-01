from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import LOST_DELAYED_ACTION_MSEC

let u = require("%sqStdLibs/helpers/u.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_time_msec } = require("dagor.time")
let { DEFAULT_HANDLER } = require("%scripts/g_listener_priority.nut")

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

removePopupByHandler(handler) - Remove all popups associated with the handler, which is set in the add method
*/

const MAX_POPUPS_ON_SCREEN = 3

let popupsList = []
let suspendedPopupsList = []
local lastPerformDelayedCallTime = 0

let getPopupCount = @() popupsList.len()

function getByGroup(sourcePopup) {
  if (!sourcePopup.groupName)
    return null

  return u.search(popupsList,
    @(popup) popup.groupName == sourcePopup.groupName)
}

function savePopup(newPopup) {
  local index = -1
  if (newPopup.groupName)
    index = suspendedPopupsList.findindex(
      @(popup) popup.groupName == newPopup.groupName) ?? -1

  if (index >= 0)
    suspendedPopupsList.remove(index)

  suspendedPopupsList.insert(max(index, 0), newPopup)
}

function canShowPopup() {
  let popupNestObj = ::get_active_gc_popup_nest_obj()
  if (!checkObj(popupNestObj))
    return false

  return popupNestObj.getModalCounter() == 0
}

function removeInvalidPopups() {
  for (local i = popupsList.len() - 1; i >= 0; --i)
    if (!popupsList[i].isValidView())
      popupsList.remove(i)
}

function removePopup(popup) {
  for (local i = 0; i < popupsList.len(); i++) {
    let checkedPopup = popupsList[i]
    if (checkedPopup == popup) {
      popupsList.remove(i)
      break
    }
  }
}

function performDelayedFlushPopupsIfCan() {
  let curTime = get_time_msec()
  if (curTime - lastPerformDelayedCallTime < LOST_DELAYED_ACTION_MSEC)
    return

  let self = callee()
  lastPerformDelayedCallTime = curTime
  get_cur_gui_scene().performDelayed({},
    function() {
      lastPerformDelayedCallTime = 0

      removeInvalidPopups()
      if (suspendedPopupsList.len() == 0)
        return

      for (local i = suspendedPopupsList.len() - 1; i >= 0; --i) {
        let popup = suspendedPopupsList[i]
        if (canShowPopup()) {
          u.removeFrom(suspendedPopupsList, popup)

          let popupByGroup = getByGroup(popup)
          if (popupByGroup) {
            popupByGroup.destroy(true)
            removePopup(popupByGroup)
            self()
          }

          let popupNestObj = ::get_active_gc_popup_nest_obj()
          popup.show(popupNestObj)
          popupsList.append(popup)

          if (getPopupCount() > MAX_POPUPS_ON_SCREEN)
            popupsList.remove(0).destroy(true)
        }
      }
    }
  )
}

let class Popup {
  static POPUP_BLK = "%gui/popup/popup.blk"
  static POPUP_BUTTON_BLK = "%gui/popup/popupButton.blk"

  title = ""
  message = ""
  groupName = null
  lifetime = null
  handler = null
  buttons = []
  selfObj = null
  onClickPopupAction = null

  constructor(config) {
    this.onClickPopupAction = config.onClickPopupAction
    this.buttons = config.buttons ?? []
    this.handler = config.handler
    this.groupName = config.groupName
    this.title = config.title
    this.message = config.msg
    this.lifetime = config.lifetime
  }

  function isValidView() {
    return checkObj(this.selfObj)
  }

  function show(popupNestObj) {
    popupNestObj.setUserData(this)

    let popupGuiScene = get_cur_gui_scene()
    this.selfObj = popupGuiScene.createElementByObject(popupNestObj, this.POPUP_BLK, "popup", this)

    if (!u.isEmpty(this.title))
      this.selfObj.findObject("title").setValue(this.title)
    else
      this.selfObj.findObject("title").show(false)

    this.selfObj.findObject("msg").setValue(this.message)
    this.selfObj["skip-navigation"] = (this.onClickPopupAction == null) ? "yes" : "no"

    let obj = this.selfObj.findObject("popup_buttons_place")
    foreach (button in this.buttons) {
      let buttonObj = popupGuiScene.createElementByObject(obj, this.POPUP_BUTTON_BLK, "Button_text", this)
      buttonObj.id = button.id
      buttonObj.setValue(button.text)
    }

    this.selfObj.setUserData(this)

    if (this.lifetime > 0)
      this.selfObj.timer_interval_msec = this.lifetime.tostring()
  }

  function destroy(isForced = false) {
    if (checkObj(this.selfObj))
      this.selfObj.fade = isForced ? "forced" : "out"
  }

  function requestDestroy(isForced = true) {
    this.destroy(isForced)
    removePopup(this)
    performDelayedFlushPopupsIfCan()
  }

  function performPopupAction(func) {
    if (!func)
      return
    if (this.handler != null)
      func.call(this.handler)
    else
      func()
  }

  function onClickPopup(_obj) {
    if (this.onClickPopupAction)
      this.performPopupAction(this.onClickPopupAction)
    this.requestDestroy()
  }

  function onRClickPopup(_obj) {
    this.requestDestroy()
  }

  function onClosePopup(_obj) {
    this.requestDestroy()
  }

  function onPopupButtonClick(obj) {
    let id = obj?.id
    let button = this.buttons.findvalue(@(b) b.id == id)
    obj.getScene().performDelayed(this, function() {
      if (!this.isValidView())
        return
      this.performPopupAction(button?.func)
      this.requestDestroy()
    })
  }

  function onTimerUpdate(_obj, _dt) {
    this.requestDestroy(false)
  }
}

function addPopup(title, msg, onClickPopupAction = null, buttons = null, handler = null, groupName = null, lifetime = 0) {
  savePopup(Popup({ title, msg, onClickPopupAction, buttons, handler, groupName, lifetime }))
  performDelayedFlushPopupsIfCan()
}

function removePopupByHandler(handler) {
  if (handler == null)
    return

  foreach (_idx, popup in popupsList)
    if (popup.handler == handler) {
      popup.destroy(true)
      removePopup(popup)
      performDelayedFlushPopupsIfCan()
    }

  for (local i = suspendedPopupsList.len() - 1; i >= 0; i--)
    if (suspendedPopupsList[i].handler == handler)
      suspendedPopupsList.remove(i)
}

addListenersWithoutEnv({
  ActiveHandlersChanged = @(_p) performDelayedFlushPopupsIfCan()
}, DEFAULT_HANDLER)

return {
  MAX_POPUPS_ON_SCREEN
  addPopup
  removePopupByHandler
}
