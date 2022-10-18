let time = require("%scripts/time.nut")


::gui_handlers.modifyThreadWnd <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/chat/modifyThreadWnd.blk"

  threadInfo = null

  curTitle = ""
  curTime = -1
  curLangs = null
  isValuesValid = false

  threadTime = -1

  moveDiffForBorderPlacesSec = 10

  function initScreen()
  {
    if (!threadInfo)
      return

    let ownerText = ::colorize("userlogColoredText", threadInfo.getOwnerText(false))
    let createdByText = ::loc("chat/threadCreatedBy", { player = ownerText })
    scene.findObject("created_by_text").setValue(createdByText)

    scene.findObject("thread_title_header").setValue(::loc("chat/threadTitle/limits",
                                              {
                                                min = ::g_chat.threadTitleLenMin
                                                max = ::g_chat.threadTitleLenMax
                                              }))

    let titleEditbox = scene.findObject("thread_title_editbox")
    titleEditbox.setValue(threadInfo.title)
    ::move_mouse_on_child(titleEditbox)

    let hiddenCheckObj = scene.findObject("is_hidden_checkbox")
    hiddenCheckObj.setValue(threadInfo.isHidden)
    onChangeHidden(hiddenCheckObj)
    let pinnedCheckObj = scene.findObject("is_pinned_checkbox")
    pinnedCheckObj.setValue(threadInfo.isPinned)
    onChangePinned(pinnedCheckObj)

    local timeHeader = ::loc("chat/threadTime")
    if (threadInfo.timeStamp > 0)
    {
      threadTime = threadInfo.timeStamp
      timeHeader += ::loc("ui/colon") + time.buildDateTimeStr(threadInfo.timeStamp)
    }
    scene.findObject("thread_time_header").setValue(timeHeader)

    initLangs()
    initCategories()
  }

  function initLangs()
  {
    curLangs = threadInfo.langs

    let show = ::g_chat.canChooseThreadsLang()
    this.showSceneBtn("language_block", show)
    if (show)
      updateLangButton()
  }

  function updateLangButton()
  {
    let view = { countries = [] }
    foreach(chatId in curLangs)
    {
      let langInfo = ::g_language.getLangInfoByChatId(chatId)
      if (langInfo)
        view.countries.append({ countryIcon = langInfo.icon })
    }
    let data = ::handyman.renderCached("%gui/countriesList", view)
    guiScene.replaceContentFromText(scene.findObject("language_btn"), data, data.len(), this)
  }

  function initCategories()
  {
    let show = ::g_chat_categories.isEnabled()
    this.showSceneBtn("thread_category_header", show)
    let cListObj = this.showSceneBtn("categories_list", show)
    if (show)
      ::g_chat_categories.fillCategoriesListObj(cListObj, threadInfo.category, this)
  }

  function getSelThreadCategoryName()
  {
    let cListObj = scene.findObject("categories_list")
    return ::g_chat_categories.getSelCategoryNameByListObj(cListObj, threadInfo.category)
  }

  function onChangeTitle(obj)
  {
    if (!obj)
      return
    curTitle = obj.getValue() || ""
    checkValues()
  }

  function checkValues()
  {
    isValuesValid = ::g_chat.checkThreadTitleLen(curTitle)

    scene.findObject("btn_apply").enable(isValuesValid)
  }

  function onApply()
  {
    if (!isValuesValid || !::checkObj(scene))
      return

    let modifyTable = {
      title = curTitle
      isHidden = scene.findObject("is_hidden_checkbox").getValue()
      isPinned = scene.findObject("is_pinned_checkbox").getValue()
      category = getSelThreadCategoryName()
    }
    if (curTime > 0)
      modifyTable.timeStamp <- curTime
    if (curLangs)
      modifyTable.langs <- curLangs

    let res = ::g_chat.modifyThread(threadInfo, modifyTable)
    if (res)
      goBack()
  }

  function onChangeHidden(obj)
  {
    if (!obj)
      return
    scene.findObject("is_pinned_checkbox").enable(!obj.getValue())
    scene.findObject("timestamp_editbox").enable(!obj.getValue())
  }

  function onChangePinned(obj)
  {
    if (!obj)
      return
    scene.findObject("is_hidden_checkbox").enable(!obj.getValue())
  }

  function updateSelTimeText(timestamp)
  {
    local text = ""
    if (timestamp >= 0)
      text = " -> " + time.buildDateTimeStr(timestamp)
    scene.findObject("new_time_text").setValue(text)
  }

  function onChangeTimeStamp(obj)
  {
    let timeStr = obj.getValue() || ""
    curTime = timeStr != "" ? time.getTimestampFromStringLocal(timeStr, threadTime) : -1

    updateSelTimeText(curTime)
  }

  function goCancelTimeStamp(obj)
  {
    if (obj.getValue() == "")
      goBack()
    else
      obj.setValue("")
  }

  function setChatTime(timestamp)
  {
    let timeText = time.buildTabularDateTimeStr(timestamp, true)
    let timeObj = scene.findObject("timestamp_editbox")
    timeObj.setValue(timeText)
    ::select_editbox(timeObj)
  }

  function onPinChatMenu()
  {
    let hoursList = [1, 2, 3, 4, 6, 12, 18, 24, 2 * 24, 3 * 24, 5 * 24, 7 * 24, 10 * 24, 14 *24]
    let menu = []
    foreach(hours in hoursList)
      menu.append({
        text = ::loc("chat/pinThreadForTime", { time = time.hoursToString(hours) })
        action = (@(hours) function() {
          let timeInt = ::get_charserver_time_sec() + time.hoursToSeconds(hours)
          setChatTime(timeInt)
        })(hours)
      })
    ::gui_right_click_menu(menu, this)
  }

  function onMoveChatMenu()
  {
    let list = ::g_chat_latest_threads.getList()
    if (!list.len())
      return

    let maxPos = min(list.len(), 14)
    let menu = []
    for(local i = 0; i < maxPos; i++)
      menu.append({
        text = ::loc("chat/moveThreadToPosition", { place = i + 1 })
        action = (@(i) function() { moveChatToPlace(i) })(i)
      })
    ::gui_right_click_menu(menu, this)
  }

  function moveChatToPlace(place)
  {
    let list = ::g_chat_latest_threads.getList()
    if (!list.len())
      return

    place = clamp(place, 0, list.len() - 1)
    let curPlace = ::find_in_array(list, threadInfo)
    if (curPlace >= 0 && curPlace < place)
      place++

    local timeInt = -1
    if (place == curPlace)
      timeInt = threadInfo.timeStamp
    else if (place == 0)
      timeInt = list[0].timeStamp + moveDiffForBorderPlacesSec
    else if (place >= list.len())
      timeInt = list[list.len() - 1].timeStamp - moveDiffForBorderPlacesSec
    else
      timeInt = list[place].timeStamp / 2 + list[place - 1].timeStamp / 2

    if (timeInt > 0)
      setChatTime(timeInt)
  }

  function onLangBtn(obj)
  {
    if (!curLangs)
      return

    let optionsList = []
    let langsConfig = ::g_language.getGameLocalizationInfo()
    foreach(lang in langsConfig)
      if (lang.isMainChatId)
        optionsList.append({
          text = lang.title
          icon = lang.icon
          value = lang.chatId
          selected = ::isInArray(lang.chatId, curLangs)
        })

    ::gui_start_multi_select_menu({
      list = optionsList
      align = "right"
      alignObj = obj
      onFinalApplyCb = ::Callback(function(langs)
                       {
                         if (langs.len())
                           curLangs = langs
                         else
                           curLangs = threadInfo.langs
                         updateLangButton()
                       }, this)
    })
  }
}
