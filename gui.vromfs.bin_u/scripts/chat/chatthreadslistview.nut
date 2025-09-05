from "%scripts/dagui_library.nut" import *
from "%scripts/chat/chatConsts.nut" import chatUpdateState

let { g_chat } = require("%scripts/chat/chat.nut")
let { g_chat_categories } = require("%scripts/chat/chatCategories.nut")
let { g_chat_room_type } = require("%scripts/chat/chatRoomType.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getObjValidIndex } = require("%sqDagui/daguiUtil.nut")
let time = require("%scripts/time.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { getChatLatestThreadsUpdateState, getChatLatestThreadsCurListUid, getSearchLangsList,
  getChatThreadsTimeToRefresh, canRefreshChatThreads, refreshChatThreads, isChatThreadsListNewest,
  getChatThreadsList, openChatThreadsChooseLangsMenu, canChooseThreadsLang
} = require("%scripts/chat/chatLatestThreads.nut")
let { getThreadInfo } = require("%scripts/chat/chatStorage.nut")

gui_handlers.ChatThreadsListView <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/chat/chatThreadsList.blk"
  backFunc = null
  updateInactiveList = false

  roomId = ""

  listObj = null
  curListUid = -1

  function initScreen() {
    this.listObj = this.scene.findObject("threads_list")
    this.scene.findObject("threads_list_timer").setUserData(this)

    this.updateAll(true)
    this.updateLangsButton()
    this.updateCategoriesButton()
  }

  function remove() {
    this.scene = null
  }

  function onSceneShow() {
    this.updateAll()
  }

  function updateAll(forceUpdate = false) {
    this.updateList(forceUpdate)
    this.updateRefreshButton()
  }

  function updateList(forceUpdate = false) {
    if (!forceUpdate && isChatThreadsListNewest(this.curListUid))
      return

    if (!checkObj(this.listObj))
      return

    let selThread = this.getThreadByObj()

    this.curListUid = getChatLatestThreadsCurListUid()
    let list = getChatThreadsList()
    let isWaiting = !list.len() && getChatLatestThreadsUpdateState() == chatUpdateState.IN_PROGRESS
    if (isWaiting)
      return

    let view = {
      isGamepadMode = showConsoleButtons.get()
      threads = list
    }

    let data = handyman.renderCached("%gui/chat/chatThreadsListRows.tpl", view)
    this.guiScene.replaceContentFromText(this.listObj, data, data.len(), this)

    if (list.len())
      this.listObj.setValue(u.find_in_array(list, selThread, 0))
  }

  function markListChanged() {
    this.curListUid = -1
  }

  function updateRefreshButton() {
    let btnObj = this.scene.findObject("btn_refresh")
    let isWaiting = getChatLatestThreadsUpdateState() == chatUpdateState.IN_PROGRESS

    btnObj.findObject("btn_refresh_img").show(!isWaiting)
    btnObj.findObject("btn_refresh_wait_anim").show(isWaiting)

    let canRefresh = !isWaiting && canRefreshChatThreads()
    btnObj.enable(canRefresh)

    let timeLeft = getChatThreadsTimeToRefresh()

    btnObj.tooltip = timeLeft > 0
      ? "".concat(loc("mainmenu/btnRefresh"), " (", time.secondsToString(0.001 * timeLeft, true, true), ")")
      : loc("mainmenu/btnRefresh")
    this.guiScene.updateTooltip(btnObj)
  }

  function updateLangsButton() {
    let show = canChooseThreadsLang()
    let langsBtn = showObjById("threads_search_langs_btn", show, this.scene)
    if (!show)
      return

    let langs = getSearchLangsList()
    let view = {
      countries = langs.map(@(l) { countryIcon = l.icon })
    }
    let data = handyman.renderCached("%gui/countriesList.tpl", view)
    this.guiScene.replaceContentFromText(langsBtn, data, data.len(), this)
  }

  function updateCategoriesButton() {
    let show = g_chat_categories.isEnabled()
    showObjById("buttons_separator", !show, this.scene)
    let catBtn = showObjById("btn_categories_filter", show, this.scene)
    if (!show)
      return

    local text = ""
    if (g_chat_categories.isSearchAnyCategory())
      text = loc("chat/allCategories")
    else {
      let textsList = g_chat_categories.getSearchCategoriesLList().map(@(cName) g_chat_categories.getCategoryNameText(cName))
      text = ", ".join(textsList, true)
    }
    catBtn.setValue(text)
  }

  function onEventChatLatestThreadsUpdate(_p) {
    if (this.isSceneActive() || this.updateInactiveList) {
      this.updateAll(this.updateInactiveList)
      this.updateInactiveList = false
    }
  }

  function onEventCrossNetworkChatOptionChanged(_p) {
    this.updateInactiveList = true
  }

  function onEventContactsBlockStatusUpdated(_p) {
    this.updateInactiveList = true
  }

  function onUpdate(_obj, _dt) {
    if (this.isSceneActive())
      this.updateAll()
  }

  function getThreadByObj(obj = null) {
    let rId = obj?.roomId
    if (rId && rId.len())
      return getThreadInfo(rId)

    if (!checkObj(this.listObj))
      return null

    let value = this.listObj.getValue() ?? 0
    if (value >= 0 && value < this.listObj.childrenCount())
      return getThreadInfo(this.listObj.getChild(value).roomId)
    return null
  }

  function onJoinThread(obj) {
    let actionThread = this.getThreadByObj(obj)
    if (actionThread)
      actionThread.join()
  }

  function onUserInfo(obj) {
    let actionThread = this.getThreadByObj(obj)
    if (actionThread)
      actionThread.showOwnerMenu(null)
  }

  function onEditThread(obj) {
    let actionThread = this.getThreadByObj(obj)
    if (actionThread)
      g_chat.openModifyThreadWnd(actionThread)
  }

  function openThreadMenu() {
    let actionThread = this.getThreadByObj()
    if (!actionThread)
      return

    local pos = null
    let nameObj = this.listObj.findObject($"ownerName_{actionThread.roomId}")
    if (checkObj(nameObj)) {
      pos = nameObj.getPosRC()
      pos[0] += nameObj.getSize()[0]
    }
    actionThread.showThreadMenu(pos)
  }

  function onCreateThread() {
    g_chat.openRoomCreationWnd()
  }

  function onRefresh() {
    refreshChatThreads()
    this.updateRefreshButton()
  }

  function onThreadsActivate(obj) {
    if (showConsoleButtons.get())
      this.openThreadMenu() 
    else
      this.onJoinThread(obj) 
  }

  function onThreadSelect() {
    
    if (!checkObj(this.listObj) || !this.listObj.childrenCount())
      return

    
    let val = getObjValidIndex(this.listObj)
    local childObj = this.listObj.getChild(val < 0 ? 0 : val)
    if (!checkObj(childObj))
      childObj = this.listObj.getChild(0)

    let selImg = childObj.findObject("thread_row_sel_img")
    if (checkObj(selImg))
      selImg.scrollToView()
  }

  function onLangsBtn(_obj) {
    openChatThreadsChooseLangsMenu("top", this.scene.findObject("threads_search_langs_btn"))
  }

  function onCategoriesBtn(_obj) {
    g_chat_categories.openChooseCategoriesMenu("top", this.scene.findObject("btn_categories_filter"))
  }

  function updateRoomInList(room) {
    if (room && room.type == g_chat_room_type.THREAD)
      this.updateThreadInList(room.id)
  }

  function updateThreadInList(id) {
    if (!this.isSceneActive())
      return this.markListChanged()

    let threadInfo = getThreadInfo(id)
    if (threadInfo)
      threadInfo.updateInfoObj(this.scene.findObject($"room_{id}"), !showConsoleButtons.get())
  }

  function goBack() {
    if (this.backFunc)
      this.backFunc()
  }

  function onEventChatRoomJoin(p) {
    this.updateRoomInList(getTblValue("room", p))
  }

  function onEventChatRoomLeave(p) {
    this.updateRoomInList(getTblValue("room", p))
  }

  function onEventChatFilterChanged(_p) {
    this.markListChanged()
    if (this.isSceneActive()) {
      
      let cb = Callback(this.updateAll, this)
      this.guiScene.performDelayed(this, function() { cb() })
    }
  }

  function onEventChatThreadSearchLangChanged(_p) {
    this.updateLangsButton()
  }

  function onEventChatSearchCategoriesChanged(_p) {
    this.updateCategoriesButton()
  }
}
