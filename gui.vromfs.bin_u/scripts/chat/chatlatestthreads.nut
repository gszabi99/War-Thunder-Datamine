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
g_chat_latest_threads.refresh <- function refresh()
{
  local langTags = ::u.map(getSearchLangsList(),
                           function(l) { return ::g_chat_thread_tag.LANG.prefix + l.chatId })

  local categoryTagsText = ""
  if (!::g_chat_categories.isSearchAnyCategory())
  {
    local categoryTags = ::u.map(::g_chat_categories.getSearchCategoriesLList(),
                                function(cName) { return ::g_chat_thread_tag.CATEGORY.prefix + cName })
    categoryTagsText = ::g_string.implode(categoryTags, ",")
  }
  refreshAdvanced("hidden", ::g_string.implode(langTags, ","), categoryTagsText)
}

//refresh latest threads. options full work only for moderators.
//!(any of @excludeTags) && (any from includeTags1) && (any from includeTags2)
//for not moderators available only "lang_*" include and forced "hidden" exclude
g_chat_latest_threads.refreshAdvanced <- function refreshAdvanced(excludeTags = "hidden", includeTags1 = "", includeTags2 = "")
{
  if (!canRefresh())
    return

  local cmdArr = ["xtlist"]
  if (!excludeTags.len() && (includeTags1.len() || includeTags2.len()) )
    excludeTags = ","

  cmdArr.append(excludeTags, includeTags1, includeTags2)

  _requestedList.clear()
  lastRequestTime = ::dagor.getCurTime()
  ::gchat_raw_command(::g_string.implode(cmdArr, " "))
}

g_chat_latest_threads.onNewThreadInfoToList <- function onNewThreadInfoToList(threadInfo)
{
  ::u.appendOnce(threadInfo, _requestedList)
}

g_chat_latest_threads.onThreadsListEnd <- function onThreadsListEnd()
{
  threadsList.clear()
  threadsList.extend(_requestedList)
  _requestedList.clear()
  curListUid++
  lastUpdatetTime = ::dagor.getCurTime()
  ::broadcastEvent("ChatLatestThreadsUpdate")
}

g_chat_latest_threads.checkAutoRefresh <- function checkAutoRefresh()
{
  if (getUpdateState() == chatUpdateState.OUTDATED)
    refresh()
}

g_chat_latest_threads.getUpdateState <- function getUpdateState()
{
  if (lastRequestTime > lastUpdatetTime && lastRequestTime + requestTimeoutMsec > ::dagor.getCurTime())
    return chatUpdateState.IN_PROGRESS
  if (lastUpdatetTime > 0 && lastUpdatetTime + autoUpdatePeriodMsec > ::dagor.getCurTime())
    return chatUpdateState.UPDATED
  return chatUpdateState.OUTDATED
}

g_chat_latest_threads.getTimeToRefresh <- function getTimeToRefresh()
{
  return ::max(0, lastUpdatetTime + playerUpdateTimeoutMsec - ::dagor.getCurTime())
}

g_chat_latest_threads.canRefresh <- function canRefresh()
{
  return ::g_chat.checkChatConnected()
         && getUpdateState() != chatUpdateState.IN_PROGRESS
         && getTimeToRefresh() <= 0
}

g_chat_latest_threads.forceAutoRefreshInSecond <- function forceAutoRefreshInSecond()
{
  local state = getUpdateState()
  if (state == chatUpdateState.IN_PROGRESS)
    return

  local diffSec = 1000
  lastUpdatetTime = ::dagor.getCurTime() - autoUpdatePeriodMsec + diffSec
  //set status chatUpdateState.IN_PROGRESS
  lastRequestTime = ::dagor.getCurTime() - requestTimeoutMsec + diffSec
}

g_chat_latest_threads.checkInitLangs <- function checkInitLangs()
{
  if (langsInited)
    return
  langsInited = true

  local canChooseLang =  ::g_chat.canChooseThreadsLang()
  if (!canChooseLang)
  {
    isCustomLangsList = false
    return
  }

  local langsStr = ::loadLocalByAccount("chat/latestThreadsLangs", "")
  local savedLangs = ::split(langsStr, ",")

  langsList.clear()
  local langsConfig = ::g_language.getGameLocalizationInfo()
  foreach(lang in langsConfig)
  {
    if (!lang.isMainChatId)
      continue
    if (::isInArray(lang.chatId, savedLangs))
      langsList.append(lang)
  }

  isCustomLangsList = langsList.len() > 0
}

g_chat_latest_threads.saveCurLangs <- function saveCurLangs()
{
  if (!langsInited || !isCustomLangsList)
    return
  local chatIds = ::u.map(langsList, function (l) { return l.chatId })
  ::saveLocalByAccount("chat/latestThreadsLangs", ::g_string.implode(chatIds, ","))
}

g_chat_latest_threads._setSearchLangs <- function _setSearchLangs(values)
{
  langsList = values
  saveCurLangs()
  isCustomLangsList = langsList.len() > 0
  ::broadcastEvent("ChatThreadSearchLangChanged")
}

g_chat_latest_threads.getSearchLangsList <- function getSearchLangsList()
{
  checkInitLangs()
  return isCustomLangsList ? langsList : [::g_language.getCurLangInfo()]
}

g_chat_latest_threads.openChooseLangsMenu <- function openChooseLangsMenu(align = "top", alignObj = null)
{
  if (!::g_chat.canChooseThreadsLang())
    return

  local optionsList = []
  local curLangs = getSearchLangsList()
  local langsConfig = ::g_language.getGameLocalizationInfo()
  foreach(lang in langsConfig)
    if (lang.isMainChatId)
      optionsList.append({
        text = lang.title
        icon = lang.icon
        value = lang
        selected = ::isInArray(lang, curLangs)
      })

  ::gui_start_multi_select_menu({
    list = optionsList
    onFinalApplyCb = function(values) { ::g_chat_latest_threads._setSearchLangs(values) }
    align = align
    alignObj = alignObj
  })
}

g_chat_latest_threads.isListNewest <- function isListNewest(checkListUid)
{
  checkAutoRefresh()
  return checkListUid == curListUid
}

g_chat_latest_threads.getList <- function getList()
{
  checkAutoRefresh()
  return threadsList
}

g_chat_latest_threads.onEventInitConfigs <- function onEventInitConfigs(p)
{
  langsInited = false

  local blk = ::get_game_settings_blk()
  if (::u.isDataBlock(blk?.chat))
  {
    autoUpdatePeriodMsec = blk.chat?.threadsListAutoUpdatePeriodMsec ?? autoUpdatePeriodMsec
    playerUpdateTimeoutMsec = blk.chat?.threadsListPlayerUpdateTimeoutMsec ?? playerUpdateTimeoutMsec
  }
}

g_chat_latest_threads.onEventChatThreadInfoModifiedByPlayer <- function onEventChatThreadInfoModifiedByPlayer(p)
{
  if (::isInArray(::getTblValue("threadInfo", p), getList()))
    ::g_chat_latest_threads.forceAutoRefreshInSecond() //wait for all changes applied
}

g_chat_latest_threads.onEventChatThreadCreateRequested <- function onEventChatThreadCreateRequested(p)
{
  ::g_chat_latest_threads.forceAutoRefreshInSecond()
}

g_chat_latest_threads.onEventChatSearchCategoriesChanged <- function onEventChatSearchCategoriesChanged(p)
{
  refresh()
}

g_chat_latest_threads.onEventGameLocalizationChanged <- function onEventGameLocalizationChanged(p)
{
  if (!isCustomLangsList)
    ::g_chat_latest_threads.forceAutoRefreshInSecond()
}

::subscribe_handler(::g_chat_latest_threads, ::g_listener_priority.DEFAULT_HANDLER)
