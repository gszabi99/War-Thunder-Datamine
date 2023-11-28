//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { get_time_msec } = require("dagor.time")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { rnd } = require("dagor.random")
let { format, split_by_chars } = require("string")
let penalties = require("%scripts/penitentiary/penalties.nut")
let systemMsg = require("%scripts/utils/systemMsg.nut")
let playerContextMenu = require("%scripts/user/playerContextMenu.nut")
let dirtyWordsFilter = require("%scripts/dirtyWordsFilter.nut")
let { clearBorderSymbolsMultiline, endsWith, cutPrefix  } = require("%sqstd/string.nut")
let regexp2 = require("regexp2")
let { registerPersistentDataFromRoot, PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { USEROPT_CHAT_FILTER, USEROPT_SHOW_SOCIAL_NOTIFICATIONS, OPTIONS_MODE_GAMEPLAY
} = require("%scripts/options/optionsExtNames.nut")
let { get_game_settings_blk } = require("blkGetters")
let { userName } = require("%scripts/user/myUser.nut")
let { getCurLangInfo } = require("%scripts/langUtils/language.nut")

::g_chat <- {
  [PERSISTENT_DATA_PARAMS] = ["rooms", "threadsInfo", "userCaps", "userCapsGen",
                              "threadTitleLenMin", "threadTitleLenMax"]

  MAX_ROOM_MSGS = 50
  MAX_ROOM_MSGS_FOR_MODERATOR = 250
  MAX_MSG_LEN = 200
  MAX_ROOMS_IN_SEARCH = 20
  MAX_LAST_SEND_MESSAGES = 10
  MAX_MSG_VC_SHOW_TIMES = 2

  MAX_ALLOWED_DIGITS_IN_ROOM_NAME = 6
  MAX_ALLOWED_CHARACTERS_IN_ROOM_NAME = 15

  SYSTEM_MESSAGES_USER_ENDING = ".warthunder.com"

  SYSTEM_COLOR = "@chatInfoColor"

  CHAT_ERROR_NO_CHANNEL = "chat/error/403"

  validateRoomNameRegexp = regexp2(@"[  !""#$%&'()*+,./\\:;<=>?@\^`{|}~-]")

  THREADS_INFO_TIMEOUT_MSEC = 300000
  THREADS_INFO_CLEAN_PERIOD_MSEC = 150000  //check clean only on get new thread info
  THREAD_INFO_REFRESH_DELAY_MSEC = 60000

  CHAT_SYSTEM_MESSAGE_TIMEOUT_MSEC = 60000

  threadTitleLenMin = 8
  threadTitleLenMax = 160

  rooms = [] //for full room params list check addRoom( function in menuchat.nut //!!FIX ME must be here, or separate class
  threadsInfo = {}
  userCapsGen = 1 // effectively makes caps falsy
  userCaps = {
      ALLOWPOST     = 0
      ALLOWPRIVATE  = 0
      ALLOWJOIN     = 0
      ALLOWXTJOIN   = 0
      ALLOWSPAWN    = 0
      ALLOWXTSPAWN  = 0
      ALLOWINVITE   = 0
    }

  LOCALIZED_MESSAGE_PREFIX = "LMSG "

  color = { //better to allow player tune color sheme
    sender =         { [false] = "@mChatSenderColorDark",        [true] = "@mChatSenderColor" }
    senderMe =       { [false] = "@mChatSenderMeColorDark",      [true] = "@mChatSenderMeColor" }
    senderPrivate =  { [false] = "@mChatSenderPrivateColorDark", [true] = "@mChatSenderPrivateColor" }
    senderSquad =    { [false] = "@mChatSenderMySquadColorDark", [true] = "@mChatSenderMySquadColor" }
    senderFriend =   { [false] = "@mChatSenderFriendColorDark",  [true] = "@mChatSenderFriendColor" }
  }
}


//to test filters - use console "chat_filter_for_myself=true"
::chat_filter_for_myself <- false
::g_chat.filterMessageText <- function filterMessageText(text, isMyMessage) {
  if (::get_option(USEROPT_CHAT_FILTER).value &&
    (!isMyMessage || ::chat_filter_for_myself))
    return dirtyWordsFilter.checkPhrase(text)
  return text
}
::cross_call_api.filter_chat_message <- ::g_chat.filterMessageText


::g_chat.convertBlockedMsgToLink <- function convertBlockedMsgToLink(msg) {
  //space work as close link. but non-breakable space - work as other symbols.
  //rnd for duplicate blocked messages
  return format("BL_%02d_%s", rnd() % 99, ::stringReplace(msg, " ", nbsp))
}


::g_chat.convertLinkToBlockedMsg <- function convertLinkToBlockedMsg(link) {
  let prefixLen = 6 // Prefix is "BL_NN_", where NN are digits.
  return ::stringReplace(link.slice(prefixLen), nbsp, " ")
}


::g_chat.makeBlockedMsg <- function makeBlockedMsg(msg, replacelocId = "chat/blocked_message") {
  local link = this.convertBlockedMsgToLink(msg)
  return format("<Link=%s>%s</Link>", link, loc(replacelocId))
}

::g_chat.makeXBoxRestrictedMsg <- function makeXBoxRestrictedMsg(msg) {
  return this.makeBlockedMsg(msg, "chat/blocked_message/xbox_restriction")
}

::g_chat.checkBlockedLink <- function checkBlockedLink(link) {
  return !is_platform_xbox && (link.len() > 6 && link.slice(0, 3) == "BL_")
}


::g_chat.revealBlockedMsg <- function revealBlockedMsg(text, link) {
  let start = text.indexof("<Link=" + link)
  if (start == null)
    return text

  local end = text.indexof("</Link>", start)
  if (end == null)
    return text

  end += "</Link>".len()

  let msg = this.convertLinkToBlockedMsg(link)
  text = text.slice(0, start) + msg + text.slice(end)
  return text
}

::g_chat.checkChatConnected <- function checkChatConnected() {
  if (::gchat_is_connected())
    return true

  this.systemMessage(loc("chat/not_connected"))
  return false
}

::g_chat.nextSystemMessageTime <- 0
::g_chat.systemMessage <- function systemMessage(msg, needPopup = true, forceMessage = false) {
  if ((!forceMessage) && (this.nextSystemMessageTime > get_time_msec()))
    return

  this.nextSystemMessageTime = get_time_msec() + this.CHAT_SYSTEM_MESSAGE_TIMEOUT_MSEC

  if (::menu_chat_handler)
    ::menu_chat_handler.addRoomMsg("", "", msg)
  if (needPopup && ::get_gui_option_in_mode(USEROPT_SHOW_SOCIAL_NOTIFICATIONS, OPTIONS_MODE_GAMEPLAY))
    ::g_popups.add(null, colorize(this.SYSTEM_COLOR, msg))
}

::g_chat.getRoomById <- function getRoomById(id) {
  return u.search(this.rooms, function (room) { return room.id == id })
}

::g_chat.isRoomJoined <- function isRoomJoined(roomId) {
  let room = this.getRoomById(roomId)
  return room != null && room.joined
}

::g_chat._roomJoinedIdx <- 0
::g_chat.addRoom <- function addRoom(room) {
  room.roomJoinedIdx = this._roomJoinedIdx++
  this.rooms.append(room)

  this.rooms.sort(function(a, b) {
    if (a.type.tabOrder != b.type.tabOrder)
      return a.type.tabOrder < b.type.tabOrder ? -1 : 1
    if (a.roomJoinedIdx != b.roomJoinedIdx)
      return a.roomJoinedIdx < b.roomJoinedIdx ? -1 : 1
    return 0
  })
}

::g_chat.getMaxRoomMsgAmount <- function getMaxRoomMsgAmount() {
  return ::is_myself_anyof_moderators() ? this.MAX_ROOM_MSGS_FOR_MODERATOR : this.MAX_ROOM_MSGS
}

::g_chat.isSystemUserName <- function isSystemUserName(name) {
  return endsWith(name, this.SYSTEM_MESSAGES_USER_ENDING)
}

::g_chat.isSystemChatRoom <- function isSystemChatRoom(roomId) {
  return ::g_chat_room_type.SYSTEM.checkRoomId(roomId)
}

::g_chat.getSystemRoomId <- function getSystemRoomId() {
  return ::g_chat_room_type.SYSTEM.getRoomId("")
}

::g_chat.openPrivateRoom <- function openPrivateRoom(name, ownerHandler) {
  if (::openChatScene(ownerHandler))
    ::menu_chat_handler.changePrivateTo.call(::menu_chat_handler, name)
}

::g_chat.joinSquadRoom <- function joinSquadRoom(callback) {
  let name = this.getMySquadRoomId()
  if (u.isEmpty(name))
    return

  let password = ::g_squad_manager.getSquadRoomPassword()
  if (u.isEmpty(password))
    return

  if (::menu_chat_handler)
    ::menu_chat_handler.joinRoom.call(::menu_chat_handler, name, password, callback)
}

::g_chat.leaveSquadRoom <- function leaveSquadRoom() {
  if (::menu_chat_handler)
    ::menu_chat_handler.leaveSquadRoom.call(::menu_chat_handler)
}

::g_chat.isRoomSquad <- function isRoomSquad(roomId) {
  return ::g_chat_room_type.SQUAD.checkRoomId(roomId)
}

::g_chat.isSquadRoomJoined <- function isSquadRoomJoined() {
  let roomId = this.getMySquadRoomId()
  if (roomId == null)
    return false

  return this.isRoomJoined(roomId)
}

::g_chat.getMySquadRoomId <- function getMySquadRoomId() {
  if (!::g_squad_manager.isInSquad())
    return null

  let squadRoomName = ::g_squad_manager.getSquadRoomName()
  if (u.isEmpty(squadRoomName))
    return null

  return ::g_chat_room_type.SQUAD.getRoomId(squadRoomName)
}

::g_chat.isRoomClan <- function isRoomClan(roomId) {
  return ::g_chat_room_type.CLAN.checkRoomId(roomId)
}

::g_chat.getMyClanRoomId <- function getMyClanRoomId() {
  let myClanId = ::clan_get_my_clan_id()
  if (myClanId != "-1")
    return ::g_chat_room_type.CLAN.getRoomId(myClanId)
  return ""
}

::g_chat.getBaseRoomsList <- function getBaseRoomsList() { //base rooms list opened on chat load for all players
  return [::g_chat_room_type.THREADS_LIST.getRoomId("")]
}

::g_chat._lastCleanTime <- -1
::g_chat._checkCleanThreadsList <- function _checkCleanThreadsList() {
  if (this._lastCleanTime + this.THREADS_INFO_CLEAN_PERIOD_MSEC > get_time_msec())
    return
  this._lastCleanTime = get_time_msec()

  //mark joined threads new
  foreach (room in this.rooms)
    if (room.type == ::g_chat_room_type.THREAD) {
      let threadInfo = this.getThreadInfo(room.id)
      if (threadInfo)
        threadInfo.markUpdated()
    }

  //clear outdated threads
  let outdatedArr = []
  foreach (id, thread in this.threadsInfo)
    if (thread.isOutdated())
      outdatedArr.append(id)
  foreach (id in outdatedArr)
    delete this.threadsInfo[id]
}

::g_chat.getThreadInfo <- function getThreadInfo(roomId) {
  return getTblValue(roomId, this.threadsInfo)
}

::g_chat.addThreadInfoById <- function addThreadInfoById(roomId) {
  local res = this.getThreadInfo(roomId)
  if (res)
    return res

  res = ::ChatThreadInfo(roomId)
  this.threadsInfo[roomId] <- res
  return res
}

::g_chat.updateThreadInfo <- function updateThreadInfo(dataBlk) {
  this._checkCleanThreadsList()
  let roomId = dataBlk?.thread
  if (!roomId)
    return

  let curThread = this.getThreadInfo(roomId)
  if (curThread)
    curThread.updateInfo(dataBlk)
  else
    this.threadsInfo[roomId] <- ::ChatThreadInfo(roomId, dataBlk)

  if (dataBlk?.type == "thread_list")
    ::g_chat_latest_threads.onNewThreadInfoToList(this.threadsInfo[roomId])

  ::update_gamercards_chat_info()
  broadcastEvent("ChatThreadInfoChanged", { roomId = roomId })
}

::g_chat.haveProgressCaps <- function haveProgressCaps(name) {
  return (this.userCaps?[name]) == this.userCapsGen;
}

::g_chat.updateProgressCaps <- function updateProgressCaps(dataBlk) {
  this.userCapsGen++;

  if ((dataBlk?.caps ?? "") != "") {
    let capsList = split_by_chars(dataBlk.caps, ",");
    foreach (_idx, prop in capsList) {
      if (prop in this.userCaps)
        this.userCaps[prop] = this.userCapsGen;
    }
  }

  log("ChatProgressCapsChanged: " + this.userCapsGen)
  debugTableData(this.userCaps);
  broadcastEvent("ChatProgressCapsChanged")
}

::g_chat.createThread <- function createThread(title, categoryName, langTags = null) {
  if (!this.checkChatConnected() || !::g_chat.canCreateThreads())
    return

  if (!langTags)
    langTags = ::g_chat_thread_tag.LANG.prefix + getCurLangInfo().chatId
  let categoryTag = ::g_chat_thread_tag.CATEGORY.prefix + categoryName
  let tagsList = ",".join([langTags, categoryTag], true)
  ::gchat_raw_command("xtjoin " + tagsList + " :" + this.prepareThreadTitleToSend(title))
  broadcastEvent("ChatThreadCreateRequested")
}

::g_chat.joinThread <- function joinThread(roomId) {
  if (!this.checkChatConnected())
    return
  if (!::g_chat_room_type.THREAD.checkRoomId(roomId))
    return this.systemMessage(loc(this.CHAT_ERROR_NO_CHANNEL))

  if (!this.isRoomJoined(roomId))
    ::gchat_raw_command("xtjoin " + roomId)
  else if (::menu_chat_handler)
    ::menu_chat_handler.switchCurRoom(roomId)
}

::g_chat.validateRoomName <- function validateRoomName(name) {
  return this.validateRoomNameRegexp.replace("", name)
}

::g_chat.validateChatMessage <- function validateChatMessage(text, multilineAllowed = false) {
  //do not allow players to use tag.  <color=#000000>...
  text = ::stringReplace(text, "<", "[")
  text = ::stringReplace(text, ">", "]")
  if (!multilineAllowed)
    text = ::stringReplace(text, "\\n", " ")
  return text
}

::g_chat.validateThreadTitle <- function validateThreadTitle(title) {
  local res = ::stringReplace(title, "\\n", "\n")
  res = clearBorderSymbolsMultiline(res)
  res = this.validateChatMessage(res, true)
  return res
}

::g_chat.prepareThreadTitleToSend <- function prepareThreadTitleToSend(title) {
  let res = this.validateThreadTitle(title)
  return ::stringReplace(res, "\n", "<br>")
}

::g_chat.restoreReceivedThreadTitle <- function restoreReceivedThreadTitle(title) {
  local res = ::stringReplace(title, "\\n", "\n")
  res = ::stringReplace(res, "<br>", "\n")
  res = clearBorderSymbolsMultiline(res)
  res = this.validateChatMessage(res, true)
  return res
}

::g_chat.checkThreadTitleLen <- function checkThreadTitleLen(title) {
  let checkLenTitle = this.prepareThreadTitleToSend(title)
  let titleLen = utf8(checkLenTitle).charCount()
  return this.threadTitleLenMin <= titleLen && titleLen <= this.threadTitleLenMax
}

::g_chat.openRoomCreationWnd <- function openRoomCreationWnd() {
  let devoiceMsg = penalties.getDevoiceMessage("activeTextColor")
  if (devoiceMsg)
    return showInfoMsgBox(devoiceMsg)

  loadHandler(gui_handlers.CreateRoomWnd)
}

::g_chat.openChatRoom <- function openChatRoom(roomId, ownerHandler = null) {
  if (!::openChatScene(ownerHandler))
    return

  if (::menu_chat_handler)
    ::menu_chat_handler.switchCurRoom.call(::menu_chat_handler, roomId)
}

::g_chat.openModifyThreadWnd <- function openModifyThreadWnd(threadInfo) {
  if (threadInfo.canEdit())
    loadHandler(gui_handlers.modifyThreadWnd, { threadInfo = threadInfo })
}

::g_chat.openModifyThreadWndByRoomId <- function openModifyThreadWndByRoomId(roomId) {
  let threadInfo = this.getThreadInfo(roomId)
  if (threadInfo)
    this.openModifyThreadWnd(threadInfo)
}

::g_chat.modifyThread <- function modifyThread(threadInfo, modifyTable) {
  if ("title" in modifyTable) {
    let title = modifyTable.title
    if (!this.checkThreadTitleLen(title))
      return false

    modifyTable.title = this.validateThreadTitle(title)
  }

  let curTitle = threadInfo.title
  let curTagsString = threadInfo.getFullTagsString()
  let curTimeStamp = threadInfo.timeStamp

  foreach (key, value in modifyTable)
    if (key in threadInfo)
      threadInfo[key] = value

  local isChanged = false
  if (threadInfo.title != curTitle) {
    let title = ::g_chat.prepareThreadTitleToSend(threadInfo.title)
    ::gchat_raw_command("xtmeta " + threadInfo.roomId + " topic :" + title)
    isChanged = true
  }

  let newTagsString = threadInfo.getFullTagsString()
  if (newTagsString != curTagsString) {
    ::gchat_raw_command("xtmeta " + threadInfo.roomId + " tags " + newTagsString)
    isChanged = true
  }

  if (curTimeStamp != threadInfo.timeStamp) {
    ::gchat_raw_command("xtmeta " + threadInfo.roomId + " stamp " + threadInfo.timeStamp)
    isChanged = true
  }

  if (isChanged) {
    broadcastEvent("ChatThreadInfoChanged", { roomId = threadInfo.roomId })
    broadcastEvent("ChatThreadInfoModifiedByPlayer", { threadInfo = threadInfo })
  }

  return true
}

::g_chat.canChooseThreadsLang <- function canChooseThreadsLang() {
  //only moderators can modify chat lang tags atm.
  return hasFeature("ChatThreadLang") && ::is_myself_anyof_moderators()
}

::g_chat.canCreateThreads <- function canCreateThreads() {
  // it can be useful in China to disallow creating threads for ordinary users
  // only moderators allowed to do so
  return ::is_myself_anyof_moderators() || hasFeature("ChatThreadCreate")
}

::g_chat.isImRoomOwner <- function isImRoomOwner(roomData) {
  if (roomData)
    foreach (member in roomData.users)
      if (member.name == userName.value)
        return member.isOwner
  return false
}

::g_chat.generateInviteMenu <- function generateInviteMenu(playerName) {
  let menu = []
  if (userName.value == playerName)
    return menu
  foreach (room in this.rooms) {
    if (!room.type.canInviteToRoom)
      continue

    if (room.type.havePlayersList) {
      local isMyRoom = false
      local isPlayerInRoom = false
      foreach (member in room.users) {
        if (member.isOwner && member.name == userName.value)
          isMyRoom = true
        if (member.name == playerName)
          isPlayerInRoom = true
      }
      if (isPlayerInRoom || (!isMyRoom && room.type.onlyOwnerCanInvite))
        continue
    }

    let roomId = room.id
    menu.append({
      text = room.getRoomName()
      show = true
      action = function () {
          ::gchat_raw_command(format("INVITE %s %s",
            ::gchat_escape_target(playerName),
            ::gchat_escape_target(roomId)))
          }
    })
  }
  return menu
}

::g_chat.showPlayerRClickMenu <- function showPlayerRClickMenu(playerName, roomId = null, contact = null, position = null) {
  playerContextMenu.showMenu(contact, this, {
    position = position
    roomId = roomId
    playerName = playerName
    canComplain = true
  })
}

::g_chat.generatePlayerLink <- function generatePlayerLink(name, uid = null) {
  if (uid)
    return "PLU_" + uid
  return "PL_" + name
}

::g_chat.onEventInitConfigs <- function onEventInitConfigs(_p) {
  let blk = get_game_settings_blk()
  if (!u.isDataBlock(blk?.chat))
    return

  this.threadTitleLenMin = blk.chat?.threadTitleLenMin ?? this.threadTitleLenMin
  this.threadTitleLenMax = blk.chat?.threadTitleLenMax ?? this.threadTitleLenMax
}

::g_chat.getNewMessagesCount <- function getNewMessagesCount() {
  local result = 0

  foreach (room in ::g_chat.rooms)
    if (!room.hidden && !room.concealed())
      result += room.newImportantMessagesCount

  return result
}

::g_chat.haveNewMessages <- function haveNewMessages() {
  return this.getNewMessagesCount() > 0
}

::g_chat.sendLocalizedMessage <- function sendLocalizedMessage(roomId, langConfig, isSeparationAllowed = true, needAssert = true) {
  let message = systemMsg.configToJsonString(langConfig, this.validateChatMessage)
  let messageLen = message.len() //to be visible in assert callstack
  if (messageLen > this.MAX_MSG_LEN) {
    local res = false
    if (isSeparationAllowed && u.isArray(langConfig) && langConfig.len() > 1) {
      needAssert = false
      //do not allow to separate more than on 2 messages because of chat server restrictions.
      let sliceIdx = (langConfig.len() + 1) / 2
      res = this.sendLocalizedMessage(roomId, langConfig.slice(0, sliceIdx), false)
      res = res && this.sendLocalizedMessage(roomId, langConfig.slice(sliceIdx), false)
    }

    if (!res && needAssert) {
      let partsAmount = u.isArray(langConfig) ? langConfig.len() : 1
      script_net_assert_once("too long json message", "Too long json message to chat. partsAmount = " + partsAmount)
    }
    return res
  }

  ::gchat_chat_message(::gchat_escape_target(roomId), this.LOCALIZED_MESSAGE_PREFIX + message)
  return true
}

::g_chat.localizeReceivedMessage <- function localizeReceivedMessage(message) {
  let jsonString = cutPrefix(message, this.LOCALIZED_MESSAGE_PREFIX)
  if (!jsonString)
    return message

  let res = systemMsg.jsonStringToLang(jsonString, null, "\n   ")
  if (!res)
    log("Chat: failed to localize json message: " + message)
  return res || ""
}

::g_chat.sendLocalizedMessageToSquadRoom <- function sendLocalizedMessageToSquadRoom(langConfig) {
  let squadRoomId = this.getMySquadRoomId()
  if (!u.isEmpty(squadRoomId))
    this.sendLocalizedMessage(squadRoomId, langConfig)
}

::g_chat.getSenderColor <- function getSenderColor(senderName, isHighlighted = true, isPrivateChat = false, defaultColor = ::g_chat.color.sender) {
  if (isPrivateChat)
    return this.color.senderPrivate[isHighlighted]
  if (senderName == userName.value)
    return this.color.senderMe[isHighlighted]
  if (::g_squad_manager.isInMySquad(senderName, false))
    return this.color.senderSquad[isHighlighted]
  if (::isPlayerNickInContacts(senderName, EPL_FRIENDLIST))
    return this.color.senderFriend[isHighlighted]
  return u.isTable(defaultColor) ? defaultColor[isHighlighted] : defaultColor
}

registerPersistentDataFromRoot("g_chat")
subscribe_handler(::g_chat, ::g_listener_priority.DEFAULT_HANDLER)
