from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/dagui_library.nut" import *

let { g_chat } = require("%scripts/chat/chat.nut")

register_gui_handler("ChatThreadHeader", class (BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  sceneTplName = "%gui/chat/chatThreadsListRows.tpl"

  roomId = ""
  threadInfo = null

  function getSceneTplView() {
    this.threadInfo = g_chat.addThreadInfoById(this.roomId)
    return {
      threads = [this.threadInfo]
      onlyInfo = true
      noSelect = true
      addTimer = true
    }
  }

  function initScreen() {
    let timerObj = this.scene.findObject($"room_{this.roomId}")
    if (checkObj(timerObj))
      timerObj.setUserData(this)
  }

  function updateInfo() {
    this.threadInfo.updateInfoObj(this.scene)
  }

  function onSceneShow() {
    this.popDelayedActions()
  }

  function onUserInfo() {
    this.threadInfo.showOwnerMenu(null)
  }

  function onEditThread() {
    g_chat.openModifyThreadWnd(this.threadInfo)
  }

  function onEventChatThreadInfoChanged(p) {
    if (p?.roomId == this.roomId)
      this.doWhenActiveOnce("updateInfo")
  }

  function onEventChatFilterChanged(_p) {
    this.doWhenActiveOnce("updateInfo")
  }

  function onEventContactsGroupUpdate(_p) {
    this.doWhenActiveOnce("updateInfo")
  }

  function onEventSquadStatusChanged(_p) {
    this.doWhenActiveOnce("updateInfo")
  }

  function onEventContactsBlockStatusUpdated(_p) {
    this.doWhenActiveOnce("updateInfo")
  }

  function onThreadTimer(_obj, _dt) {
    this.threadInfo.checkRefreshThread()
  }
})