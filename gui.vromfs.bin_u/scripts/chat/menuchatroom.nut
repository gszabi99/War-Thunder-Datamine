//-file:plus-string
from "%scripts/dagui_natives.nut" import sync_handler_simulate_signal
from "%scripts/dagui_library.nut" import *
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { format } = require("string")
let { isChatEnableWithPlayer } = require("%scripts/chat/chatStates.nut")
let { endsWith, slice, cutPrefix } = require("%sqstd/string.nut")
let { get_charserver_time_sec } = require("chard")
let { USEROPT_MARK_DIRECT_MESSAGES_AS_PERSONAL, OPTIONS_MODE_GAMEPLAY
} = require("%scripts/options/optionsExtNames.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { userName } = require("%scripts/user/profileStates.nut")

enum MESSAGE_TYPE {
  MY          = "my"
  INCOMMING   = "incomming"
  SYSTEM      = "system"
  CUSTOM      = "custom"
}

let persistent = {
  lastCreatedMessageIndex = 0
}

let privateColor = "@chatTextPrivateColor"
let blockedColor = "@chatTextBlockedColor"
let systemColor = "@chatInfoColor"

registerPersistentData("MenuChatMessagesGlobals", persistent, ["lastCreatedMessageIndex"])

local function localizeSystemMsg(msg) {
  local localized = false
  foreach (ending in ["is set READONLY", "is set BANNED"]) {
    if (!endsWith(msg, ending))
      continue

    localized = true
    let locText = loc(ending, "")
    local playerName = slice(msg, 0, -ending.len() - 1)
    playerName = getPlayerName(playerName)
    if (locText != "")
      msg = format(locText, playerName)
    if (playerName == userName.value)
      sync_handler_simulate_signal("profile_reload")
    break
  }
  if (!localized)
    msg = loc(msg)
  return msg
}

local function colorMyNameInText(msg) {
  if (userName.value == "" || msg.len() < userName.value.len())
    return msg

  local counter = 0;
  msg = " " + msg + " "; //add temp spaces before name coloring

  while (counter + userName.value.len() <= msg.len()) {
    let nameStartPos = msg.indexof(userName.value, counter);
    if (nameStartPos == null)
      break;

    let nameEndPos = nameStartPos + userName.value.len();
    counter = nameEndPos;

    if (isInArray(msg.slice(nameStartPos - 1, nameStartPos), ::punctuation_list) &&
        isInArray(msg.slice(nameEndPos, nameEndPos + 1),     ::punctuation_list)) {
      let msgStart = msg.slice(0, nameStartPos);
      let msgEnd = msg.slice(nameEndPos);
      let msgName = msg.slice(nameStartPos, nameEndPos);
      let msgProcessedPart = msgStart + colorize(::g_chat.color.senderMe[false], msgName)
      msg = msgProcessedPart + msgEnd;
      counter = msgProcessedPart.len();
    }
  }
  msg = msg.slice(1, msg.len() - 1); //remove temp spaces after name coloring

  return msg
}

let function newMessage(from, msg, privateMsg = false, myPrivate = false, overlaySystemColor = null,
    important = false, needCensore = false) {
  let text = ""
  local clanTag = ""
  local uid = null
  local messageType = ""
  local msgColor = ""
  local userColor = ""
  let msgSrc = msg

  //from can be as string - Player nick, and as table - player contact.
  //after getting type, and acting accordingly, name must be string and mean name of player
  if (type(from) != "instance") {
    if (from in ::clanUserTable)
      clanTag = ::clanUserTable[from]
  }
  else {
    uid = from.uid
    clanTag = from.clanTag
    from = from.name
  }

  let needMarkDirectAsPersonal = ::get_gui_option_in_mode(USEROPT_MARK_DIRECT_MESSAGES_AS_PERSONAL,
    OPTIONS_MODE_GAMEPLAY)
  if (needMarkDirectAsPersonal && userName.value != "" && from != userName.value
    && msg.indexof(userName.value) != null
  )
    important = true

  if (myPrivate)
    from = userName.value
  let myself = from == userName.value

  if (::g_chat.isSystemUserName(from)) {
    from = ""
    msg = localizeSystemMsg(msg)
  }

  if (from == "") {
    msgColor = overlaySystemColor ? overlaySystemColor : systemColor
    messageType = MESSAGE_TYPE.SYSTEM
  }
  else {
    userColor = ::g_chat.getSenderColor(from, true, privateMsg)

    if (needCensore)
      msg = ::g_chat.filterMessageText(msg, myself)

    msgColor = privateMsg ? privateColor : ""

    if (overlaySystemColor) {
      msgColor = overlaySystemColor
    }
    else if (!myPrivate && ::isPlayerNickInContacts(from, EPL_BLOCKLIST)) {
      if (privateMsg)
        return null

      userColor = blockedColor
      msgColor = blockedColor
      msg = ::g_chat.makeBlockedMsg(msg)
    }
    else if (!myself && !myPrivate && !isChatEnableWithPlayer(from)) {
      if (privateMsg)
        return null

      userColor = blockedColor
      msgColor = blockedColor
      msg = ::g_chat.makeXBoxRestrictedMsg(msg)
    }
    else
      msg = colorMyNameInText(msg)

    messageType = myself ? MESSAGE_TYPE.MY : MESSAGE_TYPE.INCOMMING
  }

  if (msgColor != "")
    msg = colorize(msgColor, msg)

  return {
    fullName = ::g_contacts.getPlayerFullName(getPlayerName(from), clanTag)
    from = from
    uid = uid
    clanTag = clanTag
    userColor = userColor
    isMeSender = messageType == MESSAGE_TYPE.MY
    isSystemSender = messageType == MESSAGE_TYPE.SYSTEM

    msgs = [msg]
    msgsSrc = [msgSrc]
    msgColor = msgColor

    important = important
    messageType = messageType

    text = text

    sTime = get_charserver_time_sec()

    messageIndex = 0
  }
}

let function newRoom(id, customScene = null, ownerHandler = null) {
  let rType = ::g_chat_room_type.getRoomType(id)
  local r = {
    id = id

    type = rType
    canBeClosed = rType.canBeClosed(id)
    havePlayersList = rType.havePlayersList
    hasCustomViewHandler = rType.hasCustomViewHandler

    customScene = customScene
    ownerHandler = ownerHandler

    joined = true
    hidden = customScene != null
    concealed = @() rType.isConcealed(id)

    existOnlyInCustom = customScene != null
    isCustomScene = customScene != null

    users = []
    mBlocks = []

    lastTextInput = ""
    joinParams = ""
    roomJoinedIdx = 0
    newImportantMessagesCount = 0

    function addMessage(mBlock) {
      mBlock = clone mBlock
      if (this.mBlocks.len() > 0 && !this.isCustomScene && this.mBlocks.top().from == mBlock.from && mBlock.from != "") {
        this.mBlocks.top().msgs.extend(mBlock.msgs)
        this.mBlocks.top().msgsSrc.extend(mBlock.msgsSrc)
        mBlock = this.mBlocks.top()
      }
      else {
        mBlock.messageType = this.isCustomScene ? MESSAGE_TYPE.CUSTOM : mBlock.messageType
        this.mBlocks.append(mBlock)
      }

      if (::g_chat.isRoomClan(id))
        mBlock.clanTag = ""

      if (mBlock.text == "" && mBlock.from != "") {
          let pLink = ::g_chat.generatePlayerLink(mBlock.from, mBlock.uid)
          mBlock.text = format("<Link=%s><Color=%s>%s</Color>:</Link> ", pLink, mBlock.userColor,
            mBlock.fullName)
      }

      mBlock.text += (!this.isCustomScene ? "\n" : "") + mBlock.msgs.top()
      mBlock.messageIndex = persistent.lastCreatedMessageIndex++

      if (this.mBlocks.len() > ::g_chat.getMaxRoomMsgAmount())
        this.mBlocks.remove(0)
    }

    function clear() {
      this.mBlocks = []
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
      let logObj = this.mBlocks.map(@(mBlock) {
        from = mBlock.from
        userColor = mBlock.userColor != "" ? get_main_gui_scene().getConstantValue(cutPrefix(mBlock.userColor, "@")) : ""
        fromUid = mBlock.uid
        clanTag = mBlock.clanTag
        msgs = mBlock.msgsSrc
        msgColor = mBlock.msgColor != "" ? get_main_gui_scene().getConstantValue(cutPrefix(mBlock.msgColor, "@")) : ""
        sTime = mBlock.sTime
      })
      return this.chatLogFormatForBanhammer().__merge({ chatLog = logObj })
    }

    getRoomName = @(isColored = false) rType.getRoomName(id, isColored)
  }

  return r
}

let function initChatMessageListOn(sceneObject, handler, customRoomId = null) {
  let messages = []
  for (local i = 0; i < ::g_chat.getMaxRoomMsgAmount(); i++) {
    messages.append({ childIndex = i });
  }
  let view = { messages = messages, customRoomId = customRoomId }
  let messageListView = handyman.renderCached("%gui/chat/chatMessageList.tpl", view)
  sceneObject.getScene().replaceContentFromText(sceneObject,
    messageListView, messageListView.len(), handler)
}

return {
  newRoom
  newMessage
  initChatMessageListOn
}