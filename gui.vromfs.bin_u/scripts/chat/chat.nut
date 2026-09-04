import "%sqStdLibs/helpers/u.nut" as u
import "regexp2" as regexp2
from "%sqStdLibs/helpers/subscriptions.nut" import subscribe_handler, broadcastEvent
from "%sqstd/platform.nut" import is_gdk
from "dagor.time" import get_time_msec
from "dagor.random" import rnd
from "string" import format, split_by_chars
from "%sqstd/string.nut" import endsWith, cutPrefix
from "blkGetters" import get_game_settings_blk
from "eventbus" import eventbus_subscribe
from "%scripts/dagui_natives.nut" import gchat_raw_command, clan_get_my_clan_id
from "%scripts/dagui_library.nut" import *

let { g_chat_room_type } = require("%scripts/chat/chatRoomType.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getDevoiceMessage } = require("%scripts/penitentiary/penaltyMessages.nut")
let systemMsg = require("%scripts/utils/systemMsg.nut")
let { getCurLangInfo } = require("%scripts/langUtils/language.nut")
let { updateGamercardsChatInfo } = require("%scripts/gamercard/gamercardHelpers.nut")
let { canCreateThreads, getThreadInfo, chatRooms, chatThreadsInfo, MAX_ROOM_MSGS, MAX_ROOM_MSGS_FOR_MODERATOR, getMaxRoomMsgAmount } = require("%scripts/chat/chatStorage.nut")
let { chatColors, getSenderColor } = require("%scripts/chat/chatColors.nut")
let { g_chat_thread_tag } = require("%scripts/chat/chatThreadInfoTags.nut")
let { checkChatConnected } = require("%scripts/chat/chatHelper.nut")
let { onNewThreadInfoToList } = require("%scripts/chat/chatLatestThreads.nut")
let { validateThreadTitle, prepareThreadTitleToSend } = require("%scripts/chat/chatUtils.nut")
let { THREADS_INFO_CLEAN_PERIOD_MSEC, ChatThreadInfo } = require("%scripts/chat/chatThreadInfo.nut")
let { MAX_MSG_LEN, LOCALIZED_MESSAGE_PREFIX } = require("%scripts/chat/localizedMessages.nut")

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

const MAX_ROOMS_IN_SEARCH = 20
const MAX_LAST_SEND_MESSAGES = 10
const MAX_MSG_VC_SHOW_TIMES = 2

const MAX_ALLOWED_DIGITS_IN_ROOM_NAME = 6
const MAX_ALLOWED_CHARACTERS_IN_ROOM_NAME = 15

const SYSTEM_MESSAGES_USER_ENDING = ".warthunder.com"

const CHAT_ERROR_NO_CHANNEL = "chat/error/403"

let storage = persist("storage", @() {
  userCapsGen = 1 
  threadTitleLenMin = 8
  threadTitleLenMax = 160
})

local _lastCleanTime = -1

let g_chat = {
  validateRoomNameRegexp
  getThreadTitleLenMin = @() storage.threadTitleLenMin
  getThreadTitleLenMax = @() storage.threadTitleLenMax
  getMaxRoomMsgAmount
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
  rooms = chatRooms 
  threadsInfo = chatThreadsInfo
  userCaps = userCaps
  color = chatColors
  getSenderColor
}


g_chat.convertBlockedMsgToLink <- function convertBlockedMsgToLink(msg) {
  
  
  return format("BL_%02d_%s", rnd() % 99, msg.replace(" ", nbsp))
}


g_chat.convertLinkToBlockedMsg <- function convertLinkToBlockedMsg(link) {
  const prefixLen = 6 
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
  return !is_gdk && (link.len() > 6 && link.slice(0, 3) == "BL_")
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

g_chat.isSystemUserName <- function isSystemUserName(name) {
  return endsWith(name, SYSTEM_MESSAGES_USER_ENDING)
}

g_chat.isSystemChatRoom <- function isSystemChatRoom(roomId) {
  return g_chat_room_type.SYSTEM.checkRoomId(roomId)
}

g_chat.getSystemRoomId <- function getSystemRoomId() {
  return g_chat_room_type.SYSTEM.getRoomId("")
}

g_chat.getMyClanRoomId <- function getMyClanRoomId() {
  let myClanId = clan_get_my_clan_id()
  if (myClanId != "-1")
    return g_chat_room_type.CLAN.getRoomId(myClanId)
  return ""
}

g_chat.getBaseRoomsList <- function getBaseRoomsList() { 
  return [g_chat_room_type.THREADS_LIST.getRoomId("")]
}

g_chat._checkCleanThreadsList <- function _checkCleanThreadsList() {
  if (_lastCleanTime + THREADS_INFO_CLEAN_PERIOD_MSEC > get_time_msec())
    return
  _lastCleanTime = get_time_msec()

  
  foreach (room in chatRooms)
    if (room.type == g_chat_room_type.THREAD) {
      let threadInfo = getThreadInfo(room.id)
      if (threadInfo)
        threadInfo.markUpdated()
    }

  
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

  res = ChatThreadInfo(roomId)
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
    chatThreadsInfo[roomId] <- ChatThreadInfo(roomId, dataBlk)

  if (dataBlk?.type == "thread_list")
    onNewThreadInfoToList(chatThreadsInfo[roomId])

  updateGamercardsChatInfo()
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
  if (!checkChatConnected() || !canCreateThreads())
    return

  if (!langTags)
    langTags = "".concat(g_chat_thread_tag.LANG.prefix, getCurLangInfo().chatId)
  let categoryTag = "".concat(g_chat_thread_tag.CATEGORY.prefix, categoryName)
  let tagsList = ",".join([langTags, categoryTag], true)
  gchat_raw_command($"xtjoin {tagsList} :{prepareThreadTitleToSend(title)}")
  broadcastEvent("ChatThreadCreateRequested")
}



g_chat.validateRoomName <- function validateRoomName(name) {
  return validateRoomNameRegexp.replace("", name)
}

g_chat.checkThreadTitleLen <- function checkThreadTitleLen(title) {
  let checkLenTitle = prepareThreadTitleToSend(title)
  let titleLen = utf8(checkLenTitle).charCount()
  return storage.threadTitleLenMin <= titleLen && titleLen <= storage.threadTitleLenMax
}

g_chat.openRoomCreationWnd <- function openRoomCreationWnd() {
  let devoiceMsg = getDevoiceMessage("activeTextColor")
  if (devoiceMsg)
    return showInfoMsgBox(devoiceMsg)

  loadHandler(get_gui_handler("CreateRoomWnd"))
}


g_chat.openModifyThreadWnd <- function openModifyThreadWnd(threadInfo) {
  if (threadInfo.canEdit())
    loadHandler(get_gui_handler("modifyThreadWnd"), { threadInfo = threadInfo })
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

    modifyTable.title = validateThreadTitle(title)
  }

  let curTitle = threadInfo.title
  let curTagsString = threadInfo.getFullTagsString()
  let curTimeStamp = threadInfo.timeStamp

  foreach (key, value in modifyTable)
    if (key in threadInfo)
      threadInfo[key] = value

  local isChanged = false
  if (threadInfo.title != curTitle) {
    let title = prepareThreadTitleToSend(threadInfo.title)
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

g_chat.localizeReceivedMessage <- function localizeReceivedMessage(message) {
  let jsonString = cutPrefix(message, LOCALIZED_MESSAGE_PREFIX)
  if (!jsonString)
    return message

  let res = systemMsg.jsonStringToLang(jsonString, null, "\n   ")
  if (!res)
    log($"Chat: failed to localize json message: {message}")
  return res ?? ""
}

subscribe_handler(g_chat, g_listener_priority.DEFAULT_HANDLER)
eventbus_subscribe("on_sign_out", @(_p) g_chat.rooms.clear())

return {
  g_chat
}
