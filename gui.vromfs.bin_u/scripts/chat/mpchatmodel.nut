//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { isChatEnabled, isChatEnableWithPlayer } = require("%scripts/chat/chatStates.nut")
let { PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { getRealName } = require("%scripts/user/nameMapping.nut")
let { send } = require("eventbus")
let { CHAT_MODE_ALL, CHAT_MODE_PRIVATE, chat_set_mode } = require("chat")

let mpChatState = {
  log = [],
  currentModeId = null,
  [PERSISTENT_DATA_PARAMS] = ["log"]
}

let chatLogFormatForBanhammer = @() {
  category = ""
  title = ""
  ownerUid = ""
  ownerNick = ""
  roomName = ""
  location = ""
  clanInfo = ""
  chatLog = null
}

local mpChatModel = {
  maxLogSize = 20

  function init() {
    this.maxLogSize = ::g_chat.getMaxRoomMsgAmount()
  }

  function getLog() {
    return mpChatState.log
  }

  function setLog(l) {
    mpChatState.log = l
  }

  function getLogForBanhammer() {
    let logObj = mpChatState.log.map(@(message) {
      from = message.sender
      userColor = message.userColor != "" ? ::get_main_gui_scene().getConstantValue(::g_string.cutPrefix(message.userColor, "@")) : ""
      fromUid = message.uid
      clanTag = message.clanTag
      msgs = [message.text]
      msgColor = message.msgColor != "" ? ::get_main_gui_scene().getConstantValue(::g_string.cutPrefix(message.msgColor, "@")) : ""
      mode = message.mode
      sTime = message.sTime
    })
    return chatLogFormatForBanhammer().__merge({ chatLog = logObj })
  }

  function onInternalMessage(str) {
    this.onIncomingMessage("", str, false, CHAT_MODE_ALL, true)
  }


  function onIncomingMessage(sender, msg, _enemy, mode, automatic) {
    if ((!isChatEnabled()
         || mode == CHAT_MODE_PRIVATE
         || !isChatEnableWithPlayer(sender))
        && !automatic) {
      return false
    }

    let player = ::u.search(::get_mplayers_list(GET_MPLAYERS_LIST, true), @(p) p.name == sender)

    let message = {
      userColor = ""
      msgColor = ""
      clanTag = ""
      uid = null
      sender = sender
      text = msg
      isMyself = sender == ::my_user_name || getRealName(sender) == ::my_user_name
      isBlocked = ::isPlayerNickInContacts(sender, EPL_BLOCKLIST)
      isAutomatic = automatic
      mode = mode
      time = ::get_usefull_total_time()
      sTime = ::get_charserver_time_sec()

      team = player ? player.team : 0
    }

    if (mpChatState.log.len() > this.maxLogSize) {
      mpChatState.log.remove(0)
    }
    mpChatState.log.append(message)

    ::broadcastEvent("MpChatLogUpdated")
    send("mpChatPushMessage", message)
    return true
  }


  function clearLog() {
    this.onChatClear()
    ::broadcastEvent("MpChatLogUpdated")
  }


  function onModeChanged(modeId, _playerName) {
    if (mpChatState.currentModeId == modeId)
      return

    if (!::g_mp_chat_mode.getModeById(modeId).isEnabled()) {
      let isEnabledCurMod = mpChatState.currentModeId != null
        && ::g_mp_chat_mode.getModeById(mpChatState.currentModeId).isEnabled()
      let enabledModId = isEnabledCurMod ? mpChatState.currentModeId
        : ::g_mp_chat_mode.getNextMode(mpChatState.currentModeId)
      if (enabledModId != null)
        chat_set_mode(enabledModId, "")
      return
    }

    mpChatState.currentModeId = modeId
    send("hudChatModeIdUpdate", { modeId })
    ::broadcastEvent("MpChatModeChanged", { modeId = mpChatState.currentModeId })
  }


  function onInputChanged(str) {
    send("mpChatInputChanged", { str })
    ::broadcastEvent("MpChatInputChanged", { str = str })
  }


  function onChatClear() {
    mpChatState.log.clear()
    send("mpChatClear", {})
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
    let newModeId = ::g_mp_chat_mode.getNextMode(mpChatState.currentModeId)
    if (newModeId == null)
      return

    chat_set_mode(newModeId, "")
  }
}


::g_script_reloader.registerPersistentData(
  "mpChatState",
  mpChatState,
  ["log", "currentModeId"]
)

::set_chat_handler(mpChatModel)
return mpChatModel
