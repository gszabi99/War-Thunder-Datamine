class ::gui_handlers.ChatThreadHeader extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  sceneTplName = "gui/chat/chatThreadsListRows"

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
    local timerObj = scene.findObject("room_" + roomId)
    if (::checkObj(timerObj))
      timerObj.setUserData(this)
  }

  function updateInfo()
  {
    threadInfo.updateInfoObj(scene)
  }

  function onSceneShow()
  {
    popDelayedActions()
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
    if (::getTblValue("roomId", p) == roomId)
      doWhenActiveOnce("updateInfo")
  }

  function onEventChatFilterChanged(p)
  {
    doWhenActiveOnce("updateInfo")
  }

  function onEventContactsGroupUpdate(p)
  {
    doWhenActiveOnce("updateInfo")
  }

  function onEventSquadStatusChanged(p)
  {
    doWhenActiveOnce("updateInfo")
  }

  function onEventContactsBlockStatusUpdated(p) {
    doWhenActiveOnce("updateInfo")
  }

  function onThreadTimer(obj, dt)
  {
    threadInfo.checkRefreshThread()
  }
}