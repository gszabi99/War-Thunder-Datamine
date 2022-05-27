let lobbyStates = require("%scripts/matchingRooms/lobbyStates.nut")

::gui_handlers.JoiningGameWaitBox <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/msgBox.blk"
  timeToShowCancel = 30
  timer = -1

  function initScreen()
  {
    scene.findObject("msgWaitAnimation").show(true)
    scene.findObject("msg_box_timer").setUserData(this)
    updateInfo()
  }

  function onEventLobbyStatusChange(params)
  {
    updateInfo()
  }

  function onEventEventsDataUpdated(params)
  {
    updateInfo()
  }

  function updateInfo()
  {
    if (!::SessionLobby.isInJoiningGame())
      return goBack()

    resetTimer() //statusChanged
    checkGameMode()

    let misData = ::SessionLobby.getMissionParams()
    local msg = ::loc("wait/sessionJoin")
    if (::SessionLobby.status == lobbyStates.UPLOAD_CONTENT)
      msg = ::loc("wait/sessionUpload")
    if (misData)
      msg = "".concat(msg, "\n\n", ::colorize("activeTextColor", getCurrentMissionGameMode()),
        "\n", ::colorize("userlogColoredText", getCurrentMissionName()))

    scene.findObject("msgText").setValue(msg)
  }

  function getCurrentMissionGameMode()
  {
    local gameModeName = ::get_cur_game_mode_name()
    if (gameModeName == "domination")
    {
      let event = ::SessionLobby.getRoomEvent()
      if (event == null)
        return ""

      if (::events.getEventDisplayType(event) != ::g_event_display_type.RANDOM_BATTLE)
        gameModeName = "event"
    }
    return ::loc("multiplayer/" + gameModeName + "Mode")
  }

  function getCurrentMissionName()
  {
    if (::get_game_mode() == ::GM_DOMINATION)
    {
      let event = ::SessionLobby.getRoomEvent()
      if (event)
        return ::events.getEventNameText(event)
    }
    else
    {
      let misName = ::SessionLobby.getMissionNameLoc()
      if (misName != "")
        return misName
    }
    return ""
  }

  function checkGameMode()
  {
    let gm = ::SessionLobby.getGameMode()
    let curGm = ::get_game_mode()
    if (gm < 0 || curGm==gm)
      return

    ::set_mp_mode(gm)
    if (mainGameMode < 0)
      mainGameMode = curGm  //to restore gameMode after close window
  }

  function showCancelButton(show)
  {
    let btnId = "btn_cancel"
    local obj = scene.findObject(btnId)
    if (obj)
    {
      obj.show(show)
      obj.enable(show)
      if (show)
        ::move_mouse_on_obj(obj)
      return
    }
    if (!show)
      return

    let data = format(
      "Button_text{id:t='%s'; btnName:t='AB'; text:t='#msgbox/btn_cancel'; on_click:t='onCancel'}",
      btnId)
    let holderObj = scene.findObject("buttons_holder")
    if (!holderObj)
      return

    guiScene.appendWithBlk(holderObj, data, this)
    obj = scene.findObject(btnId)
    ::move_mouse_on_obj(obj)
  }

  function resetTimer()
  {
    timer = timeToShowCancel
    showCancelButton(false)
  }

  function onUpdate(obj, dt)
  {
    if (timer < 0)
      return
    timer -= dt
    if (timer < 0)
      showCancelButton(true)
  }

  function onCancel()
  {
    guiScene.performDelayed(this, function()
    {
      if (timer >= 0)
        return
      ::destroy_session_scripted()
      ::SessionLobby.leaveRoom()
    })
  }
}

return {
  open = @() ::gui_start_modal_wnd(::gui_handlers.JoiningGameWaitBox)
}
