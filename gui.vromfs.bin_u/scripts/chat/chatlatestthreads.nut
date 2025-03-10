from "%scripts/dagui_natives.nut" import gchat_raw_command
from "%scripts/dagui_library.nut" import *
from "%scripts/chat/chatConsts.nut" import chatUpdateState
from "%scripts/utils_sa.nut" import is_myself_anyof_moderators

let { g_chat_categories } = require("%scripts/chat/chatCategories.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { loadLocalByAccount, saveLocalByAccount } = require("%scripts/clientState/localProfileDeprecated.nut")
let { split_by_chars } = require("string")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_time_msec } = require("dagor.time")
let { get_game_settings_blk } = require("blkGetters")
let { getCurLangInfo, getGameLocalizationInfo } = require("%scripts/langUtils/language.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { g_chat_thread_tag } = require("%scripts/chat/chatThreadInfoTags.nut")
let { checkChatConnected } = require("%scripts/chat/chatHelper.nut")

const REQUEST_TIMEOUT_MSEC = 15000

local autoUpdatePeriodMsec = 60000
local playerUpdateTimeoutMsec = 15000

local lastUpdatetTime = -1
local lastRequestTime = -1
local curListUid = 0 
local threadsList = [] 
local requestedList = [] 

local langsInited = false
local isCustomLangsList = false
local langsList = []


let canChooseThreadsLang = @() hasFeature("ChatThreadLang") && is_myself_anyof_moderators()

function getChatLatestThreadsUpdateState() {
  if (lastRequestTime > lastUpdatetTime && lastRequestTime + REQUEST_TIMEOUT_MSEC > get_time_msec())
    return chatUpdateState.IN_PROGRESS
  if (lastUpdatetTime > 0 && lastUpdatetTime + autoUpdatePeriodMsec > get_time_msec())
    return chatUpdateState.UPDATED
  return chatUpdateState.OUTDATED
}

function forceAutoRefreshInSecond() {
  let state = getChatLatestThreadsUpdateState()
  if (state == chatUpdateState.IN_PROGRESS)
    return

  let diffSec = 1000
  lastUpdatetTime = get_time_msec() - autoUpdatePeriodMsec + diffSec
  
  lastRequestTime = get_time_msec() - REQUEST_TIMEOUT_MSEC + diffSec
}

function onChatThreadsListEnd() {
  threadsList.clear()
  threadsList.extend(requestedList)
  requestedList.clear()
  curListUid++
  lastUpdatetTime = get_time_msec()
  broadcastEvent("ChatLatestThreadsUpdate")
}

function checkInitLangs() {
  if (langsInited)
    return
  langsInited = true

  let canChooseLang =  canChooseThreadsLang()
  if (!canChooseLang) {
    isCustomLangsList = false
    return
  }

  let langsStr = loadLocalByAccount("chat/latestThreadsLangs", "")
  let savedLangs = split_by_chars(langsStr, ",")

  langsList.clear()
  let langsConfig = getGameLocalizationInfo()
  foreach (lang in langsConfig) {
    if (!lang.isMainChatId)
      continue
    if (isInArray(lang.chatId, savedLangs))
      langsList.append(lang)
  }

  isCustomLangsList = langsList.len() > 0
}

function saveCurLangs() {
  if (!langsInited || !isCustomLangsList)
    return
  let chatIds = langsList.map(@(l) l.chatId)
  saveLocalByAccount("chat/latestThreadsLangs", ",".join(chatIds, true))
}

function getSearchLangsList() {
  checkInitLangs()
  return isCustomLangsList ? langsList : [getCurLangInfo()]
}

function setSearchLangs(values) {
  langsList = values
  saveCurLangs()
  isCustomLangsList = langsList.len() > 0
  broadcastEvent("ChatThreadSearchLangChanged")
}

function onNewThreadInfoToList(threadInfo) {
  u.appendOnce(threadInfo, requestedList)
}

function getChatThreadsTimeToRefresh() {
  return max(0, lastUpdatetTime + playerUpdateTimeoutMsec - get_time_msec())
}

function canRefreshChatThreads() {
  return checkChatConnected()
         && getChatLatestThreadsUpdateState() != chatUpdateState.IN_PROGRESS
         && getChatThreadsTimeToRefresh() <= 0
}




function refreshAdvanced(excludeTags = "hidden", includeTags1 = "", includeTags2 = "") {
  if (!canRefreshChatThreads())
    return

  let cmdArr = ["xtlist"]
  if (!excludeTags.len() && (includeTags1.len() || includeTags2.len()))
    excludeTags = ","

  cmdArr.append(excludeTags, includeTags1, includeTags2)

  requestedList.clear()
  lastRequestTime = get_time_msec()
  gchat_raw_command(" ".join(cmdArr, true))
}


function refreshChatThreads() {
  let langTags = getSearchLangsList().map(@(l) g_chat_thread_tag.LANG.prefix + l.chatId)

  local categoryTagsText = ""
  if (!g_chat_categories.isSearchAnyCategory()) {
    local categoryTags = g_chat_categories.getSearchCategoriesLList().map(@(cName) g_chat_thread_tag.CATEGORY.prefix + cName)
    categoryTagsText = ",".join(categoryTags, true)
  }
  refreshAdvanced("hidden", ",".join(langTags, true), categoryTagsText)
}

function checkAutoRefresh() {
  if (getChatLatestThreadsUpdateState() == chatUpdateState.OUTDATED)
    refreshChatThreads()
}

function isChatThreadsListNewest(checkListUid) {
  checkAutoRefresh()
  return checkListUid == curListUid
}

function getChatThreadsList() {
  checkAutoRefresh()
  return threadsList
}

function openChatThreadsChooseLangsMenu(align = "top", alignObj = null) {
  if (!canChooseThreadsLang())
    return

  let optionsList = []
  let curLangs = getSearchLangsList()
  let langsConfig = getGameLocalizationInfo()
  foreach (lang in langsConfig)
    if (lang.isMainChatId)
      optionsList.append({
        text = lang.title
        icon = lang.icon
        value = lang
        selected = isInArray(lang, curLangs)
      })

  loadHandler(gui_handlers.MultiSelectMenu, {
    list = optionsList
    onFinalApplyCb = setSearchLangs
    align = align
    alignObj = alignObj
  })
}

addListenersWithoutEnv({
  function InitConfigs(_p) {
    langsInited = false

    let blk = get_game_settings_blk()
    if (u.isDataBlock(blk?.chat)) {
      autoUpdatePeriodMsec = blk.chat?.threadsListAutoUpdatePeriodMsec ?? autoUpdatePeriodMsec
      playerUpdateTimeoutMsec = blk.chat?.threadsListPlayerUpdateTimeoutMsec ?? playerUpdateTimeoutMsec
    }
  }

  function ChatThreadInfoModifiedByPlayer(p) {
    if (getChatThreadsList().contains(p?.threadInfo))
      forceAutoRefreshInSecond() 
  }

  function GameLocalizationChanged(_p) {
    if (!isCustomLangsList)
      forceAutoRefreshInSecond()
  }

  CrossNetworkChatOptionChanged = @(_p) forceAutoRefreshInSecond()
  ContactsBlockStatusUpdated = @(_p) forceAutoRefreshInSecond()
  ChatThreadCreateRequested = @(_p) forceAutoRefreshInSecond()
  ChatSearchCategoriesChanged = @(_p) refreshChatThreads()
}, g_listener_priority.DEFAULT_HANDLER)

return {
  getChatLatestThreadsUpdateState
  getChatLatestThreadsCurListUid = @() curListUid
  onChatThreadsListEnd
  getSearchLangsList
  onNewThreadInfoToList
  getChatThreadsTimeToRefresh
  canRefreshChatThreads
  refreshChatThreads
  isChatThreadsListNewest
  getChatThreadsList
  openChatThreadsChooseLangsMenu
  canChooseThreadsLang
}
