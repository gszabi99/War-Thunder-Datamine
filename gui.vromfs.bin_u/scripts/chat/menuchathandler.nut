from "%scripts/dagui_natives.nut" import get_pds_next_time, ps4_is_ugc_enabled, gchat_unescape_target, sync_handler_simulate_signal, gchat_list_rooms, gchat_is_connecting, get_pds_code_limit, update_objects_under_windows_state, gchat_is_connected, ps4_show_ugc_restriction, gchat_chat_private_message, gchat_chat_message, gchat_join_room, gchat_raw_command, gchat_escape_target, send_pds_presence_check_in, get_pds_code_suggestion, gchat_list_names
from "%scripts/dagui_library.nut" import *
from "%scripts/chat/chatConsts.nut" import voiceChatStats
from "%scripts/utils_sa.nut" import save_to_json, is_myself_anyof_moderators
from "%scripts/shop/shopCountriesList.nut" import checkCountry

let { get_game_params_blk } = require("blkGetters")
let { g_chat, isRoomWWOperation } = require("%scripts/chat/chat.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { g_chat_room_type } = require("%scripts/chat/chatRoomType.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { subscribe_handler, broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_child_by_value, move_mouse_on_obj, select_editbox, handlersManager,
  is_in_loading_screen } = require("%scripts/baseGuiHandlerManagerWT.nut")
let DataBlock = require("DataBlock")
let { get_time_msec } = require("dagor.time")
let { deferOnce } = require("dagor.workcycle")
let regexp2 = require("regexp2")
let { parse_json } = require("json")
let { clearBorderSymbols, startsWith, replace, stripTags } = require("%sqstd/string.nut")
let penalties = require("%scripts/penitentiary/penalties.nut")
let { newRoom, newMessage, initChatMessageListOn } = require("%scripts/chat/menuChatRoom.nut")
let { topMenuBorders } = require("%scripts/mainmenu/topMenuStates.nut")
let { isChatEnabled, checkChatEnableWithPlayer, isCrossNetworkMessageAllowed, chatStatesCanUseVoice } = require("%scripts/chat/chatStates.nut")
let { hasMenuGeneralChats, hasMenuChatPrivate, hasMenuChatSquad, hasMenuChatClan, hasMenuChatMPlobby
} = require("%scripts/user/matchingFeature.nut")
let { add_user, remove_user, is_muted } = require("%scripts/chat/xboxVoice.nut")
let { eventbus_send, eventbus_subscribe } = require("eventbus")
let { get_option_voicechat, set_gchat_event_cb,
  is_chat_message_empty, is_chat_message_allowed } = require("chat")
let { set_option, get_option } = require("%scripts/options/optionsExt.nut")
let { get_charserver_time_sec } = require("chard")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { USEROPT_VOICE_CHAT, USEROPT_SHOW_SOCIAL_NOTIFICATIONS, OPTIONS_MODE_GAMEPLAY } = require("%scripts/options/optionsExtNames.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings, loadLocalByScreenSize, saveLocalByScreenSize
} = require("%scripts/clientState/localProfile.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { userName } = require("%scripts/user/profileStates.nut")
let { contactPresence } = require("%scripts/contacts/contactPresence.nut")
let { addPopup } = require("%scripts/popups/popups.nut")
let { getContactByName, clanUserTable } = require("%scripts/contacts/contactsManager.nut")
let openEditBoxDialog = require("%scripts/wndLib/editBoxHandler.nut")
let { getLastGamercardScene } = require("%scripts/gamercard.nut")
let { isProfileReceived, isAuthorized } = require("%appGlobals/login/loginState.nut")
let { showChatPlayerRClickMenu } = require("%scripts/user/playerContextMenu.nut")
let { isPlayerNickInContacts } = require("%scripts/contacts/contactsChecks.nut")
let { find_contact_by_name_and_do } = require("%scripts/contacts/contactsActions.nut")
let { collectMissedContactData, getPlayerFullName } = require("%scripts/contacts/contactsInfo.nut")
let { is_in_my_clan } = require("%scripts/clans/clanState.nut")
let { onChatThreadsListEnd } = require("%scripts/chat/chatLatestThreads.nut")
let { checkChatConnected } = require("%scripts/chat/chatHelper.nut")
let { get_gui_option_in_mode } = require("%scripts/options/options.nut")
let { getContact } = require("%scripts/contacts/contacts.nut")
let { lastChatSceneShow, globalChatRooms, langsList } = require("%scripts/chat/chatConsts.nut")
let { openRightClickMenu } = require("%scripts/wndLib/rightClickMenu.nut")
let { getChatObject, isUserBlockedByPrivateSetting } = require("%scripts/chat/chatUtils.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { wwIsOperationLoaded } = require("worldwar")
let { acceptInviteByLink, addChatRoomInvite } = require("%scripts/invites/invites.nut")
let { ceil } = require("%sqstd/math.nut")
let { menuChatHandler } = require("%scripts/chat/chatHandler.nut")

const CHAT_ROOMS_LIST_SAVE_ID = "chatRooms"
const VOICE_CHAT_SHOW_COUNT_SAVE_ID = "voiceChatShowCount"

let chatUpdateSendBtnTextDelaySec = get_game_params_blk()?.floodFilter.chatMessagesTime ?? 2
const CHAT_SEND_BTN_ADD_DELAY_SEC = 0.3 

enum chatErrorName {
  NO_SUCH_NICK_CHANNEL    = "401"
  NO_SUCH_CHANNEL         = "403"
  CANT_SEND_MESSAGE       = "404"
  ALREADY_ON_CHANNEL      = "443"
  CANNOT_JOIN_CHANNEL_NO_INVITATION = "473"
  CANNOT_JOIN_THE_CHANNEL = "475"
}

let availableCmdList = [
  "help", 
  "edit", 
  "msg", "join", "part", "invite", "mode",
  "kick", 
  
  "shelp", "squad_invite", "sinvite", "squad_remove", "sremove", "squad_ready", "sready",
  "reauth", "xpost", "mpost", "p_check"
]

let voiceChatIcons = {
  [voiceChatStats.online] = "voip_enabled",
  
  [voiceChatStats.talking] = "voip_talking",
  [voiceChatStats.muted] = "voip_banned" 
}

let menu_chat_sizes = {}
let last_send_messages = []
let defaultChatRooms = ["general"]

let sortChatUsers = @(a, b) a.name <=> b.name
let sendEventUpdateChatFeatures = @() broadcastEvent("UpdateChatFeatures")

function getGlobalRoomsListByLang(lang, roomsList = null) {
  let res = []
  let def_lang = isInArray(lang, langsList) ? lang : langsList[0]
  foreach (r in globalChatRooms) {
    local l = def_lang
    if ("langs" in r && r.langs.len()) {
      l = isInArray(lang, r.langs) ? lang : r.langs[0]
      if (getTblValue("hideInOtherLangs", r, false) && !isInArray(lang, r.langs))
        continue
    }
    if (!roomsList || isInArray(r.name, roomsList))
      res.append($"{r.name}_{l}")
  }
  return res
}

function getGlobalRoomsList() {
  let res = getGlobalRoomsListByLang(loc("current_lang"))
  foreach (lang in langsList)
    if (lang != loc("current_lang")) {
      let list = getGlobalRoomsListByLang(lang)
      foreach (ch in list)
        if (!isInArray(ch, res))
          res.append(ch)
    }
  return res
}

let globalChatRoomsList = getGlobalRoomsList()

function menuChatCallback(event, taskId, db) {
  broadcastEvent("ChatCallback", { event, taskId, db })
}

let MenuChatHandler = class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM

  presenceDetectionTimer = 0
  static roomRegexp = regexp2("^#[^\\s]")

  roomHandlerWeak = null
  emptyChatRoom = newRoom("#___empty___")
  delayedChatRoom = newRoom("#___empty___")
  prevScenes = [] 
  roomJoinParamsTable = {} 
  lastShowedInRoomMessageIndex = -1

  wndControlsAllowMask = CtrlsInGui.CTRL_ALLOW_FULL

  isChatWindowMouseOver = false
  curHoverObjId = null
  static editboxObjIdList = [ "menuchat_input", "search_edit" ]

  constructor(gui_scene, params = {}) {
    registerPersistentData("MenuChatHandler", this, ["roomsInited"]) 
    base.constructor(gui_scene, params)
    subscribe_handler(this, g_listener_priority.DEFAULT_HANDLER)
  }

  function isValid() {
    return true
  }

  function getControlsAllowMask() {
    if (!this.isMenuChatActive() || !this.scene.isEnabled())
      return CtrlsInGui.CTRL_ALLOW_FULL
    return this.wndControlsAllowMask
  }

  function updateControlsAllowMask() {
    local mask = CtrlsInGui.CTRL_ALLOW_FULL

    if (lastChatSceneShow.get()) {
      let focusObj = this.guiScene.getSelectedObject()
      let hasFocusedObj = checkObj(focusObj) && this.editboxObjIdList.contains(focusObj?.id)

      if (hasFocusedObj || (showConsoleButtons.value && this.isChatWindowMouseOver))
        if (showConsoleButtons.value)
          mask = CtrlsInGui.CTRL_ALLOW_VEHICLE_FULL & ~CtrlsInGui.CTRL_ALLOW_VEHICLE_XINPUT
        else
          mask = CtrlsInGui.CTRL_ALLOW_VEHICLE_FULL & ~CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD
    }

    this.switchControlsAllowMask(mask)
  }

  function onChatEditboxFocus(_obj) {
    this.guiScene.performDelayed(this, function() {
      if (this.checkScene())
        this.updateControlsAllowMask()
    })
  }

  function onChatWindowMouseOver(obj) {
    if (!showConsoleButtons.value)
      return
    let isMouseOver = this.checkScene() && obj.isMouseOver()
    if (this.isChatWindowMouseOver == isMouseOver)
      return
    this.isChatWindowMouseOver = isMouseOver
    this.updateControlsAllowMask()
  }

  function onChatListHover(obj) {
    if (this.checkScene() && obj.isHovered())
      this.checkListValue(obj)
  }

  function selectEditbox(obj) {
    if (this.checkScene() && checkObj(obj) && obj.isVisible() && obj.isEnabled())
      select_editbox(obj)
  }

  function selectChatInputEditbox() {
    this.selectEditbox(this.scene.findObject("menuchat_input"))
  }

  function initChat(obj, resetList = true) {
    if (obj != null && obj == this.scene)
      return

    set_gchat_event_cb(null, menuChatCallback)

    this.chatSceneShow(false)
    this.scene = obj
    this.sceneChanged = true

    if (resetList)
      this.prevScenes = []
    this.chatSceneShow(true)
    this.reloadChatScene()
  }

  function switchScene(obj, onlyShow = false) {
    if (!checkObj(obj) || (checkObj(this.scene) && this.scene.isEqual(obj))) {
      if (!onlyShow || !lastChatSceneShow.get())
        this.chatSceneShow()
    }
    else {
      this.prevScenes.append({
        scene = this.scene
        show = lastChatSceneShow.get()
        roomHandlerWeak = this.roomHandlerWeak && this.roomHandlerWeak.weakref()
      })
      this.roomHandlerWeak = null
      this.removeFromPrevScenes(obj)
      this.initChat(obj, false)
    }
  }

  function removeFromPrevScenes(obj) {
    for (local i = this.prevScenes.len() - 1; i >= 0; i--) {
      let scn = this.prevScenes[i].scene
      if (!checkObj(scn) || scn.isEqual(obj))
        this.prevScenes.remove(i)
    }
  }

  function checkScene() {
    if (checkObj(this.scene))
      return true
    for (local i = this.prevScenes.len() - 1; i >= 0; i--)
      if (checkObj(this.prevScenes[i].scene)) {
        this.scene = this.prevScenes[i].scene
        this.guiScene = this.scene.getScene()
        let prevRoomHandler = this.prevScenes[i].roomHandlerWeak
        this.roomHandlerWeak = prevRoomHandler && prevRoomHandler.weakref()
        this.sceneChanged = true
        this.chatSceneShow(this.prevScenes[i].show || lastChatSceneShow.get())
        return true
      }
      else
        this.prevScenes.remove(i)
    this.scene = null
    return false
  }

  function checkChatAvailableInRoom(roomId, callback) {
    let room = g_chat.getRoomById(roomId)
    if (room == null || room.hasCustomViewHandler) {
      callback?(false)
      return
    }

    if (room.type == g_chat_room_type.PRIVATE) {
      checkChatEnableWithPlayer(roomId, callback)
      return
    }

    callback?(isChatEnabled())
  }

  function reloadChatScene() {
    if (!this.checkScene())
      return

    if (!this.scene.findObject("menuchat")) {
      this.guiScene = this.scene.getScene()
      this.sceneChanged = true
      this.guiScene.replaceContent(this.scene, "%gui/chat/menuChat.blk", this)
      this.setSavedSizes()
      this.scene.findObject("menu_chat_update").setUserData(this)
      local thisCapture = this
      this.checkAndUpdateSendBtn()

      this.checkChatAvailableInRoom(this?.curRoom.id, function(canChat) {
        thisCapture.showChatInput(canChat)
        thisCapture.scene.findObject("menuchat_input")["max-len"] = g_chat.MAX_MSG_LEN.tostring()
        thisCapture.searchInited = false
        initChatMessageListOn(thisCapture.scene.findObject("menu_chat_messages_container"), thisCapture)
        thisCapture.updateRoomsList()
        thisCapture.updateButtonCreateRoom()
      })
    }
  }

  function fillList(listObj, formatText, listTotal) {
    let total = listObj.childrenCount()
    if (total > listTotal)
      for (local i = total - 1; i >= listTotal; i--)
        this.guiScene.destroyElement(listObj.getChild(i))
    else if (total < listTotal) {
      local data = ""
      for (local i = total; i < listTotal; i++)
        data = "".concat(data, format(formatText, i, i))
      this.guiScene.appendWithBlk(listObj, data, this)
    }
  }

  function switchCurRoom(room, needUpdateWindow = true) {
    if (u.isString(room))
      room = g_chat.getRoomById(room)
    if (!room || room == this.curRoom)
      return

    this.curRoom = room
    this.sceneChanged = true
    if (needUpdateWindow)
      this.updateRoomsList()
  }

  function updateButtonCreateRoom() {
    let btnCreateRoomObj = this.scene.findObject("btn_create_room")
    if (!checkObj(btnCreateRoomObj))
      return
    btnCreateRoomObj.enable(hasMenuGeneralChats.value)
    btnCreateRoomObj.show(hasMenuGeneralChats.value)
  }

  function updateRoomsList() {
    if (!this.checkScene())
      return
    let obj = this.scene.findObject("rooms_list")
    if (!checkObj(obj))
      return

    this.guiScene.setUpdatesEnabled(false, false)
    let roomFormat = "shopFilter { shopFilterText { id:t='room_txt_%d'; text:t='' } Button_close { id:t='close_%d'; on_click:t='onRoomClose';}}\n"
    this.fillList(obj, roomFormat, g_chat.rooms.len())

    local curVal = -1

    foreach (idx, room in g_chat.rooms) {
      this.updateRoomTabByIdx(idx, room, obj)

      if (room == this.curRoom && room.type.isVisible())
        curVal = idx
    }

    if (curVal < 0 && g_chat.rooms.len() > 0) {
      curVal = obj.getValue()
      if (curVal < 0 || curVal >= g_chat.rooms.len())
        curVal = g_chat.rooms.len() - 1
    }

    if (curVal != -1 && curVal != obj.getValue())
      obj.setValue(curVal)

    this.scene.findObject("blocked_chat_msg").show(g_chat.rooms.len() == 0)

    this.guiScene.setUpdatesEnabled(true, true)

    if (!this.onRoomChanged()) {
      this.checkNewMessages()
      this.updateRoomsIcons()
    }
  }

  function showChatInput(needShow) {
    showObjById("chat_input_place", needShow, this.scene)
    showObjById("menuchat_input", needShow, this.scene)
    showObjById("btn_send", needShow, this.scene)
  }

  function onRoomChanged() {
    if (!this.checkScene())
      return false

    let obj = this.scene.findObject("rooms_list")
    let value = obj.getValue()
    let roomData = getTblValue(value, g_chat.rooms)

    if (!roomData) {
      this.updateUsersList()
      this.updateChatText()
      this.updateInputText(roomData)
      this.showChatInput(false)
      return false
    }

    if (roomData == this.curRoom && !this.sceneChanged)
      return false

    this.curRoom = roomData
    this.checkAndUpdateSendBtn()

    showObjById("btn_showPlayersList", !this.alwaysShowPlayersList() && roomData.havePlayersList, this.scene)
    showObjById("btn_showSearchList", true, this.scene)
    showObjById("menu_chat_text_block", !roomData.hasCustomViewHandler, this.scene)

    local thisCapture = this
    this.checkChatAvailableInRoom(roomData.id, function(canChat) {
      thisCapture.showChatInput(canChat)
    })

    this.updateUsersList()
    this.updateChatText()
    this.updateInputText(roomData)
    this.checkNewMessages()
    this.updateRoomsIcons()
    this.updateSquadInfo()

    this.checkSwitchRoomHandler(roomData)
    this.updateHeaderBlock(roomData)

    this.sceneChanged = false
    return true
  }

  function onRoomRClick(_obj) {
    if (this.curRoom.type == g_chat_room_type.PRIVATE)
      showChatPlayerRClickMenu(this.curRoom.id, this.curRoom.id)
  }

  function checkSwitchRoomHandler(roomData) {
    showObjById("menu_chat_custom_handler_block", roomData.hasCustomViewHandler, this.scene)
    if (!roomData.hasCustomViewHandler)
      return

    if (!this.roomHandlerWeak)
      return this.createRoomHandler(roomData)

    if (("roomId" in this.roomHandlerWeak) && this.roomHandlerWeak.roomId != roomData.id) {
      if ("remove" in this.roomHandlerWeak)
        this.roomHandlerWeak.remove()
      this.createRoomHandler(roomData)
      return
    }

    if ("onSceneShow" in this.roomHandlerWeak)
      this.roomHandlerWeak.onSceneShow()
  }

  function createRoomHandler(roomData) {
    let obj = this.scene.findObject("menu_chat_custom_handler_block")
    let roomHandler = roomData.type.loadCustomHandler(obj, roomData.id, Callback(this.goBack, this))
    this.roomHandlerWeak = roomHandler && roomHandler.weakref()
  }

  function updateHeaderBlock(roomData) {
    if (!this.checkScene())
      return

    let hasChatHeader = roomData.type.hasChatHeader
    let obj = showObjById("menu_chat_header_block", hasChatHeader, this.scene)
    let isRoomChanged = obj?.roomId != roomData.id
    if (!isRoomChanged) {
      if (hasChatHeader)
        roomData.type.updateChatHeader(obj, roomData)
      return
    }

    if (!hasChatHeader)
      return 

    roomData.type.fillChatHeader(obj, roomData)
    obj.roomId = roomData.id
  }

  function updateInputText(roomData) {
    this.scene.findObject("menuchat_input").setValue(getTblValue("lastTextInput", roomData, ""))
  }

  function updateRoomTabByIdx(idx, room, listObj = null) {
    if (!this.checkScene())
      return
    if (!listObj)
      listObj = this.scene.findObject("rooms_list")
    if (listObj.childrenCount() <= idx)
      return
    let roomTab = listObj.getChild(idx)
    if (!checkObj(roomTab))
      return
    let roomVisible = room.type.isVisible()

    roomTab.canClose = room.canBeClosed ? "yes" : "no"
    room.concealed(function(is_concealed) {
      if (!roomTab?.isValid())
        return
      roomTab.enable(!room.hidden && !is_concealed && roomVisible)
      roomTab.show(!room.hidden && !is_concealed && roomVisible)
    })
    roomTab.tooltip = room.type.getTooltip(room.id)
    let textObj = roomTab.findObject($"room_txt_{idx}")
    textObj.colorTag = room.type.getRoomColorTag(room.id)
    textObj.setValue(room.getRoomName())
  }

  function updateRoomTabById(roomId) {
    foreach (idx, room in g_chat.rooms)
      if (room.id == roomId)
        this.updateRoomTabByIdx(idx, room)
  }

  function updateAllRoomTabs() {
    if (!this.checkScene())
      return
    let listObj = this.scene.findObject("rooms_list")
    foreach (idx, room in g_chat.rooms)
      this.updateRoomTabByIdx(idx, room, listObj)
  }

  function onEventChatThreadInfoChanged(p) {
    this.updateRoomTabById(getTblValue("roomId", p))
  }

  function onEventChatFilterChanged(_p) {
    this.updateAllRoomTabs()
  }

  function onEventContactsGroupUpdate(_p) {
    this.updateAllRoomTabs()
  }

  function onEventSquadStatusChanged(_p) {
    this.updateAllRoomTabs()
  }

  function onEventCrossNetworkChatOptionChanged(_p) {
    this.updateAllRoomTabs()
  }

  function onEventContactsBlockStatusUpdated(_p) {
    this.updateAllRoomTabs()
  }

  function onEventVoiceChatOptionUpdated(_p) {
    this.updateUsersList()
  }

  function alwaysShowPlayersList() {
    return showConsoleButtons.value
  }

  function getRoomIdxById(id) {
    foreach (idx, item in g_chat.rooms)
      if (item.id == id)
        return idx
    return -1
  }

  function updateRoomsIcons() {
    if (!this.checkScene() || !lastChatSceneShow.get())
      return

    let roomsObj = this.scene.findObject("rooms_list")
    if (!roomsObj)
      return

    local total = roomsObj.childrenCount()
    if (total > g_chat.rooms.len())
      total = g_chat.rooms.len() 
    for (local i = 0; i < total; i++) {
      let childObj = roomsObj.getChild(i)
      let obj = childObj.findObject("new_msgs")
      let haveNew = g_chat.rooms[i].newImportantMessagesCount > 0
      if (checkObj(obj) != haveNew)
        if (haveNew) {
          let data = handyman.renderCached("%gui/cssElems/cornerImg.tpl", {
            id = "new_msgs"
            img = "#ui/gameuiskin#chat_new.svg"
            hasGlow = true
          })
          this.guiScene.appendWithBlk(childObj, data, this)
        }
        else
          this.guiScene.destroyElement(obj)
    }
  }

  function updateUsersList() {
    if (!this.checkScene())
      return

    this.guiScene.setUpdatesEnabled(false, false)
    let listObj = this.scene.findObject("users_list")
    let leftObj = this.scene.findObject("middleLine")
    if (!this.curRoom || !this.curRoom.havePlayersList || (!this.showPlayersList && !this.alwaysShowPlayersList())) {
      leftObj.show(false)
      
    }
    else {
      leftObj.show(true)
      let users = this.curRoom.users
      if (users == null)
        this.guiScene.replaceContentFromText(listObj, "", 0, this)
      else {
        let userFormat = "".concat("text { id:t='user_name_%d'; behaviour:t='button'; ",
          "on_click:t='onUserListClick'; on_r_click:t='onUserListRClick'; ",
          "tooltipObj { id:t='tooltip'; uid:t=''; on_tooltip_open:t='onContactTooltipOpen';",
          " on_tooltip_close:t='onTooltipObjClose'; display:t='hide' }\n ",
          "title:t='$tooltipObj';\n }\n")
        this.fillList(listObj, userFormat, users.len())
        foreach (idx, user in users) {
          let fullName = getPlayerFullName(
            getPlayerName(user.name),
            clanUserTable.get()?[user.name] ?? ""
          )
          listObj.findObject($"user_name_{idx}").setValue(fullName)
        }
      }
    }
    if (this.curRoom)
      foreach (idx, user in this.curRoom.users) {
        if (user.uid == null && (g_squad_manager.isInMySquad(user.name, false) || is_in_my_clan(user.name)))
          user.uid = getContactByName(user.name)?.uid

        let contact = (user.uid != null) ? getContact(user.uid) : null
        this.updateUserPresence(listObj, idx, contact)
      }

    this.updateReadyButton()
    this.guiScene.setUpdatesEnabled(true, true)
  }

  function updateReadyButton() {
    if (!this.checkScene() || !this.showPlayersList || !this.curRoom)
      return

    let readyShow = this.curRoom.id == g_chat_room_type.getMySquadRoomId() && g_squad_manager.canSwitchReadyness()
    let readyObj = this.scene.findObject("btn_ready")
    showObjById("btn_ready", readyShow, this.scene)
    if (readyShow)
      readyObj.setValue(g_squad_manager.isMeReady() ? loc("multiplayer/btnNotReady") : loc("mainmenu/btnReady"))
  }

  function updateSquadInfo() {
    if (!this.checkScene() || !this.curRoom)
      return

    let squadBRTextObj = this.scene.findObject("battle_rating")
    if (!checkObj(squadBRTextObj))
      return

    let br = g_squad_manager.getLeaderBattleRating()
    let isShow = br && g_squad_manager.isInSquad() && this.curRoom.id == g_chat_room_type.getMySquadRoomId()

    if (isShow) {
      let gmText = events.getEventNameText(
                       events.getEvent(g_squad_manager.getLeaderGameModeId())
                     ) ?? ""
      local desc = "".concat(loc("shop/battle_rating"), " ", format("%.1f", br))
      desc = "\n".join([gmText, desc], true)
      squadBRTextObj.setValue(desc)
    }
    squadBRTextObj.show(isShow)
  }

  function onEventSquadDataUpdated(_params) {
    this.updateSquadInfo()
  }

  function updateUserPresence(listObj, idx, contact) {
    let obj = listObj.findObject($"user_name_{idx}")
    if (obj) {
      let inMySquad = contact && g_squad_manager.isInMySquad(contact.name, false)
      let inMyClan = contact && is_in_my_clan(contact.name)
      let img = inMySquad ? contact.presence.getIcon() : ""
      local img2 = ""
      local voiceIcon = ""
      if (inMySquad) {
        let memberData = g_squad_manager.getMemberData(contact.uid)
        if (memberData && checkCountry(memberData.country, $"squad member data ( uid = {contact.uid})", true))
          img2 = getCountryIcon(memberData.country)
      }
      obj.findObject("tooltip").uid = (inMySquad && contact) ? contact.uid : ""
      if (get_option_voicechat()
          && (inMySquad || inMyClan)
          && chatStatesCanUseVoice()
          && contact.voiceStatus in voiceChatIcons)
        voiceIcon = $"#ui/gameuiskin#{voiceChatIcons[contact.voiceStatus]}"

      this.setIcon(obj, "statusImg", "img", img)
      this.setIcon(obj, "statusImg2", "img2", img2)
      this.setIcon(obj, "statusVoiceIcon", "voiceIcon", voiceIcon)
      let imgCount = (inMySquad ? 2 : 0) + (voiceIcon != "" ? 1 : 0)
      obj.imgType = imgCount == 0 ? "none" : "".concat(imgCount, "ico")
    }
  }

  function setIcon(obj, id, blockName, image) {
    if (!checkObj(obj))
      return

    let picObj = obj.findObject(id)
    if (picObj)
      picObj["background-image"] = image
    else {
      let string = "%s { id:t='%s'; background-image:t='%s'}"
      let data = format(string, blockName, id, image)
      this.guiScene.prependWithBlk(obj, data, this)
    }
  }

  function updatePresenceContact(contact) {
    if (!this.checkScene() || !lastChatSceneShow.get())
      return

    if (!this.curRoom)
      return

    foreach (idx, user in this.curRoom.users)
      if (user.name == contact.name) {
        user.uid = contact.uid
        let listObj = this.scene.findObject("users_list")
        this.updateUserPresence(listObj, idx, contact)
        return
      }
  }

  function updateChatText() {
    this.updateCustomChatTexts()
    if (!this.checkScene())
      return

    local roomToDraw = null
    if (this.curRoom) {
      if (this.curRoom.hasCustomViewHandler)
        return
      roomToDraw = this.curRoom
    }
    else if (!gchat_is_connected()) {
      if (gchat_is_connecting() || g_chat.rooms.len() == 0) {
        roomToDraw = newRoom("#___empty___")
        newMessage("", loc("chat/connecting"), false, false, null, false, false, function(new_message) {
          roomToDraw.addMessage(new_message)
        })
      }
      else {
        roomToDraw = this.emptyChatRoom
        newMessage("", loc("chat/disconnected"), false, false, null, false, false, function(new_message) {
          roomToDraw.addMessage(new_message)
        })
      }
    }
    if (roomToDraw)
      this.drawRoomTo(roomToDraw, this.scene.findObject("menu_chat_messages_container"), this.sceneChanged)
  }

  function drawRoomTo(room, messagesContainer, isSceneChanged = false) {
    let lastMessageIndex = (room.mBlocks.len() == 0) ? -1 : room.mBlocks.top().messageIndex
    if (lastMessageIndex == this.lastShowedInRoomMessageIndex && !isSceneChanged)
      return

    this.lastShowedInRoomMessageIndex = lastMessageIndex

    messagesContainer.getScene().setUpdatesEnabled(false, false)

    let totalMblocks = room.mBlocks.len()
    let numChildrens = messagesContainer.childrenCount()
    for (local i = 0; i < numChildrens; i++) {
      let msgObj = messagesContainer.getChild(i)
      let textObj  = msgObj.findObject("chat_message_text")
      if (i < totalMblocks) {
        msgObj.show(true)
        msgObj.messageType = room.mBlocks[i].messageType
        textObj.setValue(room.mBlocks[i].text)
      }
      else {
        msgObj.show(false)
      }
    }
    messagesContainer.getScene().setUpdatesEnabled(true, true)
  }

  function chatSceneShow(show = null) {
    if (!this.checkScene())
      return

    if (show == null)
      show = !this.scene.isVisible()
    if (!show)
      this.loadSizes()
    this.scene.show(show)
    this.scene.enable(show)
    lastChatSceneShow.set(show)
    if (show) {
      this.setSavedSizes()
      this.rejoinDefaultRooms(true)
      this.checkNewMessages()
      this.updateRoomsList()
      this.updateSquadInfo()
      this.guiScene.performDelayed(this, function() {
        if (!this.isValid())
          return
        update_objects_under_windows_state(this.guiScene)
        this.restoreFocus()
      })
    }
    else
      this.guiScene.performDelayed(this, function() {
        if (this.isValid())
          update_objects_under_windows_state(this.guiScene)
      })

    this.onChatWindowMouseOver(this.scene)
  }

  function restoreFocus() {
    if (!this.checkScene())
      return
    let inputObj = this.scene.findObject("menuchat_input")
    if (checkObj(inputObj) && inputObj.isVisible())
      this.selectEditbox(inputObj)
    else
      move_mouse_on_child_by_value(this.scene.findObject("rooms_list"))
  }

  function loadRoomParams(roomName, joinParams) {
    foreach (r in defaultChatRooms) 
      if (roomName == $"#{r}_{loc("current_lang")}") {
        let rList = getGlobalRoomsListByLang(loc("current_lang"), [r])
        
        return { roomName = (rList.len() ? $"#{rList[0]}" : roomName)
                  joinParams = "" }
      }

    let idx = roomName.indexof(" ")
    if (idx)  {
      
      return { roomName = $"#{g_chat.validateRoomName(roomName.slice(0, idx))}"
               joinParams = roomName.slice(idx + 1) }
    }

    return {  roomName = roomName
              joinParams = joinParams  }
  }

  function rejoinDefaultRooms(initRooms = false) {
    if (!gchat_is_connected() || !isProfileReceived.get())
      return
    if (this.roomsInited && !initRooms)
      return

    let baseRoomsList = g_chat.getBaseRoomsList()
    foreach (idx, roomId in baseRoomsList)
      if (!g_chat.getRoomById(roomId))
        this.addRoom(roomId, null, null, idx == 0)

    if (isChatEnabled()) {
      let chatRooms = loadLocalAccountSettings(CHAT_ROOMS_LIST_SAVE_ID)
      local roomIdx = 0
      if (chatRooms != null) {
        let storedRooms = []
        for (roomIdx = 0; chatRooms?[$"room{roomIdx}"]; roomIdx++)
          storedRooms.append(this.loadRoomParams(chatRooms?[$"room{roomIdx}"],
                                             chatRooms?[$"params{roomIdx}"]))

        foreach (it in storedRooms) {
          let roomType = g_chat_room_type.getRoomType(it.roomName)
          if (!roomType.needSave()) 
            continue

          gchat_raw_command(format("join %s%s", it.roomName, (it.joinParams == "" ? "" : $" {it.joinParams}")))
          this.addChatJoinParams(it.roomName, it.joinParams)
        }
      }
    }
    this.roomsInited = true
  }

  function saveJoinedRooms() {
    if (!this.roomsInited)
      return

    local saveIdx = 0
    let chatRoomsBlk = DataBlock()
    foreach (room in g_chat.rooms)
      if (!room.hidden && room.type.needSave()) {
        chatRoomsBlk[$"room{saveIdx}"] = gchat_escape_target(room.id)
        if (room.joinParams != "")
          chatRoomsBlk[$"params{saveIdx}"] = room.joinParams
        saveIdx++
      }
    saveLocalAccountSettings(CHAT_ROOMS_LIST_SAVE_ID, chatRoomsBlk)
  }

  function goBack() {
    this.chatSceneShow(false)
  }

  function loadSizes() {
    if (this.isMenuChatActive()) {
      local obj = this.scene.findObject("menuchat")
      menu_chat_sizes.pos <- obj.getPosRC()
      menu_chat_sizes.size <- obj.getSize()
      obj = this.scene.findObject("middleLine")
      menu_chat_sizes.usersSize <- obj.getSize()
      obj = this.scene.findObject("searchDiv")
      if (obj.isVisible())
        menu_chat_sizes.searchSize <- obj.getSize()

      saveLocalByScreenSize("menu_chat_sizes", save_to_json(menu_chat_sizes))
    }
  }

  function onRoomCreator() {
    g_chat.openRoomCreationWnd()
  }

  function setSavedSizes() {
    if (menu_chat_sizes.len() == 0) {
      let data = loadLocalByScreenSize("menu_chat_sizes")
      if (data) {
        let parsedData = parse_json(data)
        if (!("pos" in parsedData) || !("size" in parsedData) || !("usersSize" in parsedData))
          menu_chat_sizes.clear()
        else {
          menu_chat_sizes.__update(parse_json(data))
          menu_chat_sizes.pos[0] = menu_chat_sizes.pos[0].tointeger()
          menu_chat_sizes.pos[1] = menu_chat_sizes.pos[1].tointeger()
          menu_chat_sizes.size[0] = menu_chat_sizes.size[0].tointeger()
          menu_chat_sizes.size[1] = menu_chat_sizes.size[1].tointeger()
          menu_chat_sizes.usersSize[0] = menu_chat_sizes.usersSize[0].tointeger()
          menu_chat_sizes.usersSize[1] = menu_chat_sizes.usersSize[1].tointeger()
        }
      }
    }

    if (!this.isMenuChatActive() || menu_chat_sizes.len() == 0)
      return

    local obj = this.scene.findObject("menuchat")
    if (!obj)
      return

    let pos = menu_chat_sizes.pos
    let size = menu_chat_sizes.size
    if (!pos || !size)
      return

    let rootSize = [screen_width(), screen_height()]
    for (local i = 0; i <= 1; i++) 
      if (pos[i] < topMenuBorders[i][0] * rootSize[i])
        pos[i] = (topMenuBorders[i][0] * rootSize[i]).tointeger()
      else if (pos[i] + size[i] > topMenuBorders[i][1] * rootSize[i])
          pos[i] = (topMenuBorders[i][1] * rootSize[i] - size[i]).tointeger()

    obj.pos = $"{pos[0]}, {pos[1]}"
    obj.size = $"{size[0]}, {size[1]}"

    if ("usersSize" in menu_chat_sizes) {
      obj = this.scene.findObject("middleLine")
      obj.size = $"{menu_chat_sizes.usersSize[0]}, ph" 
    }

    if ("searchSize" in menu_chat_sizes) {
      obj = this.scene.findObject("searchDiv")
      if (obj.isVisible())
        obj.size = $"{menu_chat_sizes.searchSize[0]}, ph"
    }
  }

  function onPresenceDetectionCheckIn(code) {
    if ((code >= 0) && (code < get_pds_code_limit()))
      send_pds_presence_check_in(code)
  }

  function onPresenceDetectionTick() {
    if (!gchat_is_connected())
      return

    if (!is_myself_anyof_moderators())
      return

    if (this.presenceDetectionTimer <= 0) {
      this.presenceDetectionTimer = get_pds_next_time()
    }

    if (get_charserver_time_sec() > this.presenceDetectionTimer) {
      this.presenceDetectionTimer = 0
      let msg = format(loc("chat/presenceCheck"), get_pds_code_suggestion().tostring())

      this.addRoomMsg("", "", msg, false, false)
    }
  }

  
  function onUpdate(timerObj, _dt) {
    let customChatSceneData = this.getSceneDataByActionObj(timerObj)
    let customChatScene = customChatSceneData?.scene
    if (!lastChatSceneShow.get() && !(customChatScene?.isValid() ?? false))
      return

    this.checkAndUpdateSendBtn(customChatSceneData)

    this.loadSizes()
    this.onPresenceDetectionTick()
  }

  function onEventChatCallback(params) {
    let { event, taskId, db } = params
    this.onEventCb(event, taskId, db)
  }

  function onEventCb(event, taskId, db) {
  
    let ctasks = this.chatTasks
    let l = ctasks.len()
    for (local idx=l-1; idx>=0; --idx) {
      let t = ctasks[idx]
      if (t.task == taskId) {
        t.handler.call(this, event, db, t)
        ctasks.remove(idx)
      }
    }
    if (event == GCHAT_EVENT_MESSAGE) {
      if (isChatEnabled())
        this.onMessage(db)
    }
    else if (event == GCHAT_EVENT_CONNECTED) {
      if (this.roomsInited) {
        local thisCapture = this
        newMessage("", loc("chat/connected"), false, false, null, false, false, function(new_message) {
          thisCapture.showRoomPopup(new_message, g_chat.getSystemRoomId())
        })
      }
      this.rejoinDefaultRooms()
      if (g_chat.rooms.len() > 0) {
        let msg = loc("chat/connected")
        this.addRoomMsg("", "", msg)
      }

      foreach (room in g_chat.rooms) {
        if (room.id.slice(0, 1) != "#" || g_chat.isSystemChatRoom(room.id))
          continue

        let roomId = room.id
        let cb = (!checkObj(room.customScene)) ? null : function() { this.afterReconnectCustomRoom(roomId) }
        this.joinRoom(room.id, "", cb, null, null, true)
      }
      this.updateRoomsList()
      broadcastEvent("ChatConnected")
    }
    else if (event == GCHAT_EVENT_DISCONNECTED)
      this.addRoomMsg("", "", loc("chat/disconnected"))
    else if (event == GCHAT_EVENT_CONNECTION_FAILURE)
      this.addRoomMsg("", "", loc("chat/connectionFail"))
    else if (event == GCHAT_EVENT_TASK_RESPONSE)
      this.onEventTaskResponse(taskId, db)
    else if (event == GCHAT_EVENT_VOICE) {
      if (db.uid) {
        let contact = getContact(db.uid)
        local voiceChatStatus = null
        if (db.type == "join") {
          add_user(db.uid)
          voiceChatStatus = is_muted(db.uid) ?
                              voiceChatStats.muted :
                              voiceChatStats.online
        }
        if (db.type == "part") {
          voiceChatStatus = voiceChatStats.offline
          remove_user(db.uid)
        }
        if (db.type == "update") {
          if (is_muted(db.uid))
            voiceChatStatus = voiceChatStats.muted
          else if (db.is_speaking)
            voiceChatStatus = voiceChatStats.talking
          else
            voiceChatStatus = voiceChatStats.online
        }

        if (!contact)
          collectMissedContactData(db.uid, "voiceStatus", voiceChatStatus)
        else {
          contact.voiceStatus = voiceChatStatus
          if (this.checkScene())
            this.updatePresenceContact(contact)
        }

        broadcastEvent("VoiceChatStatusUpdated", {
                                                    uid = db.uid,
                                                    voiceChatStatus = voiceChatStatus
                                                   })

        eventbus_send("updateVoiceChatStatus", {
          name = contact?.getName() ?? "",
          isTalking = voiceChatStatus == voiceChatStats.talking
        })
      }
    }
    
























 
  }

  function createRoomUserInfo(name, uid = null) {
    return {
      name = name
      uid = uid
      isOwner = false
    }
  }

  function onEventTaskResponse(taskId, db) {
    if (!this.checkEventResponseByType(db))
      this.checkEventResponseByTaskId(taskId, db)
  }

  function checkEventResponseByType(db) {
    let dbType = db?.type
    if (!dbType)
      return false

    if (dbType == "rooms") {
      this.searchInProgress = false
      if (db?.list)
        this.searchRoomList = db.list % "item"
      this.validateSearchList()
      this.defaultRoomsInSearch = false
      this.searchInited = false
      this.fillSearchList()
    }
    else if (dbType == "names") {
      if (!db?.list || !db?.channel)
        return true

      let roomData = g_chat.getRoomById(db.channel)
      if (roomData) {
        let uList = db.list % "item"
        roomData.users = []
        foreach (idx, unit in uList)
          if (u.find_in_array(uList, unit) == idx) { 
            let utbl = this.createRoomUserInfo(unit)
            let first = utbl.name.slice(0, 1)

            if (g_chat_room_type.getRoomType(db.channel).isHaveOwner
                && (first == "@" || first == "+")) {
              utbl.name = utbl.name.slice(1, utbl.name.len())
              utbl.isOwner = true
            }
            roomData.users.append(utbl)
          }
        roomData.users.sort(sortChatUsers)
        this.updateUsersList()
      }
      if (g_chat.isRoomClan(db.channel))
        broadcastEvent("ClanRoomMembersChanged");

      else if (isRoomWWOperation(db.channel) && wwIsOperationLoaded()) {
        this.openChatRoom(db.channel)
      }
    }
    else if (dbType == "user_leave") {
      if (!db?.channel || !db?.nick)
        return true
      if (db.channel == "")
        foreach (roomData in g_chat.rooms) {
          this.removeUserFromRoom(roomData, db.nick)
          if (g_chat.isRoomClan(roomData.id))
            broadcastEvent(
              "ClanRoomMembersChanged",
              { nick = db.nick, presence = contactPresence.OFFLINE }
            )
        }
      else {
        this.removeUserFromRoom(g_chat.getRoomById(db.channel), db.nick)
        if (g_chat.isRoomClan(db.channel))
          broadcastEvent(
            "ClanRoomMembersChanged",
            { nick = db.nick, presence = contactPresence.OFFLINE }
          )
      }
    }
    else if (dbType == "user_join") {
      if (!db?.channel || !db?.nick)
        return true
      let roomData = g_chat.getRoomById(db.channel)
      if (roomData) {
        local found = false
        foreach (user in roomData.users)
          if (user.name == db.nick) {
            found = true
            break
          }
        if (!found) {
          roomData.users.append(this.createRoomUserInfo(db.nick))
          roomData.users.sort(sortChatUsers)
          if (g_chat.isRoomSquad(roomData.id))
            this.onSquadListMember(db.nick, true)

          this.updateUsersList()
        }
        if (g_chat.isRoomClan(db.channel))
          broadcastEvent(
            "ClanRoomMembersChanged",
            { nick = db.nick, presence = contactPresence.ONLINE }
          )
      }
    }
    else if (dbType == "invitation") {
      if (!db?.channel || !db?.from)
        return true

      let fromNick = db.from
      let roomId = db.channel
      addChatRoomInvite(roomId, fromNick)
    }
    else if (dbType == "thread_list" || dbType == "thread_update")
      g_chat.updateThreadInfo(db)
    else if (dbType == "progress_caps")
      g_chat.updateProgressCaps(db)
    else if (dbType == "thread_list_end")
      onChatThreadsListEnd()
    else
      return false
    return true
  }

  function checkEventResponseByTaskId(taskId, _db) {
    if (startsWith(taskId, "join_#")) {
      let roomId = taskId.slice(5)
      if (g_chat.isSystemChatRoom(roomId))
        return

      if (g_chat.isRoomClan(roomId) && !hasFeature("Clans"))
        return

      local room = g_chat.getRoomById(roomId)
      if (!room)
        room = this.addRoom(roomId)
      else {
        room.joined = true
        if (room.customScene)
          this.afterReconnectCustomRoom(roomId)
      }
      if (this.changeRoomOnJoin == roomId)
        this.switchCurRoom(room, false)
      this.updateRoomsList()
      broadcastEvent("ChatRoomJoin", { room = room })
    }
    else if (startsWith(taskId, "leave_#")) {
      let roomId = taskId.slice(6) 
      if (g_chat.isSystemChatRoom(roomId))
        return
      let room = g_chat.getRoomById(roomId)
      if (room) {
        room.joined = false
        let isSquad = g_chat.isRoomSquad(room.id)
        let isClan = g_chat.isRoomClan(room.id)
        if (isSquad || isClan)
          this.silenceUsersByList(room.users)
        room.users = []
        if (isSquad) {
          room.canBeClosed = true
          this.updateRoomTabById(room.id)
        }
        this.addRoomMsg(room.id, "", format(room.getLeaveMessage(), room.getRoomName()))
        this.sceneChanged = true
        this.onRoomChanged()
        broadcastEvent("ChatRoomLeave", { room = room })
      }
    }
  }

  function silenceUsersByList(users) {
    if (!users || !users.len())
      return

    let resultFunc = Callback(
      function(contact) {
        if (!contact)
          return

        if (contact?.voiceStatus == voiceChatStats.talking)
          this.onEventCb(GCHAT_EVENT_VOICE, null,
            { uid = contact.uid, type = "update", is_speaking = false })
      }, this)

    foreach (user in users)
      find_contact_by_name_and_do(user.name, resultFunc)
  }

  function removeUserFromRoom(roomData, nick) {
    if (!("users" in roomData))
      return
    foreach (idx, user in roomData.users)
      if (user.name == nick) {
        if (g_chat.isRoomSquad(roomData.id))
          this.onSquadListMember(nick, false)
        else if ("isOwner" in user && user.isOwner == true)
          gchat_list_names(gchat_escape_target(roomData.id))
        roomData.users.remove(idx)
        if (this.curRoom == roomData)
          this.updateUsersList()
        break
      }
  }

  function addRoomMsg(roomId, from, msg, privateMsg = false, myPrivate = false, overlaySystemColor = null,
    important = false) {
    if (!g_chat_room_type.getRoomType(roomId).isVisible())
      return

    local thisCapture = this
    newMessage(from, msg, privateMsg, myPrivate, overlaySystemColor, important, !g_chat.isRoomSquad(roomId), function(mBlock) {
      if (!mBlock)
        return

      if (g_chat.rooms.len() == 0) {
        if (important) {
          thisCapture.delayedChatRoom.addMessage(mBlock)
          thisCapture.newMessagesGC()
        }
        else if (roomId == "") {
          thisCapture.emptyChatRoom.addMessage(mBlock)
          thisCapture.updateChatText()
        }
      }
      else {
        foreach (roomData in g_chat.rooms) {
          if ((roomId == "") || roomData.id == roomId) {
            roomData.addMessage(mBlock)

            if (roomData?.customScene) {
              this.updateCustomChatTexts()
              continue
            }

            if (!thisCapture.curRoom)
              continue

            if (roomData == thisCapture.curRoom || roomData.hidden)
              thisCapture.updateChatText()

            if (roomId != ""
                && (roomData.type.needCountAsImportant || mBlock.important)
                && !(mBlock.isMeSender || mBlock.isSystemSender)
                && (!lastChatSceneShow.get() || thisCapture.curRoom != roomData)
               ) {
              roomData.newImportantMessagesCount++
              thisCapture.newMessagesGC()

              if (roomData.type.needShowMessagePopup)
                thisCapture.showRoomPopup(mBlock, roomData.id)
            }
            else if (roomId == "" && mBlock.important
              && thisCapture.curRoom.type == g_chat_room_type.SYSTEM && !lastChatSceneShow.get()) {
              roomData.newImportantMessagesCount++
              thisCapture.newMessagesGC()
            }
          }
        }
      }

      if (privateMsg && roomId == "" && !lastChatSceneShow.get())
        thisCapture.newMessagesGC()

      thisCapture.updateRoomsIcons()
    })
  }

  function newMessagesGC() {
    ::update_gamercards()
  }

  function checkNewMessages() {
    if (this.delayedChatRoom && this.delayedChatRoom.mBlocks.len() > 0)
      return

    if (!lastChatSceneShow.get() || !this.curRoom)
      return

    this.curRoom.newImportantMessagesCount = 0

    ::update_gamercards()
  }

  function checkLastActionRoom() {
    if (this.lastActionRoom == "" || !g_chat.getRoomById(this.lastActionRoom))
      this.lastActionRoom = getTblValue("id", this.curRoom, "")
  }

  filterPlayerName = @(name) getPlayerName(
    replace(replace(name, "%20", " "),  "%40", "@"))

  function onMessage(db) {
    if (!db || !db.from)
      return

    if (db?.type == "xpost") {
      if ((db?.message.len() ?? 0) == 0)
        return
      local chat_rooms = g_chat.rooms 
      for (local idx = 0; idx < chat_rooms.len(); ++idx) {
        local room = chat_rooms[idx]
        if (room.id != db?.sender.name)
          continue

        let idxLast = db.message.indexof(">")
        local thisCapture = this
        local onMessageAddedCB = function() {
          if (room == thisCapture.curRoom)
            thisCapture.updateChatText();
        }

        if (idxLast != null && db.message.slice(0, 1) == "<")
          newMessage(db.message.slice(1, idxLast), db.message.slice(idxLast + 1), false, false,
            this.mpostColor, false, false, function(new_message) {
              room.addMessage(new_message)
              onMessageAddedCB()
            })
        else
          newMessage("", db.message, false, false, this.xpostColor, false, false, function(new_message) {
            room.addMessage(new_message)
            onMessageAddedCB()
          })
        break
      }
      return
    }

    if (db?.type == "groupchat" || db?.type == "chat") {
      local roomId = ""
      local user = ""
      local userContact = null
      local clanTag = ""
      local privateMsg = false
      local myPrivate = false

      if (!db?.sender || db.sender?.debug)
        return

      let message = g_chat.localizeReceivedMessage(db?.message)
      if (u.isEmpty(message))
        return

      if (db?.sender.service) {
        this.addRoomMsg(roomId, userContact ?? user, message, privateMsg, myPrivate)
        return
      }

      clanTag = db?.tag ?? ""
      user = db.sender.nick
      if (db?.userId && db.userId != "0")
        userContact = getContact(db.userId, db.sender.nick, clanTag, true)
      else if (db.sender.nick != userName.value)
        clanUserTable.mutate(@(v) v[db.sender.nick] <- clanTag)
      roomId = db?.sender.name
      privateMsg = (db.type == "chat") || !this.roomRegexp.match(roomId)
      let isSystemMessage = g_chat.isSystemUserName(user)

      if (!isSystemMessage && !isCrossNetworkMessageAllowed(user))
        return

      
      if (isSystemMessage) {
        let nameLen = userName.value.len()
        if (message.len() >= nameLen && message.slice(0, nameLen) == userName.value)
          sync_handler_simulate_signal("profile_reload")
      }

      if (privateMsg) {  
        local thisCapture = this
        let dbType = db.type
        let { userId = null, sender } = db
        let { name, nick } = sender
        checkChatEnableWithPlayer(user, function(chatEnabled) {
          if (isUserBlockedByPrivateSetting(userId, user) || !chatEnabled)
            return

          if (dbType == "chat")
            roomId = nick
          myPrivate = nick == userName.value
          if (myPrivate) {
            user = name
            userContact = null
          }

          local haveRoom = false;
          foreach (room in g_chat.rooms)
            if (room.id == roomId) {
              haveRoom = true;
              break;
            }
          if (!haveRoom) {
            if (isPlayerNickInContacts(user, EPL_BLOCKLIST))
              return
            thisCapture.addRoom(roomId)
            thisCapture.updateRoomsList()
          }
          thisCapture.addRoomMsg(roomId, userContact ?? user, message, privateMsg, myPrivate)
        })
        return
      }

      this.addRoomMsg(roomId, userContact ?? user, message, privateMsg, myPrivate)
      return
    }

    if (db?.type == "error") {
      if (db?.error == null)
        return

      this.checkLastActionRoom()
      let errorName = db.error?.errorName
      local roomId = this.lastActionRoom
      let senderFrom = db?.sender.from
      if (db?.error.param1)
        roomId = db.error.param1
      else if (senderFrom && this.roomRegexp.match(senderFrom))
        roomId = senderFrom

      if (errorName == chatErrorName.NO_SUCH_NICK_CHANNEL) {
        if (!this.roomRegexp.match(roomId)) { 
          this.addRoomMsg(this.lastActionRoom, "",
                     format(loc("chat/error/401/userNotConnected"),
                            gchat_unescape_target(this.filterPlayerName(roomId))))
          return
        }
      }
      else if (errorName == chatErrorName.CANNOT_JOIN_THE_CHANNEL && roomId.len() > 1) {
        if (g_chat.isRoomSquad(roomId)) {
          addPopup(null, loc("squad/join_chat_failed"), null, null, null, "squad_chat_failed")
          return
        }

        let wasPasswordEntered = getTblValue(roomId, this.roomJoinParamsTable, "") != ""
        let locId = wasPasswordEntered ? "chat/wrongPassword" : "chat/enterPassword"
        let params = {
          title = roomId.slice(1)
          label = format(loc(locId), roomId.slice(1))
          isPassword = true
          allowEmpty = false
          okFunc = Callback(@(pass) this.joinRoom(roomId, pass), this)
        }

        openEditBoxDialog(params)
        return
      }

      let roomType = g_chat_room_type.getRoomType(roomId)
      if (isInArray(errorName, [chatErrorName.NO_SUCH_CHANNEL, chatErrorName.NO_SUCH_NICK_CHANNEL])) {
        if (roomId == g_chat_room_type.getMySquadRoomId()) {
          this.leaveSquadRoom()
          return
        }
        if (roomType == g_chat_room_type.THREAD) {
          let threadInfo = g_chat.getThreadInfo(roomId)
          if (threadInfo)
            threadInfo.invalidate()
        }
      }

      
      let locParams = {}
      let errParamCount = db.error?.errorParamCount || db.error.getInt("paramCount", 0) 
      for (local i = 0; i < errParamCount; i++) {
        let key = $"param{i}"
        local value = db.error?[key]
        if (!value)
          continue

        if (this.roomRegexp.match(value))
          value = roomType.getRoomName(value)
        else if ((i == 0 && errorName == chatErrorName.CANNOT_JOIN_CHANNEL_NO_INVITATION)
          || ((i == 0 || i == 1) && errorName == chatErrorName.ALREADY_ON_CHANNEL))
          value = this.filterPlayerName(value)

        locParams[key] <- value
      }

      let errMsg = loc($"chat/error/{errorName}{roomType.getErrorPostfix(errorName)}", locParams)
      local roomToSend = roomId
      if (!g_chat.getRoomById(roomToSend))
        roomToSend = this.lastActionRoom
      this.addRoomMsg(roomToSend, "", errMsg)
      if (roomId != roomToSend)
        this.addRoomMsg(roomId, "", errMsg)
      if (roomType.isErrorPopupAllowed) {
        local thisCapture = this
        newMessage("", errMsg, false, false, null, false, false, function(new_message) {
          thisCapture.showRoomPopup(new_message, roomId)
        })
      }
      return
    }

    log("".concat("Chat error: Received message of unknown type = ", db?.type ?? "null"))
  }

  function joinRoom(id, password = "", onJoinFunc = null, customScene = null, ownerHandler = null, reconnect = false) {
    let roomData = g_chat.getRoomById(id)
    if (roomData && id == g_chat_room_type.getMySquadRoomId())
      roomData.canBeClosed = false

    if (roomData && roomData.joinParams != "")
      return ::gchat_raw_command($"join {gchat_escape_target(id)} {roomData.joinParams}")

    if (roomData && reconnect && roomData.joined) 
      return

    this.addChatJoinParams(gchat_escape_target(id), password)
    if (customScene && !roomData)
      this.addRoom(id, customScene, ownerHandler) 

    let task = gchat_join_room(gchat_escape_target(id), password) 
    if (task != "")
      this.chatTasks.append({ task = task, handler = this.onJoinRoom, roomId = id,
                         onJoinFunc = onJoinFunc, customScene = customScene,
                         ownerHandler = ownerHandler
                       })
  }

  function onJoinRoom(event, db, taskConfig) {
    if (event != GCHAT_EVENT_TASK_ERROR && db?.type != "error") {
      local needNewRoom = true
      foreach (room in g_chat.rooms)
        if (taskConfig.roomId == room.id) {
          if (!room.joined) {
            let msgId = g_chat.isRoomSquad(taskConfig.roomId) ? "squad/joinChannel" : "chat/joinChannel"
            this.addRoomMsg(room.id, "", format(loc(msgId), room.getRoomName()))
          }
          room.joined = true
          needNewRoom = false
        }

      if (needNewRoom)
        this.addRoom(taskConfig.roomId, taskConfig.customScene, taskConfig.ownerHandler, true)

      if (("onJoinFunc" in taskConfig) && taskConfig.onJoinFunc)
        taskConfig.onJoinFunc.call(this)
    }
  }

  function addRoom(id, customScene = null, ownerHandler = null, selectRoom = false) {
    let r = newRoom(id, customScene, ownerHandler)
    if (!r.type.isVisible())
      return null

    r.joinParams = this.roomJoinParamsTable?[gchat_escape_target(id)] ??  ""

    if (r.type != g_chat_room_type.PRIVATE)
      this.guiScene.playSound("chat_join")
    g_chat.addRoom(r)

    local thisCapture = this
    this.countUnhiddenRooms(function(unhiddenRoomsCount) {
      if (unhiddenRoomsCount == 1) {
        if (isChatEnabled())
          thisCapture.addRoomMsg(id, "", loc("menuchat/hello"))
      }
    })

    if (selectRoom || r.type.needSwitchRoomOnJoin)
      this.switchCurRoom(r, false)

    if (r.type == g_chat_room_type.SQUAD && isChatEnabled())
      this.addRoomMsg(id, "", loc("squad/channelIntro"))

    if (this.delayedChatRoom && this.delayedChatRoom.mBlocks.len() > 0) {
      for (local i = 0; i < this.delayedChatRoom.mBlocks.len(); i++) {
        r.mBlocks.append(this.delayedChatRoom.mBlocks[i])
      }

      this.delayedChatRoom.clear()
      this.updateChatText()
      this.checkNewMessages()
    }
    if (!r.hidden)
      this.saveJoinedRooms()
    if (chatStatesCanUseVoice() && r.type.canVoiceChat) {
      this.shouldCheckVoiceChatSuggestion = true
      if (handlersManager.findHandlerClassInScene(gui_handlers.MainMenu) != null)
        this.checkVoiceChatSuggestion()
    }
    return r
  }

  function checkVoiceChatSuggestion() {
    if (!this.shouldCheckVoiceChatSuggestion || !isProfileReceived.get())
      return
    this.shouldCheckVoiceChatSuggestion = false

    let VCdata = get_option(USEROPT_VOICE_CHAT)
    let voiceChatShowCount = loadLocalAccountSettings(VOICE_CHAT_SHOW_COUNT_SAVE_ID, 0)
    if (this.isFirstAskForSession && voiceChatShowCount < g_chat.MAX_MSG_VC_SHOW_TIMES && !VCdata.value) {
      this.msgBox("join_voiceChat", loc("msg/enableVoiceChat"),
              [
                ["yes", function() { set_option(USEROPT_VOICE_CHAT, true) }],
                ["no", function() {} ]
              ], "no",
              { cancel_fn = function() {} })
      saveLocalAccountSettings(VOICE_CHAT_SHOW_COUNT_SAVE_ID, voiceChatShowCount + 1)
    }
    this.isFirstAskForSession = false
  }

  function onEventClanInfoUpdate(_p) {
    local haveChanges = false
    foreach (room in g_chat.rooms)
      if (g_chat.isRoomClan(room.id)
          && (room.canBeClosed != (room.id != g_chat.getMyClanRoomId()))) {
        haveChanges = true
        room.canBeClosed = !room.canBeClosed
      }
    if (haveChanges)
      this.updateRoomsList()
  }

  function countUnhiddenRooms(callback) {
    local concealedRooms = 0
    local countRoomsInternal = null
    countRoomsInternal = function(rooms, idx) {
      if (idx >= rooms.len()) {
        callback?(concealedRooms)
      } else {
        local room = rooms[idx]
        room.concealed(function(isConcealed) {
          if (!room.hidden && !isConcealed)
            concealedRooms++
          countRoomsInternal(rooms, idx + 1)
        })
      }
    }

    countRoomsInternal(g_chat.rooms, 0)
  }

  function onRoomClose(obj) {
    if (!obj)
      return
    let id = obj?.id
    if (!id || id.len() < 7 || id.slice(0, 6) != "close_")
      return

    let value = id.slice(6).tointeger()
    this.closeRoom(value)
  }

  function onRemoveRoom(obj) {
    this.closeRoom(obj.getValue(), true)
  }

  function closeRoom(roomIdx, askAllRooms = false) {
    if (!(roomIdx in g_chat.rooms))
      return
    let roomData = g_chat.rooms[roomIdx]
    if (!roomData.canBeClosed)
      return

    if (askAllRooms) {
      let msg = format(loc("chat/ask/leaveRoom"), roomData.getRoomName())
      this.msgBox("leave_squad", msg,
        [
          ["yes",  function() { this.closeRoom(roomIdx) }],
          ["no", function() {} ]
        ], "yes",
        { cancel_fn = function() {} })
      return
    }

    if (roomData.id.slice(0, 1) == "#" && roomData.joined)
      ::gchat_raw_command($"part {gchat_escape_target(roomData.id)}")

    g_chat.rooms.remove(roomIdx)
    this.saveJoinedRooms()
    broadcastEvent("ChatRoomLeave", { room = roomData })
    this.guiScene.performDelayed(this, function() {
      this.updateRoomsList()
    })
  }

  function closeRoomById(id) {
    let idx = this.getRoomIdxById(id)
    if (idx >= 0)
      this.closeRoom(idx)
  }

  function onUsersListActivate(obj) {
    let value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return

    if (!this.curRoom || this.curRoom.users.len() <= value || !this.checkScene())
      return

    let playerName = this.curRoom.users[value].name
    let roomId = this.curRoom.id
    let position = obj.getChild(value).getPosRC()
    find_contact_by_name_and_do(playerName,
      @(contact) showChatPlayerRClickMenu(playerName, roomId, contact, position))
  }

  function onChatCancel(obj) {
    if (this.isCustomRoomActionObj(obj)) {
      let customRoom = this.findCustomRoomByObj(obj)
      if (customRoom && customRoom.ownerHandler && ("onCustomChatCancel" in customRoom.ownerHandler))
        customRoom.ownerHandler.onCustomChatCancel.call(customRoom.ownerHandler)
    }
    else
      this.goBack()
  }

  function onChatEntered(obj) {
    this.chatSendAction(obj, false)
  }

  function checkCmd(msg) {
    if (msg.slice(0, 1) == "\\" || msg.slice(0, 1) == "/")
      foreach (cmd in availableCmdList)
        if ((msg.len() > (cmd.len() + 2) && msg.slice(1, cmd.len() + 2) == ($"{cmd} "))
            || (msg.len() == (cmd.len() + 1) && msg.slice(1, cmd.len() + 1) == cmd)) {
          let hasParam = msg.len() > cmd.len() + 2;

          if (cmd == "help" || cmd == "shelp")
            this.addRoomMsg(this.curRoom.id, "", loc($"menuchat/{cmd}"))
          else if (cmd == "edit")
            g_chat.openModifyThreadWndByRoomId(this.curRoom.id)
          else if (cmd == "msg")
            return hasParam ? msg.slice(0, 1) + msg.slice(cmd.len() + 2) : null
          else if (cmd == "p_check") {
            if (!hasParam) {
              this.addRoomMsg(this.curRoom.id, "", loc("chat/presenceCheckArg"));
              return null;
            }

            if (!is_myself_anyof_moderators()) {
              this.addRoomMsg(this.curRoom.id, "", loc("chat/presenceCheckDenied"));
              return null;
            }

            this.onPresenceDetectionCheckIn(to_integer_safe(msg.slice(cmd.len() + 2), -1))
            return null;
          }
          else if (cmd == "join" || cmd == "part") {
            if (cmd == "join") {
              if (!hasParam) {
                this.addRoomMsg(this.curRoom.id, "", loc("chat/error/461"));
                return null;
              }

              let paramStr = msg.slice(cmd.len() + 2)
              let spaceidx = paramStr.indexof(" ")
              local roomName = spaceidx ? paramStr.slice(0, spaceidx) : paramStr
              if (roomName.slice(0, 1) != "#")
                roomName = $"#{roomName}"
              let pass = spaceidx ? paramStr.slice(spaceidx + 1) : ""

              this.addChatJoinParams(gchat_escape_target(roomName), pass)
            }
            if (msg.len() > cmd.len() + 2)
              if (msg.slice(cmd.len() + 2, cmd.len() + 3) != "#")
                ::gchat_raw_command($"{msg.slice(1, cmd.len() + 2)}#{gchat_escape_target(msg.slice(cmd.len() + 2))}")
              else
                gchat_raw_command(msg.slice(1))
            return null
          }
          else if (cmd == "invite") {
            if (this.curRoom) {
              if (this.curRoom.id == g_chat_room_type.getMySquadRoomId()) {
                if (!hasParam) {
                  this.addRoomMsg(this.curRoom.id, "", loc("chat/error/461"));
                  return null;
                }

                this.inviteToSquadRoom(msg.slice(cmd.len() + 2))
              }
              else
                ::gchat_raw_command($"{msg.slice(1)} {gchat_escape_target(this.curRoom.id)}")
            }
            else
              this.addRoomMsg(this.curRoom.id, "", loc(g_chat.CHAT_ERROR_NO_CHANNEL))
          }
          else if (cmd == "mode" || cmd == "xpost" || cmd == "mpost")
            this.gchatRawCmdWithCurRoom(msg, cmd)
          else if (cmd == "squad_invite" || cmd == "sinvite") {
            if (!hasParam) {
              this.addRoomMsg(this.curRoom.id, "", loc("chat/error/461"));
              return null;
            }

            this.inviteToSquadRoom(msg.slice(cmd.len() + 2))
          }
          else if (cmd == "squad_remove" || cmd == "sremove" || cmd == "kick") {
            if (!hasParam) {
              this.addRoomMsg(this.curRoom.id, "", loc("chat/error/461"));
              return null;
            }

            let playerName = msg.slice(cmd.len() + 2)
            if (cmd == "kick")
              this.kickPlayerFromRoom(playerName)
            else
              g_squad_manager.dismissFromSquadByName(playerName)
          }
          else if (cmd == "squad_ready" || cmd == "sready")
            g_squad_manager.setReadyFlag()
          else
            gchat_raw_command(msg.slice(1))
          return null
        }
    return msg
  }

  function gchatRawCmdWithCurRoom(msg, cmd) {
    if (!this.curRoom)
      this.addRoomMsg("", "", loc(g_chat.CHAT_ERROR_NO_CHANNEL))
    else if (g_chat.isSystemChatRoom(this.curRoom.id))
      this.addRoomMsg(this.curRoom.id, "", loc("chat/cantWriteInSystem"))
    else {
      if (msg.len() > cmd.len() + 2)
        ::gchat_raw_command($"{msg.slice(1, cmd.len() + 2)}{gchat_escape_target(this.curRoom.id)} {msg.slice(cmd.len() + 2)}")
      else
        ::gchat_raw_command($"{msg.slice(1)} {gchat_escape_target(this.curRoom.id)}")
    }
  }

  function kickPlayerFromRoom(playerName) {
    if (!this.curRoom || g_chat.isSystemChatRoom(this.curRoom.id))
      return this.addRoomMsg(this.curRoom || "", "", loc(g_chat.CHAT_ERROR_NO_CHANNEL))
    if (this.curRoom.id == g_chat_room_type.getMySquadRoomId())
      return g_squad_manager.dismissFromSquadByName(playerName)

    ::gchat_raw_command($"kick {gchat_escape_target(this.curRoom.id)} {gchat_escape_target(playerName)}")
  }

  function squadMsg(msg) {
    let sRoom = g_chat_room_type.getMySquadRoomId()
    this.addRoomMsg(sRoom, "", msg)
    if (this.curRoom && this.curRoom.id != sRoom)
      this.addRoomMsg(this.curRoom.id, "", msg)
  }

  function leaveSquadRoom() {
    
    foreach (room in g_chat.rooms) {
      if (room.type != g_chat_room_type.SQUAD || !room.joined)
        continue

      ::gchat_raw_command($"part {gchat_escape_target(room.id)}")
      room.joined = false 
      room.canBeClosed = true
      this.silenceUsersByList(room.users)
      room.users.clear()
      this.updateRoomTabById(room.id)

      if (this.curRoom == room)
        this.updateUsersList()
    }
  }

  function isInSquadRoom() {
    let roomName = g_chat_room_type.getMySquadRoomId()
    foreach (room in g_chat.rooms)
      if (room.id == roomName)
        return room.joined
    return false
  }

  function inviteToSquadRoom(playerName, delayed = false) {
    if (!gchat_is_connected())
      return false

    if (!hasFeature("Squad")) {
      this.addRoomMsg(this.curRoom.id, "", loc("msgbox/notAvailbleYet"))
      return false
    }

    if (!g_squad_manager.isInSquad())
      return false

    if (!playerName)
      return false

    if (!g_squad_manager.isSquadLeader()) {
      this.addRoomMsg(this.curRoom.id, "", loc("squad/only_leader_can_invite"))
      return false
    }

    if (!this.isInSquadRoom())
      return false

    if (delayed) {
      let dcmd = $"xinvite {gchat_escape_target(playerName)} {gchat_escape_target(g_chat_room_type.getMySquadRoomId())}"
      log(dcmd)
      gchat_raw_command(dcmd)
    }

    ::gchat_raw_command($"invite {gchat_escape_target(playerName)} {gchat_escape_target(g_chat_room_type.getMySquadRoomId())}")
    return true
  }

  function onSquadListMember(name, join) {
    if (!g_squad_manager.isInSquad())
      return

    this.addRoomMsg(g_chat_room_type.getMySquadRoomId(),
      "",
      format(loc(join ? "squad/player_join" : "squad/player_leave"),
          getPlayerName(name)
    ))
  }

  function squadReady() {
    if (g_squad_manager.canSwitchReadyness())
      g_squad_manager.setReadyFlag()
  }

  function onEventSquadSetReady(_params) {
    this.updateReadyButton()
    if (g_squad_manager.isInSquad())
      this.squadMsg(loc(g_squad_manager.isMeReady() ? "squad/change_to_ready" : "squad/change_to_not_ready"))
  }

  function onEventQueueChangeState(_params) {
    this.updateReadyButton()
  }

  function onEventSquadPlayerInvited(params) {
    if (!g_squad_manager.isSquadLeader())
      return

    let uid = getTblValue("uid", params, "")
    if (u.isEmpty(uid))
      return

    let contact = getContact(uid)
    if (contact != null)
       this.squadMsg(format(loc("squad/invited_player"), getPlayerName(contact.name)))
  }

  function checkValidAndSpamMessage(msg, isPrivate = false) {
    if (is_chat_message_empty(msg))
      return false
    if (isPrivate || is_myself_anyof_moderators())
      return true
    if (is_chat_message_allowed(msg))
      return true
    return false
  }

  function checkAndPrintDevoiceMsg(roomId = null) {
    if (!roomId)
      roomId = this.curRoom.id

    let devoice = penalties.getDevoiceMessage()
    if (devoice)
      this.addRoomMsg(roomId, "", devoice)
    return devoice != null
  }

  function onChatEdit(obj) {
    let sceneData = this.getSceneDataByActionObj(obj)
    if (!sceneData)
      return
    let roomData = g_chat.getRoomById(sceneData.room)
    if (roomData)
      roomData.lastTextInput = obj.getValue()
  }

  function onChatSend(obj) {
    this.chatSendAction(obj, true)
  }

  function getTimeToActivateSendBtnSec() {
    return this.chatSendBtnActivateTime != null
      ? max((this.chatSendBtnActivateTime - get_time_msec()) / 1000, 0)
      : 0
  }

  function toggleSendBtnHint(sceneData, show) {
    showObjById("btn_send_hint", show, sceneData.scene)
  }

  function checkAndUpdateSendBtn(sceneData = null) {
    if (this.chatSendBtnActivateTime == null)
      return

    let chatScene = sceneData?.scene
    let sendBtn = chatScene?.findObject("btn_send") ?? this?.scene.findObject("btn_send")
    if (!(sendBtn?.isValid() ?? false))
      return

    let roomId = sceneData?.room ?? this.curRoom?.id ?? ""
    if (roomId == "")
      return

    let roomData = g_chat.getRoomById(roomId)
    let isChatAvailableInCurRoom = roomData?.isChatAvailableInCurRoom ?? true
    let leftTimeToActivateSendBtnSec = this.getTimeToActivateSendBtnSec()
    let needToShowSendTitle = leftTimeToActivateSendBtnSec == 0
    sendBtn.enable(needToShowSendTitle && isChatAvailableInCurRoom)
    sendBtn.setValue(needToShowSendTitle ? loc("chat/send")
      : $"{format("%d", ceil(min(leftTimeToActivateSendBtnSec, chatUpdateSendBtnTextDelaySec)))}{loc("measureUnits/seconds")}")

    if (this.hasErrorOnSendMessage && needToShowSendTitle) {
      this.hasErrorOnSendMessage = false
      this.toggleSendBtnHint(sceneData, false)
    }
  }

  function chatSendAction(obj, isFromButton = false) {
    let sceneData = this.getSceneDataByActionObj(obj)
    if (!sceneData)
      return

    let roomId = sceneData.room
    if (roomId == "")
      return

    if (this.getTimeToActivateSendBtnSec() > 0)
      return

    this.lastActionRoom = roomId
    let inputObj = sceneData.scene.findObject("menuchat_input")
    let value = checkObj(inputObj) ? inputObj.getValue() : ""
    if (value == "") {
      let roomData = this.findCustomRoomByObj(obj)
      if (!isFromButton && roomData && roomData.ownerHandler && ("onCustomChatContinue" in roomData.ownerHandler))
        roomData.ownerHandler.onCustomChatContinue.call(roomData.ownerHandler)
      return
    }

    this.sendMessageToRoom(value, sceneData, inputObj)
  }

  function sendMessageToRoom(msg, sceneData, inputObj) {
    last_send_messages.append(msg)
    if (last_send_messages.len() > g_chat.MAX_LAST_SEND_MESSAGES)
      last_send_messages.remove(0)
    this.lastSendIdx = -1

    if (!checkChatConnected())
      return

    msg = this.checkCmd(msg)
    if (!msg)
      return

    let roomId = sceneData.room
    if (roomId == "")
      return

    if (this.checkAndPrintDevoiceMsg(roomId))
      return

    msg = g_chat.validateChatMessage(msg)

    let privateData = this.getPrivateData(msg, roomId)
    if (privateData)
      this.onChatPrivate(privateData)
    else {
      if (this.checkValidAndSpamMessage(msg)) {
        inputObj.setValue("")
        this.toggleSendBtnHint(sceneData, false)
        if (g_chat.isSystemChatRoom(roomId))
          this.addRoomMsg(roomId, "", loc("chat/cantWriteInSystem"))
        else {
          ::gchat_chat_message(gchat_escape_target(roomId), msg)
          this.guiScene.playSound("chat_send")
        }
      }
      else {
        this.hasErrorOnSendMessage = true
        this.toggleSendBtnHint(sceneData, true)
      }
      if (!is_myself_anyof_moderators()) {
        this.chatSendBtnActivateTime = get_time_msec()
          + (chatUpdateSendBtnTextDelaySec + CHAT_SEND_BTN_ADD_DELAY_SEC) * 1000
        this.checkAndUpdateSendBtn(sceneData)
      }
    }
  }

  function getPrivateData(msg, roomId = null) {
    if (msg.slice(0, 1) == "\\" || msg.slice(0, 1) == "/") {
      msg = msg.slice(1)
      let res = { user = "", msg = "" }
      let start = msg.indexof(" ") ?? -1
      if (start < 1)
        res.user = msg
      else {
        res.user = msg.slice(0, start)
        res.msg = msg.slice(start + 1)
      }
      return res
    }
    if (!roomId && this.curRoom)
      roomId = this.curRoom.id
    if (roomId && g_chat_room_type.PRIVATE.checkRoomId(roomId))
      return { user = roomId, msg = msg }
    return null
  }

  function onChatPrivate(data) {
    if (!this.checkValidAndSpamMessage(data.msg, true))
      return
    if (!this.curRoom)
      return

    if (!gchat_chat_private_message(gchat_escape_target(this.curRoom.id), gchat_escape_target(data.user), data.msg))
      return

    this.addRoomMsg(this.curRoom.id, userName.value, data.msg, true, true)

    let blocked = isPlayerNickInContacts(data.user, EPL_BLOCKLIST)
    if (blocked)
      this.addRoomMsg(
        this.curRoom.id,
        "",
        format(
          loc("chat/cantChatWithBlocked"),
          $"<Link={g_chat.generatePlayerLink(data.user)}>{getPlayerName(data.user)}</Link>"
        )
      )
    else if (data.user != this.curRoom.id) {
      let userRoom = g_chat.getRoomById(data.user)
      if (!userRoom) {
        this.addRoom(data.user)
        this.updateRoomsList()
      }
      this.addRoomMsg(data.user, userName.value, data.msg, true, true)
    }
  }

  function showLastSendMsg(showScene = null) {
    if (!checkObj(showScene))
      return
    let obj = showScene.findObject("menuchat_input")
    if (!checkObj(obj))
      return

    obj.setValue((this.lastSendIdx in last_send_messages) ? last_send_messages[this.lastSendIdx] : "")
  }

  function openInviteMenu(menu, position) {
    if (menu.len() > 0)
      openRightClickMenu(menu, this, position)
  }

  function hasPrefix(roomId, prefix) {
    return roomId.len() >= prefix.len() && roomId.slice(0, prefix.len()) == prefix
  }

  function switchLastSendMsg(inc, _obj) {
    if (last_send_messages.len() == 0)
      return

    let selObj = this.guiScene.getSelectedObject()
    if (!checkObj(selObj) || selObj?.id != "menuchat_input")
      return
    let sceneData = this.getSceneDataByActionObj(selObj)
    if (!sceneData)
      return

    this.lastSendIdx += inc
    if (this.lastSendIdx < -1)
      this.lastSendIdx = last_send_messages.len() - 1
    if (this.lastSendIdx >= last_send_messages.len())
      this.lastSendIdx = -1
    this.showLastSendMsg(sceneData.scene)
  }

  function onPrevMsg(obj) {
    this.switchLastSendMsg(-1, obj)
  }

  function onNextMsg(obj) {
    this.switchLastSendMsg(-1, obj)
  }

  function onShowPlayersList() {
    this.showPlayersList = !this.showPlayersList
    this.updateUsersList()
  }

  function onChatLinkClick(obj, _itype, link)  { this.onChatLink(obj, link, !showConsoleButtons.value) }
  function onChatLinkRClick(obj, _itype, link) { this.onChatLink(obj, link, false) }

  function onChatLink(obj, link, lclick) {
    let sceneData = this.getSceneDataByActionObj(obj)
    if (!sceneData)
      return

    if (link && link.len() < 4)
      return

    if (link.slice(0, 2) == "PL") {
      local name = ""
      local contact = null
      if (link.slice(0, 4) == "PLU_") {
        contact = getContact(link.slice(4))
        name = contact.name
      }
      else {
        name = link.slice(3)
        contact = getContactByName(name)
      }
      if (lclick)
        this.addNickToEdit(name, sceneData.scene)
      else
        showChatPlayerRClickMenu(name, sceneData.room, contact)
    }
    else if (g_chat.checkBlockedLink(link)) {
      let roomData = g_chat.getRoomById(sceneData.room)
      if (!roomData)
        return

      let childIndex = obj.childIndex.tointeger()
      roomData.mBlocks[childIndex].text = g_chat.revealBlockedMsg(roomData.mBlocks[childIndex].text, link)
      obj.setValue(roomData.mBlocks[childIndex].text)
      this.updateChatText()
    }
    else
      acceptInviteByLink(link)
  }

  function onUserListClick(obj)  { this.onUserList(obj, !showConsoleButtons.value) }
  function onUserListRClick(obj) { this.onUserList(obj, false) }

  function onUserList(obj, lclick) {
    if (!obj?.id || obj.id.len() <= 10 || obj.id.slice(0, 10) != "user_name_")
      return

    let num = obj.id.slice(10).tointeger()
    local name = obj.text
    if (this.curRoom && this.checkScene())
      if (this.curRoom.users.len() > num) {
          name = this.curRoom.users[num].name
          this.scene.findObject("users_list").setValue(num)
        }

    let sceneData = this.getSceneDataByActionObj(obj)
    if (!sceneData)
      return
    if (lclick)
      this.addNickToEdit(name, sceneData.scene)
    else
      showChatPlayerRClickMenu(name, sceneData.room)
  }

  function changePrivateTo(user) {
    if (!checkChatConnected())
      return
    if (!this.checkScene())
      return

    if (user != this.curRoom?.id) {
      let userRoom = g_chat.getRoomById(user)
      if (!userRoom)
        this.addRoom(user)
      this.switchCurRoom(user)
    }
    broadcastEvent("ChatOpenPrivateRoom", { room = user })
  }

  function addNickToEdit(user, showScene = null) {
    if (!showScene) {
      if (!this.checkScene())
        return
      showScene = this.scene
    }

    let inputObj = showScene.findObject("menuchat_input")
    if (!checkObj(inputObj))
      return

    ::add_text_to_editbox(inputObj, $"{getPlayerName(user)} ")
    this.selectEditbox(inputObj)
  }

  function onShowSearchList() {
    this.showSearch(null, true)
  }

  function showSearch(show = null, selectSearchEditbox = false) {
    if (!this.checkScene())
      return

    let sObj = this.scene.findObject("searchDiv")
    let wasVisible = sObj.isVisible()
    if (show == null)
      show = !wasVisible

    if (!show && wasVisible)
      this.loadSizes()

    sObj.show(show)
    if (show) {
      this.setSavedSizes()
      if (!this.searchInited)
        this.fillSearchList()
      showObjById("btn_join_room", !showConsoleButtons.value, this.scene)
      if (selectSearchEditbox)
        this.selectEditbox(this.scene.findObject("search_edit"))
    }
  }

  function validateSearchList() {
    if (!this.searchRoomList)
      return

    for (local i = this.searchRoomList.len() - 1; i >= 0; i--)
      if (!g_chat_room_type.getRoomType(this.searchRoomList[i]).isVisibleInSearch())
        this.searchRoomList.remove(i)
  }

  function resetSearchList() {
    this.searchRoomList = []
    this.searchShowNotFound = false
    this.defaultRoomsInSearch = true
  }

  function resetChat() {
    last_send_messages.clear()
    this.roomsInited = false
    this.chatSendBtnActivateTime = null
    this.hasErrorOnSendMessage = false
  }

  function fillSearchList() {
    if (!this.checkScene())
      return

    if (!this.searchRoomList)
      this.resetSearchList()

    showObjById("btn_mainChannels", !this.defaultRoomsInSearch && g_chat_room_type.GLOBAL.isVisibleInSearch(), this.scene)

    let listObj = this.scene.findObject("searchList")
    if (!checkObj(listObj))
      return

    this.guiScene.setUpdatesEnabled(false, false)
    local data = ""
    let total = min(this.searchRoomList.len(), g_chat.MAX_ROOMS_IN_SEARCH)
    if (this.searchRoomList.len() > 0) {
      for (local i = 0; i < total; i++) {
        local rName = this.searchRoomList[i]
        rName = (rName.slice(0, 1) == "#") ? rName.slice(1) : loc($"chat/channel/{rName}", rName)
        data = "".concat(data, format("text { id:t='search_room_txt_%d'; text:t='%s'; tooltip:t='%s'; }",
          i, stripTags(rName), stripTags(rName)))
      }
    }
    else {
      if (this.searchInProgress)
        data = "animated_wait_icon { pos:t='0.5(pw-w),0.03sh'; position:t='absolute'; background-rotation:t='0' }"
      else if (this.searchShowNotFound)
        data = "textAreaCentered { text:t='#contacts/searchNotFound'; enable:t='no' }"
      this.searchShowNotFound = true
    }

    this.guiScene.replaceContentFromText(listObj, data, data.len(), this)
    this.guiScene.setUpdatesEnabled(true, true)

    this.searchInited = true
  }

  last_search_time = -10000000
  function onSearchStart() {
    if (!this.checkScene())
      return

    if (!ps4_is_ugc_enabled()) {
      ps4_show_ugc_restriction()
      return
    }

    if (this.searchInProgress && (get_time_msec() - this.last_search_time < 5000))
      return

    let sObj = this.scene.findObject("search_edit")
    local value = sObj.getValue()
    if (!value || is_chat_message_empty(value))
      return

    value = "".concat("#", clearBorderSymbols(value, [" ", "*"]), "*")
    this.searchInProgress = true
    this.defaultRoomsInSearch = false
    this.searchRoomList = []
    gchat_list_rooms(gchat_escape_target(value))
    this.fillSearchList()

    this.last_search_time = get_time_msec()
  }

  function closeSearch() {
    if (g_chat.isSystemChatRoom(this.curRoom.id))
      this.goBack()
    else if (this.checkScene()) {
      this.scene.findObject("searchDiv").show(false)
      this.selectChatInputEditbox()
    }
  }

  function onCancelSearchEdit(obj) {
    if (!checkObj(obj))
      return

    if (obj.getValue() == "" && this.defaultRoomsInSearch)
      this.closeSearch()
    else {
      this.onMainChannels()
      obj.setValue("")
    }

    this.searchShowNotFound = false
  }

  function onCancelSearchRooms(_obj) {
    if (!this.checkScene())
      return

    if (this.defaultRoomsInSearch)
      return this.closeSearch()

    local searchObj = this.scene.findObject("search_edit")
    this.selectEditbox(searchObj)
    this.onMainChannels()
  }

  function onSearchRoomJoin(obj) {
    if (!this.checkScene())
      return

    if (!checkObj(obj))
      obj = this.scene.findObject("searchList")

    let value = obj.getValue()
    if (value in this.searchRoomList) {
      if (!isChatEnabled(true))
        return
      if (!isInArray(this.searchRoomList[value], globalChatRoomsList) && !ps4_is_ugc_enabled()) {
        ps4_show_ugc_restriction()
        return
      }

      this.selectChatInputEditbox()
      let rName = (this.searchRoomList[value].slice(0, 1) != "#") ? $"# {this.searchRoomList[value]}" : this.searchRoomList[value]
      let room = g_chat.getRoomById(rName)
      if (room)
        this.switchCurRoom(room)
      else {
        this.changeRoomOnJoin = rName
        this.joinRoom(this.changeRoomOnJoin)
      }
    }
  }

  function onMainChannels() {
    if (this.checkScene() && !this.defaultRoomsInSearch)
      this.guiScene.performDelayed(this, function() {
        if (!this.defaultRoomsInSearch) {
          this.resetSearchList()
          this.fillSearchList()
        }
      })
  }

  function isMenuChatActive() {
    return this.checkScene() && lastChatSceneShow.get();
  }

  function addChatJoinParams(roomName, pass) {
    this.roomJoinParamsTable[roomName] <- pass
  }

  function showRoomPopup(msgBlock, roomId) {
    if (get_gui_option_in_mode(USEROPT_SHOW_SOCIAL_NOTIFICATIONS, OPTIONS_MODE_GAMEPLAY))
      addPopup(msgBlock.fullName && msgBlock.fullName.len() ? ($"{msgBlock.fullName}:") : null,
        msgBlock.msgs.top(),
        @() g_chat.openChatRoom(roomId)
      )
  }

  function popupAcceptInvite(roomId) {
    if (g_chat_room_type.THREAD.checkRoomId(roomId)) {
      g_chat.joinThread(roomId)
      this.changeRoomOnJoin = roomId
      return
    }

    this.openChatRoom(this.curRoom.id)
    this.joinRoom(roomId)
    this.changeRoomOnJoin = roomId
  }

  function openChatRoom(roomId) {
    let curScene = getLastGamercardScene()
    this.switchScene(getChatObject(curScene))
    this.chatSceneShow(true)

    let roomList = this.scene.findObject("rooms_list")
    foreach (idx, room in g_chat.rooms)
      if (room.id == roomId) {
        roomList.setValue(idx)
        break
      }
    this.onRoomChanged()
  }

  function onEventPlayerPenaltyStatusChanged(_params) {
    if (this.curRoom)
      this.checkAndPrintDevoiceMsg()
  }

  function onEventNewSceneLoaded(_p) {
    this.guiScene.performDelayed(this, function() { 
      this.updateCustomChatTexts()
    })
  }

  function updateCustomChatTexts() {
    for (local idx = g_chat.rooms.len() - 1; idx >= 0; idx--) {
      let room = g_chat.rooms[idx]
      if (checkObj(room.customScene)) {
        let obj = room.customScene.findObject("custom_chat_text_block")
        if (checkObj(obj))
          this.drawRoomTo(room, obj)
      }
      else if (room.existOnlyInCustom)
        this.closeRoom(idx)
    }
  }

  function isCustomRoomActionObj(obj) {
    return (obj?._customRoomId ?? "") != ""
  }

  function findCustomRoomByObj(obj) {
    let id = obj?._customRoomId ?? ""
    if (id != "")
      return g_chat.getRoomById(id)

    
    foreach (item in g_chat.rooms)
      if (checkObj(item.customScene) && item.customScene.isEqual(obj))
        return item
    return null
  }

  function getSceneDataByActionObj(obj) {
    if (this.isCustomRoomActionObj(obj)) {
      let customRoom = this.findCustomRoomByObj(obj)
      if (!customRoom || !checkObj(customRoom.customScene))
        return null

      return { room = customRoom.id, scene = customRoom.customScene }
    }
    else if (this.checkScene())
      return { room = this.curRoom.id, scene = this.scene }

    return null
  }

  function joinCustomObjRoom(sceneObj, roomId, password, ownerHandler) {
    if (!hasMenuChatMPlobby.value) {
      sceneObj.show(hasMenuChatMPlobby.value)
      return
    }
    let prevRoom = this.findCustomRoomByObj(sceneObj)
    if (prevRoom)
      if (prevRoom.id == roomId)
        return
      else
        this.closeRoomById(prevRoom.id)

    let objGuiScene = sceneObj.getScene()
    objGuiScene.replaceContent(sceneObj, "%gui/chat/customChat.blk", this)
    let timer = sceneObj.findObject("custom_chat_timer")
    timer._customRoomId = roomId
    timer.setUserData(this)

    foreach (name in ["menuchat_input", "btn_send", "btn_prevMsg", "btn_nextMsg"]) {
      let obj = sceneObj.findObject(name)
      obj._customRoomId = roomId
    }

    initChatMessageListOn(sceneObj.findObject("custom_chat_text_block"), this, roomId)

    let room = g_chat.getRoomById(roomId)
    if (room) {
      room.customScene = sceneObj
      room.ownerHandler = ownerHandler
      room.joined = true
      this.afterReconnectCustomRoom(roomId)
      this.updateChatText()
    }

    this.joinRoom(roomId, password,
      function() {
        this.afterReconnectCustomRoom(roomId)
      },
      sceneObj, ownerHandler)
  }

  function afterReconnectCustomRoom(roomId) {
    let roomData = g_chat.getRoomById(roomId)
    if (!roomData || !checkObj(roomData.customScene))
      return

    this.checkChatAvailableInRoom(roomData.id, function(isChatAvailable) {
      roomData.isChatAvailableInCurRoom <- isChatAvailable
      showObjById("menuchat_input", isChatAvailable, roomData.customScene)
      showObjById("btn_send", isChatAvailable, roomData.customScene)
      this.checkAndUpdateSendBtn()
    })
  }

  function checkListValue(obj) {
    if (obj.getValue() < 0 && obj.childrenCount())
      obj.setValue(0)
  }

  function onEventInviteReceived(params) {
    let invite = getTblValue("invite", params)
    if (!invite || !invite.isVisible())
      return

    let msg = invite.getChatInviteText()
    if (msg.len())
      this.addRoomMsg("", "", msg, false, false, invite.inviteColor, true)
  }

  function onEventInviteUpdated(params) {
    this.onEventInviteReceived(params)
  }

  function onEventUpdateChatFeatures(_) {
    this.rejoinDefaultRooms(true)
    this.updateRoomsList()
  }

  function onChatInputWrapRight() {
    if (this.checkScene())
      move_mouse_on_obj(this.scene.findObject("btn_send"))
  }

  function onEventChatChangePrivateTo(params) {
    this.changePrivateTo(params.user)
  }

  function onEventChatJoinRoom(params) {
    let { id, password = "", onJoinFunc = null, customScene = null, ownerHandler = null, reconnect = false } = params
    this.joinRoom(id, password, onJoinFunc, customScene, ownerHandler, reconnect)
  }

  function onEventChatLeaveSquadRoom(_params) {
    this.leaveSquadRoom()
  }

  function onEventChatSwitchCurRoom(params) {
    let { roomId } = params
    this.switchCurRoom(roomId)
  }

  function onEventChatAddRoomMsg(params) {
    let { roomId, from, msg } = params
    this.addRoomMsg(roomId, from, msg)
  }

  function ChatCheckVoiceChatSuggestion(_params) {
    this.checkVoiceChatSuggestion()
  }

  function onEventChatKickPlayerFromRoom(params) {
    let { playerName } = params
    this.kickPlayerFromRoom(playerName)
  }

  function onEventChatAddNickToEdit(params) {
    let { playerName } = params
    this.addNickToEdit(playerName)
  }

  function onEventChatOpenInviteMenu(params) {
    let { menu, position } = params
    this.openInviteMenu(menu, position)
  }

  function onEventChatJoinCustomObjRoom(params) {
    let { sceneObj, roomId, password, ownerHandler } = params
    this.joinCustomObjRoom(sceneObj, roomId, password, ownerHandler)
  }

  function onEventChatUpdatePresence(params) {
    this.updatePresenceContact(params.contact)
  }

  function onEventChatSwitchObject(params) {
    let { scene } = params
    this.switchScene(getChatObject(scene))
  }

  function onEventChatSwitchObjectIfVisible(params) {
    if (!lastChatSceneShow.get() || (isPlatformSony && is_in_loading_screen()))
      return
    this.switchScene(params.obj, true)
  }

  function onEventChatCheckScene(_params) {
    this.checkScene()
  }

  function onEventChatCheckIsActive(_params) {
    if (!this.isMenuChatActive())
      isChatEnabled(true)
  }

  chatSendBtnActivateTime = null
  hasErrorOnSendMessage = false
  scene = null
  sceneChanged = true
  roomsInited = false

  shouldCheckVoiceChatSuggestion = false
  isFirstAskForSession = true

  chatTasks = []
  lastSendIdx = -1

  curRoom = null
  lastActionRoom = ""
  showPlayersList = true

  searchInProgress = false
  searchShowNotFound = false
  searchRoomList = null
  searchInited = false
  defaultRoomsInSearch = false
  changeRoomOnJoin = ""

  xpostColor = "@chatTextXpostColor"
  mpostColor = "@chatTextMpostColor"
}

hasMenuGeneralChats.subscribe(@(_) deferOnce(sendEventUpdateChatFeatures))
hasMenuChatPrivate.subscribe(@(_) deferOnce(sendEventUpdateChatFeatures))
hasMenuChatSquad.subscribe(@(_) deferOnce(sendEventUpdateChatFeatures))
hasMenuChatClan.subscribe(@(_) deferOnce(sendEventUpdateChatFeatures))

function createMenuChatHandler(scene) {
  menuChatHandler.set(MenuChatHandler(scene))
  return menuChatHandler.get()
}

addListenersWithoutEnv({
  AuthorizeComplete = @(_p) createMenuChatHandler(get_gui_scene()).initChat(null)
})

eventbus_subscribe("on_sign_out", function(_p) {
  if (menuChatHandler.get())
    menuChatHandler.get().resetChat()
})

if (isAuthorized.get())
  createMenuChatHandler(get_gui_scene()).initChat(null)

return {
  createMenuChatHandler
  menuChatHandler
}
