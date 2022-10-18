from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")

::gui_handlers.ChatThreadHeader <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  sceneTplName = "%gui/chat/chatThreadsListRows"

  roomId = ""
  threadInfo = null

  function getSceneTplView()
  {
    threadInfo = ::g_chat.addThreadInfoById(roomId)
    return {
      threads = [threadInfo]
      onlyInfo = true
      noSelect = true
      addTimer = true
    }
  }

  function initScreen()
  {
    let timerObj = this.scene.findObject("room_" + roomId)
    if (checkObj(timerObj))
      timerObj.setUserData(this)
  }

  function updateInfo()
  {
    threadInfo.updateInfoObj(this.scene)
  }

  function onSceneShow()
  {
    this.popDelayedActions()
  }

  function onUserInfo()
  {
    threadInfo.showOwnerMenu(null)
  }

  function onEditThread()
  {
    ::g_chat.openModifyThreadWnd(threadInfo)
  }

  function onEventChatThreadInfoChanged(p)
  {
    if (getTblValue("roomId", p) == roomId)
      this.doWhenActiveOnce("updateInfo")
  }

  function onEventChatFilterChanged(_p)
  {
    this.doWhenActiveOnce("updateInfo")
  }

  function onEventContactsGroupUpdate(_p)
  {
    this.doWhenActiveOnce("updateInfo")
  }

  function onEventSquadStatusChanged(_p)
  {
    this.doWhenActiveOnce("updateInfo")
  }

  function onEventContactsBlockStatusUpdated(_p) {
    this.doWhenActiveOnce("updateInfo")
  }

  function onThreadTimer(_obj, _dt)
  {
    threadInfo.checkRefreshThread()
  }
}