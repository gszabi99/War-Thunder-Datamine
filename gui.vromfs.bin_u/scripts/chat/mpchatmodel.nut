from "%scripts/dagui_library.nut" import *
let { isChatEnabled, checkChatEnableWithPlayer } = require("%scripts/chat/chatStates.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getRealName } = require("%scripts/user/nameMapping.nut")
let { eventbus_send } = require("eventbus")
let { set_chat_handler, CHAT_MODE_ALL, CHAT_MODE_PRIVATE, chat_set_mode } = require("chat")
let { cutPrefix } = require("%sqstd/string.nut")
let { get_mission_time, get_mplayer_by_name } = require("mission")
let { get_charserver_time_sec } = require("chard")
let { userName } = require("%scripts/user/profileStates.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { getMpChatLog, addMessageToLog, onChatClear, getCurrentModeId, setCurrentModeId
} = require("%scripts/chat/mpChatState.nut")
let { register_command } = require("console")
let { g_mp_chat_mode } =require("%scripts/chat/mpChatMode.nut")
let { isPlayerNickInContacts } = require("%scripts/contacts/contactsChecks.nut")

let chatLogFormatForBanhammer = {
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
  let logObj = getMpChatLog().map(@(message) {
    from = message.sender
    userColor = message.userColor != "" ? get_main_gui_scene().getConstantValue(cutPrefix(message.userColor, "@")) : ""
    fromUid = message.uid
    clanTag = message.clanTag
    msgs = [message.text]
    msgColor = message.msgColor != "" ? get_main_gui_scene().getConstantValue(cutPrefix(message.msgColor, "@")) : ""
    mode = message.mode
    sTime = message.sTime
    time = message.time
  })
  return chatLogFormatForBanhammer.__merge({ chatLog = logObj })
}

function removeForbiddenCharacters(msg) {
  return msg.replace("\\n", " ")
}

function clearMpChatLog() {
  onChatClear()
  broadcastEvent("MpChatLogUpdated")
}

function onIncomingMessageImpl(sender, msg, mode, automatic) {
  let player = get_mplayer_by_name(sender)
  let message = {
    userColor = ""
    msgColor = ""
    clanTag = ""
    uid = player?.userId.tointeger()
    sender = sender
    text = msg
    isMyself = sender == userName.value || getRealName(sender) == userName.value
    isBlocked = isPlayerNickInContacts(sender, EPL_BLOCKLIST)
    isAutomatic = automatic
    mode = mode
    time = get_mission_time()
    sTime = get_charserver_time_sec()
    team = player?.team ?? MP_TEAM_NEUTRAL
  }

  addMessageToLog(message)
  broadcastEvent("MpChatLogUpdated")
  eventbus_send("mpChatPushMessage", message.__merge({
    fullName = sender == "" ? ""
      : ::g_contacts.getPlayerFullName(getPlayerName(sender), message.clanTag)
  }))
}

function onIncomingMessage(sender, msg, _enemy, mode, automatic) {
  if (automatic) {
    onIncomingMessageImpl(sender, msg, mode, automatic)
    return
  }
  if (!isChatEnabled() || mode == CHAT_MODE_PRIVATE)
    return

  checkChatEnableWithPlayer(sender, function(canChat) {
    if (!canChat)
      return

    onIncomingMessageImpl(sender, removeForbiddenCharacters(msg), mode, automatic)
  })
}

function onInternalMessage(str) {
    onIncomingMessage("", str, false, CHAT_MODE_ALL, true)
}

function onModeChanged(modeId, _playerName) {
  let currentModeId = getCurrentModeId()
  if (currentModeId == modeId)
    return

  if (!g_mp_chat_mode.getModeById(modeId).isEnabled()) {
    let isEnabledCurMod = currentModeId != null
      && g_mp_chat_mode.getModeById(currentModeId).isEnabled()
    let enabledModId = isEnabledCurMod ? currentModeId
      : g_mp_chat_mode.getNextMode(currentModeId)
    if (enabledModId != null)
      chat_set_mode(enabledModId, "")
    return
  }

  setCurrentModeId(modeId)
  eventbus_send("hudChatModeIdUpdate", { modeId })
  broadcastEvent("MpChatModeChanged", { modeId })
}

function onInputChanged(str) {
  eventbus_send("mpChatInputChanged", { str })
  broadcastEvent("MpChatInputChanged", { str = str })
}

function onModeSwitched() {
  let newModeId = g_mp_chat_mode.getNextMode(getCurrentModeId())
  if (newModeId == null)
    return

  chat_set_mode(newModeId, "")
}

let mpChatModel = {
  onIncomingMessage
  onInternalMessage
  clearLog = clearMpChatLog
  onChatClear
  onModeChanged
  onInputChanged
  onModeSwitched
}

register_command(
  function(count) {
    for (local i = 0; i < count; i++) {
      onIncomingMessage("Kawakaze_Aki", "Attention to the map!<color=#FF96966E> [b5]</color>", null, 0, false)
      onIncomingMessage("F16C1978@live", "ok ill go taxi in", null, 1, false)
      onIncomingMessage("Iridescenzza", "and based material", null, 2, false)
    }
  }
"mpChatModel.onIncomingMessage")

set_chat_handler(mpChatModel)
return {
  getLogForBanhammer
  clearMpChatLog
  onIncomingMessage
  onInternalMessage
  chatSystemMessage = @(text) onIncomingMessage("", text, false, 0, true)
}
