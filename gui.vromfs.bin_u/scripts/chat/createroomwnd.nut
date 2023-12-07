//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { select_editbox } = require("%scripts/baseGuiHandlerManagerWT.nut")

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

let { format } = require("string")
let regexp2 = require("regexp2")
let { clearBorderSymbols } = require("%sqstd/string.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { is_chat_message_empty } = require("chat")

gui_handlers.CreateRoomWnd <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/chat/createChatroom.blk"

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

  function initScreen() {
    this.tabsList = []
    this.tabBlocksList = []
    foreach (tab in this.fullTabsList) {
      u.appendOnce(tab.tabBlockName, this.tabBlocksList)
      if (tab.roomType.canCreateRoom())
        this.tabsList.append(tab)
    }

    if (!this.tabsList.len())
      return this.goBack()

    if (this.tabsList.len() > 1) {
      this.scene.findObject("caption_text").setValue("")
      this.fillTabs()
    }
    this.switchTab(0)

    let roomNameBoxObj = this.scene.findObject("room_name")
    roomNameBoxObj["max-len"] = ::g_chat.MAX_ALLOWED_CHARACTERS_IN_ROOM_NAME

    this.scene.findObject("thread_title_header").setValue(loc("chat/threadTitle/limits",
      {
        min = ::g_chat.threadTitleLenMin
        max = ::g_chat.threadTitleLenMax
      }))
    this.scene.findObject("chat_room_name_text").setValue(loc("chat/roomName/limits",
      {
        maxSymbols = ::g_chat.MAX_ALLOWED_CHARACTERS_IN_ROOM_NAME
        maxDigits = ::g_chat.MAX_ALLOWED_DIGITS_IN_ROOM_NAME
      }))

    this.initCategories()
  }

  function fillTabs() {
    let view = {
      tabs = []
    }
    foreach (idx, tab in this.tabsList)
      view.tabs.append({
        tabName = loc(tab.locId)
        navImagesText = ::get_navigation_images_text(idx, this.tabsList.len())
      })

    let tabsObj = this.showSceneBtn("tabs_list", true)
    let data = handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
    this.guiScene.replaceContentFromText(tabsObj, data, data.len(), this)
    tabsObj.setValue(0)
  }

  function switchTab(idx) {
    if (idx == this.curTabIdx || !(idx in this.tabsList))
      return

    let curTab = this.tabsList[idx]
    this.curTabIdx = idx
    this.roomType = curTab.roomType

    let curTabBlock = curTab.tabBlockName
    foreach (blockName in this.tabBlocksList)
      this.showSceneBtn(blockName, blockName == curTabBlock)

    this.checkValues()
  }

  function initCategories() {
    let show = ::g_chat_categories.isEnabled()
    this.showSceneBtn("thread_category_header", show)
    let cListObj = this.showSceneBtn("categories_list", show)
    if (show)
      ::g_chat_categories.fillCategoriesListObj(cListObj, ::g_chat_categories.defaultCategoryName, this)
  }

  function getSelThreadCategoryName() {
    let cListObj = this.scene.findObject("categories_list")
    return ::g_chat_categories.getSelCategoryNameByListObj(cListObj, ::g_chat_categories.defaultCategoryName)
  }

  function onTabChange(obj) {
    this.switchTab(obj.getValue())
  }

  function checkValues() {
    if (this.roomType == ::g_chat_room_type.THREAD)
      this.isValuesValid = ::g_chat.checkThreadTitleLen(this.curTitle)
    else {
      this.isValuesValid = !is_chat_message_empty(this.curName)
      let onlyDigits = regexp2(@"\D").replace("", this.curName)
      this.isValuesValid = this.isValuesValid && onlyDigits.len() <= ::g_chat.MAX_ALLOWED_DIGITS_IN_ROOM_NAME
    }

    this.scene.findObject("btn_create_room").enable(this.isValuesValid && this.roomType.isVisible())
  }

  function onChangeRoomName(obj) {
    let value = obj.getValue()
    let validValue = ::g_chat.validateRoomName(value)
    if (value != validValue) {
      obj.setValue(validValue)
      return
    }
    this.curName = validValue
    this.checkValues()
  }

  function onChangeThreadTitle(obj) {
    this.curTitle = obj.getValue()
    this.checkValues()
  }

  onFocusPassword = @() select_editbox(this.scene.findObject("room_password"))

  function onCreateRoom() {
    if (!this.isValuesValid)
      return

    if (this.roomType == ::g_chat_room_type.THREAD)
      ::g_chat.createThread(this.curTitle, this.getSelThreadCategoryName())
    else
      this.createChatRoom()

    this.goBack()
  }

  function createChatRoom() {
    let name = "#" + clearBorderSymbols(this.curName, [" "])
    local pass = this.scene.findObject("room_password").getValue()
    if (pass != "")
      pass = clearBorderSymbols(pass, [" "])
    let invitationsOnly = this.guiScene["room_invitation"].getValue()
    if (::menu_chat_handler) {
      ::menu_chat_handler.joinRoom.call(::menu_chat_handler, name, pass, function () {
        if (invitationsOnly)
          ::gchat_raw_command(format("MODE %s +i", ::gchat_escape_target(name)))
      })
    }
  }
}
