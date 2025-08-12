from "%scripts/dagui_natives.nut" import gchat_raw_command
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import is_myself_anyof_moderators

let { g_chat_room_type } = require("%scripts/chat/chatRoomType.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { split_by_chars } = require("string")
let playerContextMenu = require("%scripts/user/playerContextMenu.nut")
let { isCrossNetworkMessageAllowed } = require("%scripts/chat/chatStates.nut")
let { get_time_msec } = require("dagor.time")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { getLangInfoByChatId, getEmptyLangInfo, getGameLocalizationInfo } = require("%scripts/langUtils/language.nut")
let { g_chat_thread_tag } = require("%scripts/chat/chatThreadInfoTags.nut")
let { getPlayerFullName } = require("%scripts/contacts/contactsInfo.nut")
let { canChooseThreadsLang } = require("%scripts/chat/chatLatestThreads.nut")
let { checkChatConnected } = require("%scripts/chat/chatHelper.nut")
let { getContact } = require("%scripts/contacts/contacts.nut")
let { restoreReceivedThreadTitle, filterMessageText } = require("%scripts/chat/chatUtils.nut")
let { getSenderColor } = require("%scripts/chat/chatColors.nut")
let { isRoomJoined, joinThread } = require("%scripts/chat/chatRooms.nut")

const MAX_THREAD_LANG_VISIBLE = 3
const THREADS_INFO_TIMEOUT_MSEC = 300000
const THREADS_INFO_CLEAN_PERIOD_MSEC = 150000  
const THREAD_INFO_REFRESH_DELAY_MSEC = 60000

let ChatThreadInfo = class {
  roomId = "" 
  lastUpdateTime = -1

  title = ""
  category = ""
  numPosts = 0
  customTags = null
  ownerUid = ""
  ownerNick = ""
  ownerClanTag = ""
  membersAmount = 0
  isHidden = false
  isPinned = false
  timeStamp = -1
  langs = null

  isValid = true

  constructor(threadRoomId, dataBlk = null) { 
    this.roomId = threadRoomId
    this.isValid = this.roomId.len() > 0
    assert(g_chat_room_type.THREAD.checkRoomId(this.roomId), $"Chat thread created with not thread id = {this.roomId}")
    this.langs = []

    this.updateInfo(dataBlk)
  }

  function markUpdated() {
    this.lastUpdateTime = get_time_msec()
  }

  function invalidate() {
    this.isValid = false
  }

  function isOutdated() {
    return this.lastUpdateTime + THREADS_INFO_TIMEOUT_MSEC < get_time_msec()
  }

  function checkRefreshThread() {
    if (!this.isValid
        || !checkChatConnected()
        || this.lastUpdateTime + THREAD_INFO_REFRESH_DELAY_MSEC > get_time_msec()
       )
      return

    gchat_raw_command($"xtmeta {this.roomId}")
  }

  function updateInfo(dataBlk) {
    if (!dataBlk)
      return

    this.title = restoreReceivedThreadTitle(dataBlk.topic) || this.title
    if (this.title == "")
      this.title = this.roomId
    this.numPosts = dataBlk?.numposts ?? this.numPosts

    this.updateInfoTags(u.isString(dataBlk?.tags) ? split_by_chars(dataBlk.tags, ",") : [])
    if (this.ownerNick.len() && this.ownerUid.len())
      getContact(this.ownerUid, this.ownerNick, this.ownerClanTag)

    this.markUpdated()
  }

  function updateInfoTags(tagsList) {
    foreach (tagType in g_chat_thread_tag.types) {
      if (!tagType.isRegular)
        continue

      tagType.updateThreadBeforeTagsUpdate(this)

      local found = false
      for (local i = tagsList.len() - 1; i >= 0; i--)
        if (tagType.updateThreadByTag(this, tagsList[i])) {
          tagsList.remove(i)
          found = true
        }

      if (!found)
        tagType.updateThreadWhenNoTag(this)
    }
    this.customTags = tagsList
    this.sortLangList()
  }

  function getFullTagsString() {
    let resArray = []
    foreach (tagType in g_chat_thread_tag.types) {
      if (!tagType.isRegular)
        continue

      let str = tagType.getTagString(this)
      if (str.len())
        resArray.append(str)
    }
    resArray.extend(this.customTags)
    return ",".join(resArray, true)
  }

  function sortLangList() {
    
    if (this.langs.len() < 2)
      return

    let unsortedLangs = clone this.langs
    this.langs.clear()
    foreach (langInfo in getGameLocalizationInfo()) {
      let idx = unsortedLangs.indexof(langInfo.chatId)
      if (idx != null)
        this.langs.append(unsortedLangs.remove(idx))
    }
    this.langs.extend(unsortedLangs) 
  }

  function isMyThread() {
    return this.ownerUid == "" || this.ownerUid == userIdStr.value
  }

  function getTitle() {
    return filterMessageText(this.title, this.isMyThread())
  }

  function getOwnerText(isColored = true, defaultColor = "") {
    if (!this.ownerNick.len())
      return this.ownerUid

    local res = getPlayerFullName(getPlayerName(this.ownerNick), this.ownerClanTag)
    if (isColored)
      res = colorize(getSenderColor(this.ownerNick, false, false, defaultColor), res)
    return res
  }

  function getRoomTooltipText() {
    return "".concat(
      this.getOwnerText(true, "userlogColoredText"),
      "\n", loc("chat/thread/participants"), loc("ui/colon"),
      colorize("activeTextColor", this.membersAmount), "\n\n", this.getTitle())
  }

  function isJoined() {
    return isRoomJoined(this.roomId)
  }

  function join() {
    joinThread(this.roomId)
  }

  function showOwnerMenu(position = null) {
    let contact = getContact(this.ownerUid, this.ownerNick, this.ownerClanTag)
    playerContextMenu.showChatPlayerRClickMenu(this.ownerNick, this.roomId, contact, position)
  }

  function getJoinText() {
    return this.isJoined() ? loc("chat/showThread") : loc("chat/joinThread")
  }

  function getMembersAmountText() {
    return "".concat(loc("chat/thread/participants"), loc("ui/colon"), this.membersAmount)
  }

  function showThreadMenu(position = null) {
    let thread = this
    let menu = [
      {
        text = this.getJoinText()
        action = function() {
          thread.join()
        }
      }
    ]

    let contact = getContact(this.ownerUid, this.ownerNick, this.ownerClanTag)
    playerContextMenu.showMenu(contact, null, {
      position = position
      roomId = this.roomId
      playerName = this.ownerNick
      extendButtons = menu
    })
  }

  function canEdit() {
    return is_myself_anyof_moderators()
  }

  function setObjValueById(objNest, id, value) {
    let obj = objNest.findObject(id)
    if (checkObj(obj))
      obj.setValue(value)
  }

  function updateInfoObj(obj, updateActionBtn = false) {
    if (!checkObj(obj))
      return

    obj.active = this.isJoined() ? "yes" : "no"

    if (updateActionBtn)
      this.setObjValueById(obj, "action_btn", this.getJoinText())

    this.setObjValueById(obj,$"ownerName_{this.roomId}", this.getOwnerText())
    this.setObjValueById(obj, "thread_title", this.getTitle())
    this.setObjValueById(obj, "thread_members", this.getMembersAmountText())
    if (canChooseThreadsLang())
      this.fillLangIconsRow(obj)
  }

  function needShowLang() {
    return canChooseThreadsLang()
  }

  function getLangsList() {
    let res = []
    local langInfo = {}
    if (this.langs.len() > MAX_THREAD_LANG_VISIBLE) {
      langInfo = getEmptyLangInfo()
      langInfo.icon = ""
      res.append(langInfo)
    }
    else
      foreach (langId in this.langs) {
        langInfo = getLangInfoByChatId(langId)
        if (langInfo)
          res.append(langInfo)
      }
    res.resize(MAX_THREAD_LANG_VISIBLE, getEmptyLangInfo())
    return res
  }

  function fillLangIconsRow(obj) {
    let contentObject = obj.findObject("thread_lang")
    let res = this.getLangsList()
    for (local i = 0; i < MAX_THREAD_LANG_VISIBLE; i++) {
      contentObject.getChild(i)["background-image"] = res[i].icon
    }
  }

  
  isConcealed = function() {
    if (this.isMyThread())
      return false

    if (!isCrossNetworkMessageAllowed(this.ownerNick))
      return true

    let contact = getContact(this.ownerUid, this.ownerNick, this.ownerClanTag)
    if (contact)
      return contact.isBlockedMe() || contact.isInBlockGroup()

    return false
  }
}

return {
  THREADS_INFO_CLEAN_PERIOD_MSEC
  ChatThreadInfo
}
