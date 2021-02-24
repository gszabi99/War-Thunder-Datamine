local platformModule = require("scripts/clientState/platform.nut")
local { isChatEnableWithPlayer } = require("scripts/chat/chatStates.nut")

enum MESSAGE_TYPE {
  MY          = "my"
  INCOMMING   = "incomming"
  SYSTEM      = "system"
  CUSTOM      = "custom"
}

local persistent = {
  lastCreatedMessageIndex = 0
}

local privateColor = "@chatTextPrivateColor"
local blockedColor = "@chatTextBlockedColor"
local systemColor = "@chatInfoColor"

::g_script_reloader.registerPersistentData("MenuChatMessagesGlobals", persistent, ["lastCreatedMessageIndex"])

local function filterSystemUserMsg(msg)
{
  msg = ::g_chat.filterMessageText(msg, false)
  local localized = false
  foreach(ending in ["is set READONLY", "is set BANNED"])
  {
    if (!::g_string.endsWith(msg, ending))
      continue

    localized = true
    local locText = ::loc(ending, "")
    local playerName = ::g_string.slice(msg, 0, -ending.len() - 1)
    playerName = platformModule.getPlayerName(playerName)
    if (locText != "")
      msg = ::format(locText, playerName)
    if (playerName == ::my_user_name)
      ::sync_handler_simulate_signal("profile_reload")
    break
  }
  if (!localized)
    msg = ::loc(msg)
  return msg
}

local function colorMyNameInText(msg)
{
  if (::my_user_name=="" || msg.len() < ::my_user_name.len())
    return msg

  local counter = 0;
  msg = " " + msg + " "; //add temp spaces before name coloring

  while (counter+::my_user_name.len() <= msg.len())
  {
    local nameStartPos = msg.indexof(::my_user_name, counter);
    if (nameStartPos == null)
      break;

    local nameEndPos = nameStartPos + ::my_user_name.len();
    counter = nameEndPos;

    if (::isInArray(msg.slice(nameStartPos-1, nameStartPos), ::punctuation_list) &&
        ::isInArray(msg.slice(nameEndPos, nameEndPos+1),     ::punctuation_list))
    {
      local msgStart = msg.slice(0, nameStartPos);
      local msgEnd = msg.slice(nameEndPos);
      local msgName = msg.slice(nameStartPos, nameEndPos);
      local msgProcessedPart = msgStart + ::colorize(::g_chat.color.senderMe[false], msgName)
      msg = msgProcessedPart + msgEnd;
      counter = msgProcessedPart.len();
    }
  }
  msg = msg.slice(1, msg.len()-1); //remove temp spaces after name coloring

  return msg
}

local function newMessage(from, msg, privateMsg = false, myPrivate = false, overlaySystemColor = null,
    important = false, needCensore = false, isMyActionInfo = false) {
  local text = ""
  local clanTag = ""
  local uid = null
  local messageType = ""
  local msgColor = ""
  local userColor = ""
  local msgSrc = msg

  //from can be as string - Player nick, and as table - player contact.
  //after getting type, and acting accordingly, name must be string and mean name of player
  if (typeof(from) != "instance") {
    if (from in ::clanUserTable)
      clanTag = ::clanUserTable[from]
  } else {
    uid = from.uid
    clanTag = from.clanTag
    from = from.name
  }

  local needMarkDirectAsPersonal = ::get_gui_option_in_mode(::USEROPT_MARK_DIRECT_MESSAGES_AS_PERSONAL,
    ::OPTIONS_MODE_GAMEPLAY)
  if (needMarkDirectAsPersonal && from != ::my_user_name && msg.indexof(::my_user_name) != null)
    important = true

  if (myPrivate)
    from = ::my_user_name
  local myself = from == ::my_user_name

  if (::g_chat.isSystemUserName(from)) {
    from = ""
    msg = filterSystemUserMsg(msg)
  }

  if (from == "") {
    msgColor = overlaySystemColor ? overlaySystemColor:systemColor
    messageType = MESSAGE_TYPE.SYSTEM
  } else {
    userColor = ::g_chat.getSenderColor(from, true, privateMsg)

    if (needCensore)
      msg = ::g_chat.filterMessageText(msg, myself)

    msgColor = privateMsg ? privateColor : ""

    if (overlaySystemColor) {
      msgColor = overlaySystemColor
    }
    else if (!myPrivate && ::isPlayerNickInContacts(from, ::EPL_BLOCKLIST))
    {
      if (privateMsg)
        return null

      userColor = blockedColor
      msgColor = blockedColor
      msg = ::g_chat.makeBlockedMsg(msg)
    }
    else if (!myself && !myPrivate && !isChatEnableWithPlayer(from))
    {
      if (privateMsg)
        return null

      userColor = blockedColor
      msgColor = blockedColor
      msg = ::g_chat.makeXBoxRestrictedMsg(msg)
    }
    else
      msg = colorMyNameInText(msg)

    messageType = myself ? MESSAGE_TYPE.MY:MESSAGE_TYPE.INCOMMING
  }

  if (msgColor != "")
    msg = ::colorize(msgColor, msg)

  return {
    fullName = ::g_contacts.getPlayerFullName(platformModule.getPlayerName(from), clanTag)
    from = from
    uid = uid
    clanTag = clanTag
    userColor = userColor
    isMeSender = messageType == MESSAGE_TYPE.MY
    isMyActionInfo = isMyActionInfo

    msgs = [msg]
    msgsSrc = [msgSrc]
    msgColor = msgColor

    important = important
    messageType = messageType

    text = text

    sTime = ::get_charserver_time_sec()

    messageIndex = 0
  }
}

::newRoom <- function newRoom(id, customScene = null, ownerHandler = null) {
  local rType = ::g_chat_room_type.getRoomType(id)
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
      if (mBlocks.len() > 0 && !isCustomScene && mBlocks.top().from == mBlock.from && mBlock.from != "") {
        mBlocks.top().msgs.extend(mBlock.msgs)
        mBlocks.top().msgsSrc.extend(mBlock.msgsSrc)
        mBlock = mBlocks.top()
      } else {
        mBlock.messageType = isCustomScene ? MESSAGE_TYPE.CUSTOM:mBlock.messageType
        mBlocks.append(mBlock)
      }

      if(::g_chat.isRoomClan(id))
        mBlock.clanTag = ""

      if (mBlock.text == "" && mBlock.from != "") {
          local pLink = ::g_chat.generatePlayerLink(mBlock.from, mBlock.uid)
          mBlock.text = ::format("<Link=%s><Color=%s>%s</Color>:</Link> ", pLink, mBlock.userColor,
            mBlock.fullName)
      }

      mBlock.text += (!isCustomScene ? "\n":"") + mBlock.msgs.top()
      mBlock.messageIndex = persistent.lastCreatedMessageIndex++

      if (mBlocks.len() > ::g_chat.getMaxRoomMsgAmount())
        mBlocks.remove(0)
    }

    function clear() {
      mBlocks = []
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
      local log = mBlocks.map(@(mBlock) {
        from = mBlock.from
        userColor = mBlock.userColor != "" ? ::get_main_gui_scene().getConstantValue(::g_string.cutPrefix(mBlock.userColor, "@")) : ""
        fromUid = mBlock.uid
        clanTag = mBlock.clanTag
        msgs = mBlock.msgsSrc
        msgColor = mBlock.msgColor != "" ? ::get_main_gui_scene().getConstantValue(::g_string.cutPrefix(mBlock.msgColor, "@")) : ""
        sTime = mBlock.sTime
      })
      return chatLogFormatForBanhammer().__merge({ chatLog = log })
    }

    getRoomName = @(isColored = false) rType.getRoomName(id, isColored)
  }

  return r
}

::initChatMessageListOn <- function initChatMessageListOn(sceneObject, handler, customRoomId = null) {
  local messages = []
  for (local i = 0; i < ::g_chat.getMaxRoomMsgAmount(); i++) {
    messages.append({ childIndex = i });
  }
  local view = { messages = messages, customRoomId = customRoomId }
  local messageListView = ::handyman.renderCached("gui/chat/chatMessageList", view)
  sceneObject.getScene().replaceContentFromText(sceneObject,
    messageListView, messageListView.len(), handler)
}

return {
  newRoom = newRoom
  newMessage = newMessage
  initChatMessageListOn = initChatMessageListOn
}