from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

gui_handlers.ChatThreadHeader <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  sceneTplName = "%gui/chat/chatThreadsListRows.tpl"

  roomId = ""
  threadInfo = null

  function getSceneTplView() {
    this.threadInfo = ::g_chat.addThreadInfoById(this.roomId)
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
    ::g_chat.openModifyThreadWnd(this.threadInfo)
  }

  function onEventChatThreadInfoChanged(p) {
    if (getTblValue("roomId", p) == this.roomId)
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
}