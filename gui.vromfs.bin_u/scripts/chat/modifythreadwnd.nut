//-file:plus-string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { find_in_array } = require("%sqStdLibs/helpers/u.nut")
let time = require("%scripts/time.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { get_charserver_time_sec } = require("chard")
let { getLangInfoByChatId, getGameLocalizationInfo } = require("%scripts/langUtils/language.nut")


gui_handlers.modifyThreadWnd <- class extends gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/chat/modifyThreadWnd.blk"

  threadInfo = null

  curTitle = ""
  curTime = -1
  curLangs = null
  isValuesValid = false

  threadTime = -1

  moveDiffForBorderPlacesSec = 10

  function initScreen() {
    if (!this.threadInfo)
      return

    let ownerText = colorize("userlogColoredText", this.threadInfo.getOwnerText(false))
    let createdByText = loc("chat/threadCreatedBy", { player = ownerText })
    this.scene.findObject("created_by_text").setValue(createdByText)

    this.scene.findObject("thread_title_header").setValue(loc("chat/threadTitle/limits",
                                              {
                                                min = ::g_chat.threadTitleLenMin
                                                max = ::g_chat.threadTitleLenMax
                                              }))

    let titleEditbox = this.scene.findObject("thread_title_editbox")
    titleEditbox.setValue(this.threadInfo.title)
    ::move_mouse_on_child(titleEditbox)

    let hiddenCheckObj = this.scene.findObject("is_hidden_checkbox")
    hiddenCheckObj.setValue(this.threadInfo.isHidden)
    this.onChangeHidden(hiddenCheckObj)
    let pinnedCheckObj = this.scene.findObject("is_pinned_checkbox")
    pinnedCheckObj.setValue(this.threadInfo.isPinned)
    this.onChangePinned(pinnedCheckObj)

    local timeHeader = loc("chat/threadTime")
    if (this.threadInfo.timeStamp > 0) {
      this.threadTime = this.threadInfo.timeStamp
      timeHeader += loc("ui/colon") + time.buildDateTimeStr(this.threadInfo.timeStamp)
    }
    this.scene.findObject("thread_time_header").setValue(timeHeader)

    this.initLangs()
    this.initCategories()
  }

  function initLangs() {
    this.curLangs = this.threadInfo.langs

    let show = ::g_chat.canChooseThreadsLang()
    this.showSceneBtn("language_block", show)
    if (show)
      this.updateLangButton()
  }

  function updateLangButton() {
    let view = { countries = [] }
    foreach (chatId in this.curLangs) {
      let langInfo = getLangInfoByChatId(chatId)
      if (langInfo)
        view.countries.append({ countryIcon = langInfo.icon })
    }
    let data = handyman.renderCached("%gui/countriesList.tpl", view)
    this.guiScene.replaceContentFromText(this.scene.findObject("language_btn"), data, data.len(), this)
  }

  function initCategories() {
    let show = ::g_chat_categories.isEnabled()
    this.showSceneBtn("thread_category_header", show)
    let cListObj = this.showSceneBtn("categories_list", show)
    if (show)
      ::g_chat_categories.fillCategoriesListObj(cListObj, this.threadInfo.category, this)
  }

  function getSelThreadCategoryName() {
    let cListObj = this.scene.findObject("categories_list")
    return ::g_chat_categories.getSelCategoryNameByListObj(cListObj, this.threadInfo.category)
  }

  function onChangeTitle(obj) {
    if (!obj)
      return
    this.curTitle = obj.getValue() || ""
    this.checkValues()
  }

  function checkValues() {
    this.isValuesValid = ::g_chat.checkThreadTitleLen(this.curTitle)

    this.scene.findObject("btn_apply").enable(this.isValuesValid)
  }

  function onApply() {
    if (!this.isValuesValid || !checkObj(this.scene))
      return

    let modifyTable = {
      title = this.curTitle
      isHidden = this.scene.findObject("is_hidden_checkbox").getValue()
      isPinned = this.scene.findObject("is_pinned_checkbox").getValue()
      category = this.getSelThreadCategoryName()
    }
    if (this.curTime > 0)
      modifyTable.timeStamp <- this.curTime
    if (this.curLangs)
      modifyTable.langs <- this.curLangs

    let res = ::g_chat.modifyThread(this.threadInfo, modifyTable)
    if (res)
      this.goBack()
  }

  function onChangeHidden(obj) {
    if (!obj)
      return
    this.scene.findObject("is_pinned_checkbox").enable(!obj.getValue())
    this.scene.findObject("timestamp_editbox").enable(!obj.getValue())
  }

  function onChangePinned(obj) {
    if (!obj)
      return
    this.scene.findObject("is_hidden_checkbox").enable(!obj.getValue())
  }

  function updateSelTimeText(timestamp) {
    local text = ""
    if (timestamp >= 0)
      text = " -> " + time.buildDateTimeStr(timestamp)
    this.scene.findObject("new_time_text").setValue(text)
  }

  function onChangeTimeStamp(obj) {
    let timeStr = obj.getValue() || ""
    this.curTime = timeStr != "" ? time.getTimestampFromStringLocal(timeStr, this.threadTime) : -1

    this.updateSelTimeText(this.curTime)
  }

  function goCancelTimeStamp(obj) {
    if (obj.getValue() == "")
      this.goBack()
    else
      obj.setValue("")
  }

  function setChatTime(timestamp) {
    let timeText = time.buildTabularDateTimeStr(timestamp, true)
    let timeObj = this.scene.findObject("timestamp_editbox")
    timeObj.setValue(timeText)
    ::select_editbox(timeObj)
  }

  function onPinChatMenu() {
    let hoursList = [1, 2, 3, 4, 6, 12, 18, 24, 2 * 24, 3 * 24, 5 * 24, 7 * 24, 10 * 24, 14 * 24]
    let menu = hoursList.map(@(hours) {
      text = loc("chat/pinThreadForTime", { time = time.hoursToString(hours) })
      action = function() {
        let timeInt = get_charserver_time_sec() + time.hoursToSeconds(hours)
        this.setChatTime(timeInt)
      }
    })
    ::gui_right_click_menu(menu, this)
  }

  function onMoveChatMenu() {
    let list = ::g_chat_latest_threads.getList()
    if (!list.len())
      return

    let maxPos = min(list.len(), 14)
    let menu = []
    for (local i = 0; i < maxPos; i++)
      menu.append({
        text = loc("chat/moveThreadToPosition", { place = i + 1 })
        action = function() { this.moveChatToPlace(i) }
      })
    ::gui_right_click_menu(menu, this)
  }

  function moveChatToPlace(place) {
    let list = ::g_chat_latest_threads.getList()
    if (!list.len())
      return

    place = clamp(place, 0, list.len() - 1)
    let curPlace = find_in_array(list, this.threadInfo)
    if (curPlace >= 0 && curPlace < place)
      place++

    local timeInt = -1
    if (place == curPlace)
      timeInt = this.threadInfo.timeStamp
    else if (place == 0)
      timeInt = list[0].timeStamp + this.moveDiffForBorderPlacesSec
    else if (place >= list.len())
      timeInt = list[list.len() - 1].timeStamp - this.moveDiffForBorderPlacesSec
    else
      timeInt = list[place].timeStamp / 2 + list[place - 1].timeStamp / 2

    if (timeInt > 0)
      this.setChatTime(timeInt)
  }

  function onLangBtn(obj) {
    if (!this.curLangs)
      return

    let optionsList = []
    let langsConfig = getGameLocalizationInfo()
    foreach (lang in langsConfig)
      if (lang.isMainChatId)
        optionsList.append({
          text = lang.title
          icon = lang.icon
          value = lang.chatId
          selected = isInArray(lang.chatId, this.curLangs)
        })

    ::gui_start_multi_select_menu({
      list = optionsList
      align = "right"
      alignObj = obj
      onFinalApplyCb = Callback(function(langs) {
                         if (langs.len())
                           this.curLangs = langs
                         else
                           this.curLangs = this.threadInfo.langs
                         this.updateLangButton()
                       }, this)
    })
  }
}
