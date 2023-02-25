//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let time = require("%scripts/time.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")


::gui_handlers.ChatThreadsListView <- class extends ::gui_handlers.BaseGuiHandlerWT {
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
    if (!forceUpdate && ::g_chat_latest_threads.isListNewest(this.curListUid))
      return

    if (!checkObj(this.listObj))
      return

    let selThread = this.getThreadByObj()

    this.curListUid = ::g_chat_latest_threads.curListUid
    let list = ::g_chat_latest_threads.getList()
    let isWaiting = !list.len() && ::g_chat_latest_threads.getUpdateState() == chatUpdateState.IN_PROGRESS
    if (isWaiting)
      return

    let view = {
      isGamepadMode = ::show_console_buttons
      threads = list
    }

    let data = ::handyman.renderCached("%gui/chat/chatThreadsListRows.tpl", view)
    this.guiScene.replaceContentFromText(this.listObj, data, data.len(), this)

    if (list.len())
      this.listObj.setValue(::find_in_array(list, selThread, 0))
  }

  function markListChanged() {
    this.curListUid = -1
  }

  function updateRefreshButton() {
    let btnObj = this.scene.findObject("btn_refresh")
    let isWaiting = ::g_chat_latest_threads.getUpdateState() == chatUpdateState.IN_PROGRESS

    btnObj.findObject("btn_refresh_img").show(!isWaiting)
    btnObj.findObject("btn_refresh_wait_anim").show(isWaiting)

    let canRefresh = !isWaiting && ::g_chat_latest_threads.canRefresh()
    btnObj.enable(canRefresh)

    local tooltip = loc("mainmenu/btnRefresh")
    let timeLeft = ::g_chat_latest_threads.getTimeToRefresh()
    if (timeLeft > 0)
      tooltip += " (" + time.secondsToString(0.001 * timeLeft, true, true) + ")"
    btnObj.tooltip = tooltip
    this.guiScene.updateTooltip(btnObj)
  }

  function updateLangsButton() {
    let show = ::g_chat.canChooseThreadsLang()
    let langsBtn = this.showSceneBtn("threads_search_langs_btn", show)
    if (!show)
      return

    let langs = ::g_chat_latest_threads.getSearchLangsList()
    let view = {
      countries = ::u.map(langs, function (l) { return { countryIcon = l.icon } })
    }
    let data = ::handyman.renderCached("%gui/countriesList.tpl", view)
    this.guiScene.replaceContentFromText(langsBtn, data, data.len(), this)
  }

  function updateCategoriesButton() {
    let show = ::g_chat_categories.isEnabled()
    this.showSceneBtn("buttons_separator", !show)
    let catBtn = this.showSceneBtn("btn_categories_filter", show)
    if (!show)
      return

    local text = ""
    if (::g_chat_categories.isSearchAnyCategory())
      text = loc("chat/allCategories")
    else {
      let textsList = ::u.map(::g_chat_categories.getSearchCategoriesLList(),
                                function(cName) { return ::g_chat_categories.getCategoryNameText(cName) })
      text = ::g_string.implode(textsList, ", ")
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
      return ::g_chat.getThreadInfo(rId)

    if (!checkObj(this.listObj))
      return null

    let value = this.listObj.getValue() || 0
    if (value >= 0 && value < this.listObj.childrenCount())
      return ::g_chat.getThreadInfo(this.listObj.getChild(value).roomId)
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
      ::g_chat.openModifyThreadWnd(actionThread)
  }

  function openThreadMenu() {
    let actionThread = this.getThreadByObj()
    if (!actionThread)
      return

    local pos = null
    let nameObj = this.listObj.findObject("ownerName_" + actionThread.roomId)
    if (checkObj(nameObj)) {
      pos = nameObj.getPosRC()
      pos[0] += nameObj.getSize()[0]
    }
    actionThread.showThreadMenu(pos)
  }

  function onCreateThread() {
    ::g_chat.openRoomCreationWnd()
  }

  function onRefresh() {
    ::g_chat_latest_threads.refresh()
    this.updateRefreshButton()
  }

  function onThreadsActivate(obj) {
    if (::show_console_buttons)
      this.openThreadMenu() //gamepad shortcut
    else
      this.onJoinThread(obj) //dblClick
  }

  function onThreadSelect() {
    //delayed callbac
    if (!checkObj(this.listObj) || !this.listObj.childrenCount())
      return

    //sellImg is bigger than item, so for correct view while selecting by gamepad need to scroll to selImg
    let val = ::get_obj_valid_index(this.listObj)
    local childObj = this.listObj.getChild(val < 0 ? 0 : val)
    if (!checkObj(childObj))
      childObj = this.listObj.getChild(0)

    let selImg = childObj.findObject("thread_row_sel_img")
    if (checkObj(selImg))
      selImg.scrollToView()
  }

  function onLangsBtn(_obj) {
    ::g_chat_latest_threads.openChooseLangsMenu("top", this.scene.findObject("threads_search_langs_btn"))
  }

  function onCategoriesBtn(_obj) {
    ::g_chat_categories.openChooseCategoriesMenu("top", this.scene.findObject("btn_categories_filter"))
  }

  function updateRoomInList(room) {
    if (room && room.type == ::g_chat_room_type.THREAD)
      this.updateThreadInList(room.id)
  }

  function updateThreadInList(id) {
    if (!this.isSceneActive())
      return this.markListChanged()

    let threadInfo = ::g_chat.getThreadInfo(id)
    if (threadInfo)
      threadInfo.updateInfoObj(this.scene.findObject("room_" + id), !::show_console_buttons)
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
      //wait to apply all options before update scene.
      let cb = Callback(this.updateAll, this)
      this.guiScene.performDelayed(this, (@(cb) function() { cb() })(cb))
    }
  }

  function onEventChatThreadSearchLangChanged(_p) {
    this.updateLangsButton()
  }

  function onEventChatSearchCategoriesChanged(_p) {
    this.updateCategoriesButton()
  }
}
