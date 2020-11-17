local { clearBorderSymbols } = require("std/string.nut")

class ::gui_handlers.CreateRoomWnd extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/chat/createChatroom.blk"

  static fullTabsList = [
    {
      roomType = ::g_chat_room_type.THREAD
      tabBlockName = "thread_tab"
      locId = "chat/createThread/header"
    }
    {
      roomType = ::g_chat_room_type.DEFAULT_ROOM
      tabBlockName = "room_tab"
      locId = "chat/createRoom/header"
    }
  ]

  tabsList = null
  tabBlocksList = null
  curTabIdx = -1
  roomType = ::g_chat_room_type.DEFAULT_ROOM

  curName = ""
  curTitle = ""
  isValuesValid = false

  function initScreen()
  {
    tabsList = []
    tabBlocksList = []
    foreach(tab in fullTabsList)
    {
      ::u.appendOnce(tab.tabBlockName, tabBlocksList)
      if (tab.roomType.canCreateRoom())
        tabsList.append(tab)
    }

    if (!tabsList.len())
      return goBack()

    if (tabsList.len() > 1)
    {
      scene.findObject("caption_text").setValue("")
      fillTabs()
    }
    switchTab(0)

    local roomNameBoxObj = scene.findObject("room_name")
    roomNameBoxObj["max-len"] = ::g_chat.MAX_ALLOWED_CHARACTERS_IN_ROOM_NAME

    scene.findObject("thread_title_header").setValue(::loc("chat/threadTitle/limits",
      {
        min = ::g_chat.threadTitleLenMin
        max = ::g_chat.threadTitleLenMax
      }))
    scene.findObject("chat_room_name_text").setValue(::loc("chat/roomName/limits",
      {
        maxSymbols = ::g_chat.MAX_ALLOWED_CHARACTERS_IN_ROOM_NAME
        maxDigits = ::g_chat.MAX_ALLOWED_DIGITS_IN_ROOM_NAME
      }))

    initCategories()
  }

  function fillTabs()
  {
    local view = {
      tabs = []
    }
    foreach(idx, tab in tabsList)
      view.tabs.append({
        tabName = ::loc(tab.locId)
        navImagesText = ::get_navigation_images_text(idx, tabsList.len())
      })

    local tabsObj = showSceneBtn("tabs_list", true)
    local data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    guiScene.replaceContentFromText(tabsObj, data, data.len(), this)
    tabsObj.setValue(0)
  }

  function switchTab(idx)
  {
    if (idx == curTabIdx || !(idx in tabsList))
      return

    local curTab = tabsList[idx]
    curTabIdx = idx
    roomType = curTab.roomType

    local curTabBlock = curTab.tabBlockName
    foreach(blockName in tabBlocksList)
      showSceneBtn(blockName, blockName == curTabBlock)

    checkValues()
  }

  function initCategories()
  {
    local show = ::g_chat_categories.isEnabled()
    showSceneBtn("thread_category_header", show)
    local cListObj = showSceneBtn("categories_list", show)
    if (show)
      ::g_chat_categories.fillCategoriesListObj(cListObj, ::g_chat_categories.defaultCategoryName, this)
  }

  function getSelThreadCategoryName()
  {
    local cListObj = scene.findObject("categories_list")
    return ::g_chat_categories.getSelCategoryNameByListObj(cListObj, ::g_chat_categories.defaultCategoryName)
  }

  function onTabChange(obj)
  {
    switchTab(obj.getValue())
  }

  function checkValues()
  {
    if (roomType == ::g_chat_room_type.THREAD)
      isValuesValid = ::g_chat.checkThreadTitleLen(curTitle)
    else
    {
      isValuesValid = !::is_chat_message_empty(curName)
      local onlyDigits = regexp2(@"\D").replace("", curName)
      isValuesValid = isValuesValid && onlyDigits.len() <= ::g_chat.MAX_ALLOWED_DIGITS_IN_ROOM_NAME
    }

    scene.findObject("btn_create_room").enable(isValuesValid)
  }

  function onChangeRoomName(obj)
  {
    local value = obj.getValue()
    local validValue = ::g_chat.validateRoomName(value)
    if (value != validValue)
    {
      obj.setValue(validValue)
      return
    }
    curName = validValue
    checkValues()
  }

  function onChangeThreadTitle(obj)
  {
    curTitle = obj.getValue()
    checkValues()
  }

  function onCreateRoom()
  {
    if (!isValuesValid)
      return

    if (roomType == ::g_chat_room_type.THREAD)
      ::g_chat.createThread(curTitle, getSelThreadCategoryName())
    else
      createChatRoom()

    goBack()
  }

  function createChatRoom()
  {
    local name = "#" + clearBorderSymbols(curName, [" "])
    local pass = scene.findObject("room_password").getValue()
    if(pass != "")
      pass = clearBorderSymbols(pass, [" "])
    local invitationsOnly = guiScene["room_invitation"].getValue()
    if (::menu_chat_handler)
    {
      ::menu_chat_handler.joinRoom.call(::menu_chat_handler, name, pass, (@(name, invitationsOnly) function () {
        if(invitationsOnly)
          ::gchat_raw_command(::format("MODE %s +i", ::gchat_escape_target(name)))
      })(name, invitationsOnly))
    }
  }
}
