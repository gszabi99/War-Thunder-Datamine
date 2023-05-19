//checked for plus_string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

//checked for explicitness
#no-root-fallback
#explicit-this

let { split_by_chars } = require("string")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_time_msec } = require("dagor.time")

::g_chat_latest_threads <- {
  autoUpdatePeriodMsec = 60000
  playerUpdateTimeoutMsec = 15000

  requestTimeoutMsec = 15000

  lastUpdatetTime = -1
  lastRequestTime = -1

  curListUid = 0 //for fast compare is threadsList new
  threadsList = [] //first in array is a newest thread

  _requestedList = [] //uncomplete thread list received on refresh

  langsInited = false
  isCustomLangsList = false
  langsList = []
}

//refresh for usual players
::g_chat_latest_threads.refresh <- function refresh() {
  let langTags = u.map(this.getSearchLangsList(),
                           function(l) { return ::g_chat_thread_tag.LANG.prefix + l.chatId })

  local categoryTagsText = ""
  if (!::g_chat_categories.isSearchAnyCategory()) {
    local categoryTags = u.map(::g_chat_categories.getSearchCategoriesLList(),
                                function(cName) { return ::g_chat_thread_tag.CATEGORY.prefix + cName })
    categoryTagsText = ",".join(categoryTags, true)
  }
  this.refreshAdvanced("hidden", ",".join(langTags, true), categoryTagsText)
}

//refresh latest threads. options full work only for moderators.
//!(any of @excludeTags) && (any from includeTags1) && (any from includeTags2)
//for not moderators available only "lang_*" include and forced "hidden" exclude
::g_chat_latest_threads.refreshAdvanced <- function refreshAdvanced(excludeTags = "hidden", includeTags1 = "", includeTags2 = "") {
  if (!this.canRefresh())
    return

  let cmdArr = ["xtlist"]
  if (!excludeTags.len() && (includeTags1.len() || includeTags2.len()))
    excludeTags = ","

  cmdArr.append(excludeTags, includeTags1, includeTags2)

  this._requestedList.clear()
  this.lastRequestTime = get_time_msec()
  ::gchat_raw_command(" ".join(cmdArr, true))
}

::g_chat_latest_threads.onNewThreadInfoToList <- function onNewThreadInfoToList(threadInfo) {
  u.appendOnce(threadInfo, this._requestedList)
}

::g_chat_latest_threads.onThreadsListEnd <- function onThreadsListEnd() {
  this.threadsList.clear()
  this.threadsList.extend(this._requestedList)
  this._requestedList.clear()
  this.curListUid++
  this.lastUpdatetTime = get_time_msec()
  broadcastEvent("ChatLatestThreadsUpdate")
}

::g_chat_latest_threads.checkAutoRefresh <- function checkAutoRefresh() {
  if (this.getUpdateState() == chatUpdateState.OUTDATED)
    this.refresh()
}

::g_chat_latest_threads.getUpdateState <- function getUpdateState() {
  if (this.lastRequestTime > this.lastUpdatetTime && this.lastRequestTime + this.requestTimeoutMsec > get_time_msec())
    return chatUpdateState.IN_PROGRESS
  if (this.lastUpdatetTime > 0 && this.lastUpdatetTime + this.autoUpdatePeriodMsec > get_time_msec())
    return chatUpdateState.UPDATED
  return chatUpdateState.OUTDATED
}

::g_chat_latest_threads.getTimeToRefresh <- function getTimeToRefresh() {
  return max(0, this.lastUpdatetTime + this.playerUpdateTimeoutMsec - get_time_msec())
}

::g_chat_latest_threads.canRefresh <- function canRefresh() {
  return ::g_chat.checkChatConnected()
         && this.getUpdateState() != chatUpdateState.IN_PROGRESS
         && this.getTimeToRefresh() <= 0
}

::g_chat_latest_threads.forceAutoRefreshInSecond <- function forceAutoRefreshInSecond() {
  let state = this.getUpdateState()
  if (state == chatUpdateState.IN_PROGRESS)
    return

  let diffSec = 1000
  this.lastUpdatetTime = get_time_msec() - this.autoUpdatePeriodMsec + diffSec
  //set status chatUpdateState.IN_PROGRESS
  this.lastRequestTime = get_time_msec() - this.requestTimeoutMsec + diffSec
}

::g_chat_latest_threads.checkInitLangs <- function checkInitLangs() {
  if (this.langsInited)
    return
  this.langsInited = true

  let canChooseLang =  ::g_chat.canChooseThreadsLang()
  if (!canChooseLang) {
    this.isCustomLangsList = false
    return
  }

  let langsStr = ::loadLocalByAccount("chat/latestThreadsLangs", "")
  let savedLangs = split_by_chars(langsStr, ",")

  this.langsList.clear()
  let langsConfig = ::g_language.getGameLocalizationInfo()
  foreach (lang in langsConfig) {
    if (!lang.isMainChatId)
      continue
    if (isInArray(lang.chatId, savedLangs))
      this.langsList.append(lang)
  }

  this.isCustomLangsList = this.langsList.len() > 0
}

::g_chat_latest_threads.saveCurLangs <- function saveCurLangs() {
  if (!this.langsInited || !this.isCustomLangsList)
    return
  let chatIds = u.map(this.langsList, function (l) { return l.chatId })
  ::saveLocalByAccount("chat/latestThreadsLangs", ",".join(chatIds, true))
}

::g_chat_latest_threads._setSearchLangs <- function _setSearchLangs(values) {
  this.langsList = values
  this.saveCurLangs()
  this.isCustomLangsList = this.langsList.len() > 0
  broadcastEvent("ChatThreadSearchLangChanged")
}

::g_chat_latest_threads.getSearchLangsList <- function getSearchLangsList() {
  this.checkInitLangs()
  return this.isCustomLangsList ? this.langsList : [::g_language.getCurLangInfo()]
}

::g_chat_latest_threads.openChooseLangsMenu <- function openChooseLangsMenu(align = "top", alignObj = null) {
  if (!::g_chat.canChooseThreadsLang())
    return

  let optionsList = []
  let curLangs = this.getSearchLangsList()
  let langsConfig = ::g_language.getGameLocalizationInfo()
  foreach (lang in langsConfig)
    if (lang.isMainChatId)
      optionsList.append({
        text = lang.title
        icon = lang.icon
        value = lang
        selected = isInArray(lang, curLangs)
      })

  ::gui_start_multi_select_menu({
    list = optionsList
    onFinalApplyCb = function(values) { ::g_chat_latest_threads._setSearchLangs(values) }
    align = align
    alignObj = alignObj
  })
}

::g_chat_latest_threads.isListNewest <- function isListNewest(checkListUid) {
  this.checkAutoRefresh()
  return checkListUid == this.curListUid
}

::g_chat_latest_threads.getList <- function getList() {
  this.checkAutoRefresh()
  return this.threadsList
}

::g_chat_latest_threads.onEventInitConfigs <- function onEventInitConfigs(_p) {
  this.langsInited = false

  let blk = ::get_game_settings_blk()
  if (u.isDataBlock(blk?.chat)) {
    this.autoUpdatePeriodMsec = blk.chat?.threadsListAutoUpdatePeriodMsec ?? this.autoUpdatePeriodMsec
    this.playerUpdateTimeoutMsec = blk.chat?.threadsListPlayerUpdateTimeoutMsec ?? this.playerUpdateTimeoutMsec
  }
}

::g_chat_latest_threads.onEventChatThreadInfoModifiedByPlayer <- function onEventChatThreadInfoModifiedByPlayer(p) {
  if (isInArray(getTblValue("threadInfo", p), this.getList()))
    ::g_chat_latest_threads.forceAutoRefreshInSecond() //wait for all changes applied
}

::g_chat_latest_threads.onEventCrossNetworkChatOptionChanged <- function onEventCrossNetworkChatOptionChanged(_p) {
  this.forceAutoRefreshInSecond()
}

::g_chat_latest_threads.onEventContactsBlockStatusUpdated <- function onEventContactsBlockStatusUpdated(_p) {
  this.forceAutoRefreshInSecond()
}

::g_chat_latest_threads.onEventChatThreadCreateRequested <- function onEventChatThreadCreateRequested(_p) {
  ::g_chat_latest_threads.forceAutoRefreshInSecond()
}

::g_chat_latest_threads.onEventChatSearchCategoriesChanged <- function onEventChatSearchCategoriesChanged(_p) {
  this.refresh()
}

::g_chat_latest_threads.onEventGameLocalizationChanged <- function onEventGameLocalizationChanged(_p) {
  if (!this.isCustomLangsList)
    ::g_chat_latest_threads.forceAutoRefreshInSecond()
}

subscribe_handler(::g_chat_latest_threads, ::g_listener_priority.DEFAULT_HANDLER)
