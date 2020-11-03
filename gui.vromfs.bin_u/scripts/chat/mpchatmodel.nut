local { isChatEnabled, isChatEnableWithPlayer } = require("scripts/chat/chatStates.nut")

local mpChatState = {
  log = []
  currentModeId = null
  PERSISTENT_DATA_PARAMS = ["log"]
}

local mpChatModel = {
  maxLogSize = 20

  function init() {
    maxLogSize = ::g_chat.getMaxRoomMsgAmount()
  }

  function getLog() {
    return mpChatState.log
  }

  function setLog(log) {
    mpChatState.log = log
  }

  chatLogFormatForBanhammer = @() {
      category = ""
      title = ""
      ownerUid = ""
      ownerNick = ""
      roomName = ""
      location = ""
      clanInfo = ""
      chatLog = null
  }

  function getLogForBanhammer() {
    local log = mpChatState.log.map(@(message) {
      from = message.sender
      userColor = message.userColor != "" ? ::get_main_gui_scene().getConstantValue(::g_string.cutPrefix(message.userColor, "@")) : ""
      fromUid = message.uid
      clanTag = message.clanTag
      msgs = [message.text]
      msgColor = message.msgColor != "" ? ::get_main_gui_scene().getConstantValue(::g_string.cutPrefix(message.msgColor, "@")) : ""
      mode = message.mode
      sTime = message.sTime
    })
    return chatLogFormatForBanhammer().__merge({ chatLog = log })
  }

  function onInternalMessage(str) {
    onIncomingMessage("", str, false, CHAT_MODE_ALL, true)
  }


  function onIncomingMessage(sender, msg, enemy, mode, automatic) {
    if ( (!isChatEnabled()
         || mode == ::CHAT_MODE_PRIVATE
         || !isChatEnableWithPlayer(sender))
        && !automatic) {
      return false
    }

    local player = u.search(::get_mplayers_list(::GET_MPLAYERS_LIST, true), @(p) p.name == sender)

    local message = {
      userColor = ""
      msgColor = ""
      clanTag = ""
      uid = null
      sender = sender
      text = msg
      isMyself = sender == ::my_user_name
      isBlocked = ::isPlayerNickInContacts(sender, ::EPL_BLOCKLIST)
      isAutomatic = automatic
      mode = mode
      time = ::get_usefull_total_time()
      sTime = ::get_charserver_time_sec()

      team = player ? player.team:0
    }

    if (mpChatState.log.len() > maxLogSize) {
      mpChatState.log.remove(0)
    }
    mpChatState.log.append(message)

    ::broadcastEvent("MpChatLogUpdated")
    ::call_darg("mpChatPushMessage", message)
    return true
  }


  function clearLog() {
    onChatClear()
    ::broadcastEvent("MpChatLogUpdated")
  }


  function onModeChanged(modeId, playerName) {
    if (mpChatState.currentModeId == modeId)
      return

    mpChatState.currentModeId = modeId
    ::call_darg("mpChatModeChange", modeId)
    ::broadcastEvent("MpChatModeChanged", { modeId = mpChatState.currentModeId})
  }


  function onInputChanged(str) {
    ::call_darg("mpChatInputChanged", str)
    ::broadcastEvent("MpChatInputChanged", {str = str})
  }


  function onChatClear() {
    mpChatState.log.clear()
    ::call_darg("mpChatClear")
  }


  function unblockMessage(text) {
    foreach (message in mpChatState.log) {
      if (message.text == text) {
        message.isBlocked = false
        return
      }
    }
  }

  function onModeSwitched() {
    local newModeId = ::g_mp_chat_mode.getNextMode(mpChatState.currentModeId)
    if (newModeId == null)
      return

    ::chat_set_mode(newModeId, "")
  }
}


::g_script_reloader.registerPersistentData(
  "mpChatState",
  mpChatState,
  ["log", "currentModeId"]
)

::set_chat_handler(mpChatModel)
return mpChatModel
