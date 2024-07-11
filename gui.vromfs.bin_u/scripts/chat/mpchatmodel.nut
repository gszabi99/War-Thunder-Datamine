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

let mpChatState = persist("mpChatState", @() {
  log = [],
  currentModeId = null,
  maxLogSize = 20
})

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

function initMpChatModel() {
  mpChatState.maxLogSize = ::g_chat.getMaxRoomMsgAmount()
}

function getLogForBanhammer() {
  let logObj = mpChatState.log.map(@(message) {
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

function onChatClear() {
  mpChatState.log.clear()
  eventbus_send("mpChatClear", {})
}

function clearMpChatLog() {
  onChatClear()
  broadcastEvent("MpChatLogUpdated")
}

function getMpChatLog() {
  return mpChatState.log
}

function setMpChatLog(l) {
  mpChatState.log = l
}

function onIncomingMessage(sender, msg, _enemy, mode, automatic) {
  checkChatEnableWithPlayer(sender, function(canChat) {
    if ((!isChatEnabled() || mode == CHAT_MODE_PRIVATE || !canChat) && !automatic)
      return

    let player = get_mplayer_by_name(sender)

    let message = {
      userColor = ""
      msgColor = ""
      clanTag = ""
      uid = player?.userId.tointeger()
      sender = sender
      text = msg
      isMyself = sender == userName.value || getRealName(sender) == userName.value
      isBlocked = ::isPlayerNickInContacts(sender, EPL_BLOCKLIST)
      isAutomatic = automatic
      mode = mode
      time = get_mission_time()
      sTime = get_charserver_time_sec()
      team = player?.team ?? MP_TEAM_NEUTRAL
    }

    if (mpChatState.log.len() > mpChatState.maxLogSize) {
      mpChatState.log.remove(0)
    }
    mpChatState.log.append(message)

    broadcastEvent("MpChatLogUpdated")
    eventbus_send("mpChatPushMessage", message.__merge({
      fullName = sender == "" ? ""
        : ::g_contacts.getPlayerFullName(getPlayerName(sender), message.clanTag)
    }))
  })
}

function onInternalMessage(str) {
    onIncomingMessage("", str, false, CHAT_MODE_ALL, true)
}

function unblockMessage(text) {
  foreach (message in mpChatState.log) {
    if (message.text == text) {
      message.isBlocked = false
      return
    }
  }
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
  eventbus_send("hudChatModeIdUpdate", { modeId })
  broadcastEvent("MpChatModeChanged", { modeId = mpChatState.currentModeId })
}

function onInputChanged(str) {
  eventbus_send("mpChatInputChanged", { str })
  broadcastEvent("MpChatInputChanged", { str = str })
}

function onModeSwitched() {
  let newModeId = ::g_mp_chat_mode.getNextMode(mpChatState.currentModeId)
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

set_chat_handler(mpChatModel)
return {
  initMpChatModel
  getLogForBanhammer
  clearMpChatLog
  getMpChatLog
  setMpChatLog
  onIncomingMessage
  onInternalMessage
  unblockMessage
}
