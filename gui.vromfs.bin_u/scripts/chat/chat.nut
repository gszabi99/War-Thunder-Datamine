from "%scripts/dagui_natives.nut" import gchat_chat_message, gchat_is_connected, gchat_raw_command, gchat_escape_target, clan_get_my_clan_id
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import is_myself_anyof_moderators

let { g_chat_room_type } = require("%scripts/chat/chatRoomType.nut")
let { register_command } = require("console")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { get_time_msec } = require("dagor.time")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { rnd } = require("dagor.random")
let { format, split_by_chars } = require("string")
let penalties = require("%scripts/penitentiary/penalties.nut")
let systemMsg = require("%scripts/utils/systemMsg.nut")
let dirtyWordsFilter = require("%scripts/dirtyWordsFilter.nut")
let { clearBorderSymbolsMultiline, endsWith, cutPrefix } = require("%sqstd/string.nut")
let regexp2 = require("regexp2")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { USEROPT_CHAT_FILTER, USEROPT_SHOW_SOCIAL_NOTIFICATIONS, OPTIONS_MODE_GAMEPLAY
} = require("%scripts/options/optionsExtNames.nut")
let { get_game_settings_blk } = require("blkGetters")
let { userName } = require("%scripts/user/profileStates.nut")
let { getCurLangInfo } = require("%scripts/langUtils/language.nut")
let { addPopup } = require("%scripts/popups/popups.nut")
let { update_gamercards_chat_info } = require("%scripts/gamercard.nut")
let {
  canCreateThreads, getThreadInfo, chatRooms, chatThreadsInfo,
  MAX_ROOM_MSGS, MAX_ROOM_MSGS_FOR_MODERATOR, getMaxRoomMsgAmount
} = require("%scripts/chat/chatStorage.nut")
let { chatColors, getSenderColor } = require("%scripts/chat/chatColors.nut")
let { g_chat_thread_tag } = require("%scripts/chat/chatThreadInfoTags.nut")

let userCaps = persist("userCaps", @() {
  ALLOWPOST     = 0
  ALLOWPRIVATE  = 0
  ALLOWJOIN     = 0
  ALLOWXTJOIN   = 0
  ALLOWSPAWN    = 0
  ALLOWXTSPAWN  = 0
  ALLOWINVITE   = 0
})
let validateRoomNameRegexp = regexp2(@"[  !""#$%&'()*+,./\\:;<=>?@\^`{|}~-]")

const THREADS_INFO_TIMEOUT_MSEC = 300000
const THREADS_INFO_CLEAN_PERIOD_MSEC = 150000  //check clean only on get new thread info
const THREAD_INFO_REFRESH_DELAY_MSEC = 60000

const CHAT_SYSTEM_MESSAGE_TIMEOUT_MSEC = 60000
const MAX_MSG_LEN = 200
const MAX_ROOMS_IN_SEARCH = 20
const MAX_LAST_SEND_MESSAGES = 10
const MAX_MSG_VC_SHOW_TIMES = 2

const MAX_ALLOWED_DIGITS_IN_ROOM_NAME = 6
const MAX_ALLOWED_CHARACTERS_IN_ROOM_NAME = 15

const SYSTEM_MESSAGES_USER_ENDING = ".warthunder.com"

const SYSTEM_COLOR = "@chatInfoColor"

const CHAT_ERROR_NO_CHANNEL = "chat/error/403"

const LOCALIZED_MESSAGE_PREFIX = "LMSG "

let storage = persist("storage", @() {
  userCapsGen = 1 // effectively makes caps falsy
  threadTitleLenMin = 8
  threadTitleLenMax = 160
})

local _lastCleanTime = -1
local _roomJoinedIdx = 0

let g_chat = {
  validateRoomNameRegexp
  getThreadTitleLenMin = @() storage.threadTitleLenMin
  getThreadTitleLenMax = @() storage.threadTitleLenMax
  getMaxRoomMsgAmount
  getThreadInfo
  canCreateThreads

  MAX_ROOM_MSGS_FOR_MODERATOR
  MAX_ROOM_MSGS
  MAX_MSG_LEN
  MAX_ROOMS_IN_SEARCH
  MAX_LAST_SEND_MESSAGES
  MAX_MSG_VC_SHOW_TIMES

  MAX_ALLOWED_DIGITS_IN_ROOM_NAME
  MAX_ALLOWED_CHARACTERS_IN_ROOM_NAME

  CHAT_ERROR_NO_CHANNEL

  THREADS_INFO_TIMEOUT_MSEC
  THREAD_INFO_REFRESH_DELAY_MSEC

  rooms = chatRooms //for full room params list check addRoom( function in menuchat.nut //!!FIX ME must be here, or separate class
  threadsInfo = chatThreadsInfo
  userCaps = userCaps
  color = chatColors
  getSenderColor
}


local chat_filter_for_myself = false
register_command(function() {
  chat_filter_for_myself = !chat_filter_for_myself
  console_print($"filter_myself: {chat_filter_for_myself}")
}, "chat.toggle_filter_myself")

g_chat.filterMessageText <- function filterMessageText(text, isMyMessage) {
  if (::get_option(USEROPT_CHAT_FILTER).value &&
    (!isMyMessage || chat_filter_for_myself))
    return dirtyWordsFilter.checkPhrase(text)
  return text
}
::cross_call_api.filter_chat_message <- g_chat.filterMessageText


g_chat.convertBlockedMsgToLink <- function convertBlockedMsgToLink(msg) {
  //space work as close link. but non-breakable space - work as other symbols.
  //rnd for duplicate blocked messages
  return format("BL_%02d_%s", rnd() % 99, msg.replace(" ", nbsp))
}


g_chat.convertLinkToBlockedMsg <- function convertLinkToBlockedMsg(link) {
  let prefixLen = 6 // Prefix is "BL_NN_", where NN are digits.
  return link.slice(prefixLen).replace(nbsp, " ")
}


g_chat.makeBlockedMsg <- function makeBlockedMsg(msg, replacelocId = "chat/blocked_message") {
  local link = this.convertBlockedMsgToLink(msg)
  return format("<Link=%s>%s</Link>", link, loc(replacelocId))
}

g_chat.makeXBoxRestrictedMsg <- function makeXBoxRestrictedMsg(msg) {
  return this.makeBlockedMsg(msg, "chat/blocked_message/xbox_restriction")
}

g_chat.checkBlockedLink <- function checkBlockedLink(link) {
  return !is_platform_xbox && (link.len() > 6 && link.slice(0, 3) == "BL_")
}


g_chat.revealBlockedMsg <- function revealBlockedMsg(text, link) {
  let start = text.indexof($"<Link={link}")
  if (start == null)
    return text

  local end = text.indexof("</Link>", start)
  if (end == null)
    return text

  end += "</Link>".len()

  let msg = this.convertLinkToBlockedMsg(link)
  text = "".concat(text.slice(0, start), msg, text.slice(end))
  return text
}

g_chat.checkChatConnected <- function checkChatConnected() {
  if (gchat_is_connected())
    return true

  this.systemMessage(loc("chat/not_connected"))
  return false
}

g_chat.nextSystemMessageTime <- 0
g_chat.systemMessage <- function systemMessage(msg, needPopup = true, forceMessage = false) {
  if ((!forceMessage) && (this.nextSystemMessageTime > get_time_msec()))
    return

  this.nextSystemMessageTime = get_time_msec() + CHAT_SYSTEM_MESSAGE_TIMEOUT_MSEC

  if (::menu_chat_handler)
    ::menu_chat_handler.addRoomMsg("", "", msg)
  if (needPopup && ::get_gui_option_in_mode(USEROPT_SHOW_SOCIAL_NOTIFICATIONS, OPTIONS_MODE_GAMEPLAY))
    addPopup(null, colorize(SYSTEM_COLOR, msg))
}

g_chat.getRoomById <- function getRoomById(id) {
  return u.search(chatRooms, function (room) { return room.id == id })
}

g_chat.isRoomJoined <- function isRoomJoined(roomId) {
  let room = this.getRoomById(roomId)
  return room != null && room.joined
}

g_chat.addRoom <- function addRoom(room) {
  room.roomJoinedIdx = _roomJoinedIdx++
  chatRooms.append(room)

  chatRooms.sort(function(a, b) {
    if (a.type.tabOrder != b.type.tabOrder)
      return a.type.tabOrder < b.type.tabOrder ? -1 : 1
    if (a.roomJoinedIdx != b.roomJoinedIdx)
      return a.roomJoinedIdx < b.roomJoinedIdx ? -1 : 1
    return 0
  })
}

g_chat.isSystemUserName <- function isSystemUserName(name) {
  return endsWith(name, SYSTEM_MESSAGES_USER_ENDING)
}

g_chat.isSystemChatRoom <- function isSystemChatRoom(roomId) {
  return g_chat_room_type.SYSTEM.checkRoomId(roomId)
}

g_chat.getSystemRoomId <- function getSystemRoomId() {
  return g_chat_room_type.SYSTEM.getRoomId("")
}

g_chat.openPrivateRoom <- function openPrivateRoom(name, ownerHandler) {
  if (::openChatScene(ownerHandler))
    ::menu_chat_handler.changePrivateTo.call(::menu_chat_handler, name)
}

g_chat.joinSquadRoom <- function joinSquadRoom(callback) {
  let name = g_chat_room_type.getMySquadRoomId()
  if (u.isEmpty(name))
    return

  let password = g_squad_manager.getSquadRoomPassword()
  if (u.isEmpty(password))
    return

  if (::menu_chat_handler)
    ::menu_chat_handler.joinRoom.call(::menu_chat_handler, name, password, callback)
}

g_chat.leaveSquadRoom <- function leaveSquadRoom() {
  if (::menu_chat_handler)
    ::menu_chat_handler.leaveSquadRoom.call(::menu_chat_handler)
}

g_chat.isRoomSquad <- function isRoomSquad(roomId) {
  return g_chat_room_type.SQUAD.checkRoomId(roomId)
}

g_chat.isSquadRoomJoined <- function isSquadRoomJoined() {
  let roomId = g_chat_room_type.getMySquadRoomId()
  if (roomId == null)
    return false

  return this.isRoomJoined(roomId)
}

g_chat.isRoomClan <- function isRoomClan(roomId) {
  return g_chat_room_type.CLAN.checkRoomId(roomId)
}

g_chat.getMyClanRoomId <- function getMyClanRoomId() {
  let myClanId = clan_get_my_clan_id()
  if (myClanId != "-1")
    return g_chat_room_type.CLAN.getRoomId(myClanId)
  return ""
}

g_chat.getBaseRoomsList <- function getBaseRoomsList() { //base rooms list opened on chat load for all players
  return [g_chat_room_type.THREADS_LIST.getRoomId("")]
}

g_chat._checkCleanThreadsList <- function _checkCleanThreadsList() {
  if (_lastCleanTime + THREADS_INFO_CLEAN_PERIOD_MSEC > get_time_msec())
    return
  _lastCleanTime = get_time_msec()

  //mark joined threads new
  foreach (room in chatRooms)
    if (room.type == g_chat_room_type.THREAD) {
      let threadInfo = getThreadInfo(room.id)
      if (threadInfo)
        threadInfo.markUpdated()
    }

  //clear outdated threads
  let outdatedArr = []
  foreach (id, thread in chatThreadsInfo)
    if (thread.isOutdated())
      outdatedArr.append(id)
  foreach (id in outdatedArr)
    chatThreadsInfo.$rawdelete(id)
}

g_chat.addThreadInfoById <- function addThreadInfoById(roomId) {
  local res = getThreadInfo(roomId)
  if (res)
    return res

  res = ::ChatThreadInfo(roomId)
  chatThreadsInfo[roomId] <- res
  return res
}

g_chat.updateThreadInfo <- function updateThreadInfo(dataBlk) {
  this._checkCleanThreadsList()
  let roomId = dataBlk?.thread
  if (!roomId)
    return

  let curThread = getThreadInfo(roomId)
  if (curThread)
    curThread.updateInfo(dataBlk)
  else
    chatThreadsInfo[roomId] <- ::ChatThreadInfo(roomId, dataBlk)

  if (dataBlk?.type == "thread_list")
    ::g_chat_latest_threads.onNewThreadInfoToList(chatThreadsInfo[roomId])

  update_gamercards_chat_info()
  broadcastEvent("ChatThreadInfoChanged", { roomId = roomId })
}

g_chat.haveProgressCaps <- function haveProgressCaps(name) {
  return (userCaps?[name]) == storage.userCapsGen
}

g_chat.updateProgressCaps <- function updateProgressCaps(dataBlk) {
  storage.userCapsGen++;

  if ((dataBlk?.caps ?? "") != "") {
    let capsList = split_by_chars(dataBlk.caps, ",");
    foreach (_idx, prop in capsList) {
      if (prop in userCaps)
        userCaps[prop] = storage.userCapsGen;
    }
  }

  log($"ChatProgressCapsChanged: {storage.userCapsGen}")
  debugTableData(userCaps);
  broadcastEvent("ChatProgressCapsChanged")
}

g_chat.createThread <- function createThread(title, categoryName, langTags = null) {
  if (!this.checkChatConnected() || !canCreateThreads())
    return

  if (!langTags)
    langTags = "".concat(g_chat_thread_tag.LANG.prefix, getCurLangInfo().chatId)
  let categoryTag = "".concat(g_chat_thread_tag.CATEGORY.prefix, categoryName)
  let tagsList = ",".join([langTags, categoryTag], true)
  gchat_raw_command($"xtjoin {tagsList} :{this.prepareThreadTitleToSend(title)}")
  broadcastEvent("ChatThreadCreateRequested")
}

g_chat.joinThread <- function joinThread(roomId) {
  if (!this.checkChatConnected())
    return
  if (!g_chat_room_type.THREAD.checkRoomId(roomId))
    return this.systemMessage(loc(this.CHAT_ERROR_NO_CHANNEL))

  if (!this.isRoomJoined(roomId))
    gchat_raw_command($"xtjoin {roomId}")
  else if (::menu_chat_handler)
    ::menu_chat_handler.switchCurRoom(roomId)
}

g_chat.validateRoomName <- function validateRoomName(name) {
  return validateRoomNameRegexp.replace("", name)
}

g_chat.validateChatMessage <- function validateChatMessage(text, multilineAllowed = false) {
  //do not allow players to use tag.  <color=#000000>...
  text = text.replace("<", "[")
  text = text.replace(">", "]")
  if (!multilineAllowed)
    text = text.replace("\\n", " ")
  return text
}

g_chat.validateThreadTitle <- function validateThreadTitle(title) {
  local res = title.replace("\\n", "\n")
  res = clearBorderSymbolsMultiline(res)
  res = this.validateChatMessage(res, true)
  return res
}

g_chat.prepareThreadTitleToSend <- function prepareThreadTitleToSend(title) {
  let res = this.validateThreadTitle(title)
  return res.replace("\n", "<br>")
}

g_chat.restoreReceivedThreadTitle <- function restoreReceivedThreadTitle(title) {
  local res = title.replace("\\n", "\n")
  res = res.replace("<br>", "\n")
  res = clearBorderSymbolsMultiline(res)
  res = this.validateChatMessage(res, true)
  return res
}

g_chat.checkThreadTitleLen <- function checkThreadTitleLen(title) {
  let checkLenTitle = this.prepareThreadTitleToSend(title)
  let titleLen = utf8(checkLenTitle).charCount()
  return storage.threadTitleLenMin <= titleLen && titleLen <= storage.threadTitleLenMax
}

g_chat.openRoomCreationWnd <- function openRoomCreationWnd() {
  let devoiceMsg = penalties.getDevoiceMessage("activeTextColor")
  if (devoiceMsg)
    return showInfoMsgBox(devoiceMsg)

  loadHandler(gui_handlers.CreateRoomWnd)
}

g_chat.openChatRoom <- function openChatRoom(roomId, ownerHandler = null) {
  if (!::openChatScene(ownerHandler))
    return

  if (::menu_chat_handler)
    ::menu_chat_handler.switchCurRoom.call(::menu_chat_handler, roomId)
}

g_chat.openModifyThreadWnd <- function openModifyThreadWnd(threadInfo) {
  if (threadInfo.canEdit())
    loadHandler(gui_handlers.modifyThreadWnd, { threadInfo = threadInfo })
}

g_chat.openModifyThreadWndByRoomId <- function openModifyThreadWndByRoomId(roomId) {
  let threadInfo = getThreadInfo(roomId)
  if (threadInfo)
    this.openModifyThreadWnd(threadInfo)
}

g_chat.modifyThread <- function modifyThread(threadInfo, modifyTable) {
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
    let title = this.prepareThreadTitleToSend(threadInfo.title)
    gchat_raw_command($"xtmeta {threadInfo.roomId} topic :{title}")
    isChanged = true
  }

  let newTagsString = threadInfo.getFullTagsString()
  if (newTagsString != curTagsString) {
    gchat_raw_command($"xtmeta {threadInfo.roomId} tags {newTagsString}")
    isChanged = true
  }

  if (curTimeStamp != threadInfo.timeStamp) {
    gchat_raw_command($"xtmeta {threadInfo.roomId} stamp {threadInfo.timeStamp}")
    isChanged = true
  }

  if (isChanged) {
    broadcastEvent("ChatThreadInfoChanged", { roomId = threadInfo.roomId })
    broadcastEvent("ChatThreadInfoModifiedByPlayer", { threadInfo = threadInfo })
  }

  return true
}

g_chat.canChooseThreadsLang <- function canChooseThreadsLang() {
  //only moderators can modify chat lang tags atm.
  return hasFeature("ChatThreadLang") && is_myself_anyof_moderators()
}

g_chat.isImRoomOwner <- function isImRoomOwner(roomData) {
  if (roomData)
    foreach (member in roomData.users)
      if (member.name == userName.value)
        return member.isOwner
  return false
}

g_chat.generateInviteMenu <- function generateInviteMenu(playerName) {
  let menu = []
  if (userName.value == playerName)
    return menu
  foreach (room in chatRooms) {
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
          gchat_raw_command(format("INVITE %s %s",
            gchat_escape_target(playerName),
            gchat_escape_target(roomId)))
          }
    })
  }
  return menu
}

g_chat.generatePlayerLink <- function generatePlayerLink(name, uid = null) {
  if (uid)
    return $"PLU_{uid}"
  return $"PL_{name}"
}

g_chat.onEventInitConfigs <- function onEventInitConfigs(_p) {
  let blk = get_game_settings_blk()
  if (!u.isDataBlock(blk?.chat))
    return

  storage.threadTitleLenMin = blk.chat?.threadTitleLenMin ?? storage.threadTitleLenMin
  storage.threadTitleLenMax = blk.chat?.threadTitleLenMax ?? storage.threadTitleLenMax
}

g_chat.sendLocalizedMessage <- function sendLocalizedMessage(roomId, langConfig, isSeparationAllowed = true, needAssert = true) {
  let message = systemMsg.configToJsonString(langConfig, this.validateChatMessage)
  let messageLen = message.len() //to be visible in assert callstack
  if (messageLen > MAX_MSG_LEN) {
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
      script_net_assert_once("too long json message", $"Too long json message to chat. partsAmount = {partsAmount}")
    }
    return res
  }

  ::gchat_chat_message(gchat_escape_target(roomId), "".concat(LOCALIZED_MESSAGE_PREFIX, message))
  return true
}

g_chat.localizeReceivedMessage <- function localizeReceivedMessage(message) {
  let jsonString = cutPrefix(message, LOCALIZED_MESSAGE_PREFIX)
  if (!jsonString)
    return message

  let res = systemMsg.jsonStringToLang(jsonString, null, "\n   ")
  if (!res)
    log($"Chat: failed to localize json message: {message}")
  return res || ""
}

g_chat.sendLocalizedMessageToSquadRoom <- function sendLocalizedMessageToSquadRoom(langConfig) {
  let squadRoomId = g_chat_room_type.getMySquadRoomId()
  if (!u.isEmpty(squadRoomId))
    this.sendLocalizedMessage(squadRoomId, langConfig)
}

subscribe_handler(g_chat, g_listener_priority.DEFAULT_HANDLER)
return {g_chat}
