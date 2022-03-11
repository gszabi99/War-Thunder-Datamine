class ::g_invites_classes.ChatRoom extends ::BaseInvite
{
  //custom class params, not exist in base invite
  roomId = ""
  roomType = ::g_chat_room_type.DEFAULT_ROOM

  static function getUidByParams(params)
  {
    return "CR_" + ::getTblValue("inviterName", params, "") + "/" + ::getTblValue("roomId", params, "")
  }

  function updateCustomParams(params, initial = false)
  {
    roomId = ::getTblValue("roomId", params, "")
    roomType = ::g_chat_room_type.getRoomType(roomId)

    if (roomType == ::g_chat_room_type.THREAD)
    {
      local threadInfo = ::g_chat.addThreadInfoById(roomId)
      threadInfo.checkRefreshThread()
      if (threadInfo.lastUpdateTime < 0)
        setDelayed(true)
      if (initial)
        ::add_event_listener("ChatThreadInfoChanged",
                             function (data) {
                               if (::getTblValue("roomId", data) == roomId)
                                 setDelayed(false)
                             },
                             this)
    }
    else if (roomType == ::g_chat_room_type.SQUAD
             && inviterName == ::g_squad_manager.getLeaderNick())
      autoAccept()
  }

  function isValid()
  {
    return roomId != "" && roomType.isAllowed() && !haveRestrictions()
  }

  function haveRestrictions()
  {
    return !isAvailableByChatRestriction()
  }

  function getChatInviteText()
  {
    local nameF = "<Link=%s><Color="+inviteActiveColor+">%s</Color></Link>"

    local clickNameText = roomType.getInviteClickNameText(roomId)
    return ::loc(roomType.inviteLocIdFull,
                 { player = format(nameF, getChatInviterLink(), getInviterName()),
                   channel = format(nameF, getChatLink(), clickNameText) })
  }

  function getInviteText()
  {
    return ::loc(roomType.inviteLocIdNoNick,
                 {
                   channel = roomType.getRoomName(roomId)
                 })
  }

  function getPopupText()
  {
    return ::loc(roomType.inviteLocIdFull,
                 {
                   player = getInviterName()
                   channel = roomType.getRoomName(roomId)
                 })
  }

  function getIcon()
  {
    if (roomType == ::g_chat_room_type.SQUAD)
      return ""

    return roomType.inviteIcon
  }

  function accept()
  {
    if (!::menu_chat_handler)
      return

    ::menu_chat_handler.popupAcceptInvite(roomId)
    remove()
  }
}