from "%scripts/dagui_natives.nut" import sync_handler_simulate_signal, clan_get_my_clan_tag
from "%scripts/dagui_library.nut" import *

let { g_chat } = require("%scripts/chat/chat.nut")
let { g_chat_room_type } = require("%scripts/chat/chatRoomType.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { format } = require("string")
let { checkChatEnableWithPlayer } = require("%scripts/chat/chatStates.nut")
let { endsWith, slice, cutPrefix } = require("%sqstd/string.nut")
let { get_charserver_time_sec } = require("chard")
let { USEROPT_MARK_DIRECT_MESSAGES_AS_PERSONAL, OPTIONS_MODE_GAMEPLAY,
} = require("%scripts/options/optionsExtNames.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { userName } = require("%scripts/user/profileStates.nut")
let { clanUserTable, getContactByName } = require("%scripts/contacts/contactsListState.nut")
let { isPlayerNickInContacts } = require("%scripts/contacts/contactsChecks.nut")
let { getPlayerFullName } = require("%scripts/contacts/contactsInfo.nut")
let { get_gui_option_in_mode } = require("%scripts/options/options.nut")
let { isRoomClan } = require("%scripts/chat/chatRooms.nut")
let { filterMessageText, filterNameFromHtmlCodes } = require("%scripts/chat/chatUtils.nut")
let { getUserReputation, hasChatReputationFilter, getReputationBlockMessage
} = require("%scripts/user/usersReputation.nut")
let { ReputationType } = require("%globalScripts/chatState.nut")
let { getMyClanTag } = require("%scripts/user/clanName.nut")

enum MESSAGE_TYPE {
  MY          = "my"
  INCOMMING   = "incomming"
  SYSTEM      = "system"
  CUSTOM      = "custom"
}

let persistent = {
  lastCreatedMessageIndex = 0
}

let punctuation_list = [" ", ".", ",", ":", ";", "\"", "'", "~", "!", "@", "#", "$", "%", "^", "&", "*",
                       "(", ")", "+", "|", "-", "=", "\\", "/", "<", ">", "[", "]", "{", "}", "`", "?"]

let privateColor = "@chatTextPrivateColor"
let blockedColor = "@chatTextBlockedColor"
let systemColor = "@chatInfoColor"

registerPersistentData("MenuChatMessagesGlobals", persistent, ["lastCreatedMessageIndex"])

function localizeSystemMsg(msg) {
  local localized = false
  foreach (ending in ["is set READONLY", "is set BANNED"]) {
    if (!endsWith(msg, ending))
      continue

    localized = true
    let locText = loc(ending, "")
    let playerName = getPlayerName(filterNameFromHtmlCodes(slice(msg, 0, -ending.len() - 1)))
    if (locText != "")
      msg = format(locText, playerName)
    if (playerName == userName.get())
      sync_handler_simulate_signal("profile_reload")
    break
  }
  if (!localized)
    msg = loc(msg)
  return msg
}

function colorMyNameInText(msg) {
  if (userName.get() == "" || msg.len() < userName.get().len())
    return msg

  local counter = 0
  msg = $" {msg} " 

  while (counter + userName.get().len() <= msg.len()) {
    let nameStartPos = msg.indexof(userName.get(), counter)
    if (nameStartPos == null)
      break

    let nameEndPos = nameStartPos + userName.get().len()
    counter = nameEndPos

    if (isInArray(msg.slice(nameStartPos - 1, nameStartPos), punctuation_list) &&
        isInArray(msg.slice(nameEndPos, nameEndPos + 1),     punctuation_list)) {
      let msgStart = msg.slice(0, nameStartPos)
      let msgEnd = msg.slice(nameEndPos)
      let msgName = msg.slice(nameStartPos, nameEndPos)
      let msgProcessedPart = $"{msgStart}{colorize(g_chat.color.senderMe[false], msgName)}"
      msg = $"{msgProcessedPart}{msgEnd}"
      counter = msgProcessedPart.len()
    }
  }
  msg = msg.slice(1, msg.len() - 1) 
  return msg
}

function newMessage(from, msg, privateMsg, myPrivate, overlaySystemColor, important, needCensore, callback) {
  let text = ""
  local clanTag = ""
  local uid = null
  local messageType = ""
  local msgColor = ""
  local userColor = ""
  local userReputation = ReputationType.REP_GOOD
  let msgSrc = msg

  local createMessage = function() {
    let mblock = {
      fullName = getPlayerFullName(getPlayerName(from), clanTag)
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
      userReputation = userReputation
      text = text
      sTime = get_charserver_time_sec()
      messageIndex = 0
    }
    return mblock
  }

  
  
  if (type(from) != "instance") {
    clanTag = clanUserTable.get()?[from] ?? clanTag
    clanTag = clanTag == clan_get_my_clan_tag() ? getMyClanTag() : clanTag
  } else {
    uid = from.uid
    clanTag = from.clanTag == clan_get_my_clan_tag() ? getMyClanTag() : from.clanTag
    from = from.name
  }

  let needMarkDirectAsPersonal = get_gui_option_in_mode(USEROPT_MARK_DIRECT_MESSAGES_AS_PERSONAL,
    OPTIONS_MODE_GAMEPLAY)
  if (needMarkDirectAsPersonal && userName.get() != "" && from != userName.get()
    && msg.indexof(userName.get()) != null
  )
    important = true

  if (myPrivate)
    from = userName.get()
  let myself = from == userName.get()

  if (g_chat.isSystemUserName(from)) {
    from = ""
    msg = localizeSystemMsg(msg)
  }

  if (from == "") {
    msgColor = overlaySystemColor ? overlaySystemColor : systemColor
    messageType = MESSAGE_TYPE.SYSTEM
  }
  else {
    userColor = g_chat.getSenderColor(from, true, privateMsg)
    messageType = myself ? MESSAGE_TYPE.MY : MESSAGE_TYPE.INCOMMING

    if (needCensore) {
      msg = filterMessageText(msg, myself)
      if (messageType != MESSAGE_TYPE.MY && hasChatReputationFilter()) {
        let senderContact = getContactByName(from)
        if (senderContact)
          userReputation = getUserReputation(senderContact.uid)
      }
    }

    msgColor = privateMsg ? privateColor : ""

    if (overlaySystemColor) {
      msgColor = overlaySystemColor
    }
    else if (!myPrivate && isPlayerNickInContacts(from, EPL_BLOCKLIST)) {
      if (privateMsg) {
        callback?(null)
        return
      }

      userColor = blockedColor
      msgColor = blockedColor
      msg = g_chat.makeBlockedMsg(msg)
    }
    else if (!myself && !myPrivate) {
      checkChatEnableWithPlayer(from, function(canChat) {
        if (!canChat) {
          if (privateMsg) {
            callback?(null)
            return
          }

          userColor = blockedColor
          msgColor = blockedColor
          msg = g_chat.makeXBoxRestrictedMsg(msg)
          callback?(createMessage())
        } else {
          msg = colorMyNameInText(msg)
          callback?(createMessage())
        }
      })
      return
    }
    else
      msg = colorMyNameInText(msg)
  }

  if (msgColor != "")
    msg = colorize(msgColor, msg)

  callback?(createMessage())
}

function newRoom(id, customScene = null, ownerHandler = null) {
  let rType = g_chat_room_type.getRoomType(id)
  local r = {
    id = id
    type = rType
    forceCanBeClosed = null
    canBeClosed = @() this.forceCanBeClosed != null ? this.forceCanBeClosed : rType.canBeClosed(id)
    havePlayersList = rType.havePlayersList
    hasCustomViewHandler = rType.hasCustomViewHandler

    customScene = customScene
    ownerHandler = ownerHandler

    joined = true
    hidden = customScene != null
    concealed = @(cb) rType.checkConcealed(id, cb)

    existOnlyInCustom = customScene != null
    isCustomScene = customScene != null

    users = []
    mBlocks = [] 
    mBlocksByUid = {}
    lastTextInput = ""
    joinParams = ""
    roomJoinedIdx = 0
    newImportantMessagesCount = 0

    function addMblock(mBlock) {
      this.mBlocks.append(mBlock)
      if (!mBlock.uid)
        return
      if (this.mBlocksByUid?[mBlock.uid] != null)
        this.mBlocksByUid[mBlock.uid].append(mBlock)
      else
        this.mBlocksByUid[mBlock.uid] <- [mBlock]
    }

    function removeMblockAt(idx) {
      let mBlock = this.mBlocks[idx]
      this.mBlocks.remove(idx)

      let userMessages = this.mBlocksByUid?[mBlock?.uid]
      local blokIdx = userMessages?.indexof(mBlock)
      if ((blokIdx ?? -1) < 0)
        return
      userMessages?.remove(blokIdx)
    }

    function addMessage(mBlock) {
      mBlock = clone mBlock

      if (this.mBlocks.len() > 0 && !this.isCustomScene && this.mBlocks.top().from == mBlock.from && mBlock.from != "") {
        this.mBlocks.top().msgs.extend(mBlock.msgs)
        this.mBlocks.top().msgsSrc.extend(mBlock.msgsSrc)
        mBlock = this.mBlocks.top()
      }
      else {
        mBlock.messageType = this.isCustomScene ? MESSAGE_TYPE.CUSTOM : mBlock.messageType
        this.addMblock(mBlock)
      }

      if (isRoomClan(id))
        mBlock.clanTag = ""

      this.updateMessageText(mBlock)

      mBlock.messageIndex = persistent.lastCreatedMessageIndex++
      if (this.mBlocks.len() > g_chat.getMaxRoomMsgAmount())
        this.removeMblockAt(0)
    }

    function updateMessageText(mBlock, needForceUpdate = false) {
      if (needForceUpdate)
        mBlock.text = ""

      if (mBlock.text == "" && mBlock.from != "") {
        let pLink = g_chat.generatePlayerLink(mBlock.from, mBlock.uid)
        mBlock.text = format("<Link=%s><Color=%s>%s</Color>:</Link> ", pLink, mBlock.userColor,
          mBlock.fullName)
      }

      let resText = mBlock.userReputation == ReputationType.REP_BAD
        ? getReputationBlockMessage()
        : mBlock.msgs.top()

      mBlock.text = "".concat(mBlock.text, !this.isCustomScene ? "\n" : "", resText)
    }

    function clear() {
      this.mBlocks = []
      this.mBlocksByUid = {}
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
    getLeaveMessage = @() loc(rType.leaveLocId)
  }

  return r
}

function initChatMessageListOn(sceneObject, handler, customRoomId = null) {
  let messages = []
  for (local i = 0; i < g_chat.getMaxRoomMsgAmount(); i++) {
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