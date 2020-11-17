local { clearBorderSymbols } = require("std/string.nut")
local penalties = require("scripts/penitentiary/penalties.nut")
local { getPlayerName,
        isPlayerFromXboxOne,
        isPlatformSony } = require("scripts/clientState/platform.nut")
local menuChatRoom = require("scripts/chat/menuChatRoom.nut")
local { topMenuBorders } = require("scripts/mainmenu/topMenuStates.nut")
local { isChatEnabled, isChatEnableWithPlayer,
  isCrossNetworkMessageAllowed, chatStatesCanUseVoice } = require("scripts/chat/chatStates.nut")
local { updateContactsStatusByContacts } = require("scripts/contacts/updateContactsStatus.nut")

const CHAT_ROOMS_LIST_SAVE_ID = "chatRooms"
const VOICE_CHAT_SHOW_COUNT_SAVE_ID = "voiceChatShowCount"

::menu_chat_handler <- null
::menu_chat_sizes <- null
::last_chat_scene_show <- false

::last_send_messages <- []

::clanUserTable <- {}

::default_chat_rooms <- ["general"]
::langs_list <- ["en", "ru"] //first is default
::global_chat_rooms_list <- null
::global_chat_rooms <- [{name = "general", langs = ["en", "ru", "de", "zh", "vn"] },
                        {name = "radio", langs = ["ru"], hideInOtherLangs = true },
                        {name = "lfg" },
                        {name = "historical"},
                        {name = "realistic"}
                       ]

::punctuation_list <- [" ", ".", ",", ":", ";", "\"", "'", "~","!","@","#","$","%","^","&","*",
                       "(",")","+","|","-","=","\\","/","<",">","[","]","{","}","`","?"]
::cur_chat_lang <- ::loc("current_lang")

::available_cmd_list <- ["help", //local command to view help
                         "edit", //local command to open thread edit window for opened thread
                         "msg", "join", "part", "invite", "mode",
                         "kick", /*"list",*/
                         /* "ping", "users", */
                         "shelp", "squad_invite", "sinvite", "squad_remove", "sremove", "squad_ready", "sready",
                         "reauth", "xpost", "mpost", "p_check"
                        ]

::voiceChatIcons <- {
  [voiceChatStats.online] = "voip_enabled",
  //[voiceChatStats.offline] = "voip_disabled",
  [voiceChatStats.talking] = "voip_talking",
  [voiceChatStats.muted] = "voip_banned" //picture existed, was not renamed
}

::g_script_reloader.registerPersistentData("MenuChatGlobals", ::getroottable(), ["clanUserTable"]) //!!FIX ME: must be in contacts

local sortChatUsers = @(a, b) a.name <=> b.name

::getGlobalRoomsListByLang <- function getGlobalRoomsListByLang(lang, roomsList = null)
{
  local res = []
  local def_lang = ::isInArray(lang, ::langs_list)? lang : ::langs_list[0]
  foreach(r in ::global_chat_rooms)
  {
    local l = def_lang
    if ("langs" in r && r.langs.len())
    {
      l = ::isInArray(lang, r.langs)? lang : r.langs[0]
      if (::getTblValue("hideInOtherLangs", r, false) && !::isInArray(lang, r.langs))
        continue
    }
    if (!roomsList || ::isInArray(r.name, roomsList))
      res.append(r.name + "_" + l)
  }
  return res
}

::getGlobalRoomsList <- function getGlobalRoomsList(all_lang=false)
{
  local res = getGlobalRoomsListByLang(::cur_chat_lang)
  if (all_lang)
    foreach(lang in ::langs_list)
      if (lang!=::cur_chat_lang)
      {
        local list = getGlobalRoomsListByLang(lang)
        foreach(ch in list)
          if (!::isInArray(ch, res))
            res.append(ch)
      }
  return res
}
::global_chat_rooms_list = getGlobalRoomsList(true)

class ::MenuChatHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  needLocalEcho = true
  skipMyMessages = false //to skip local echo from code events
  presenceDetectionTimer = 0
  static roomRegexp = regexp2("^#[^\\s]")

  roomHandlerWeak = null
  emptyChatRoom = menuChatRoom.newRoom("#___empty___")
  delayedChatRoom = menuChatRoom.newRoom("#___empty___")
  prevScenes = [] //{ scene, show }
  roomJoinParamsTable = {} //roomName : paramString
  lastShowedInRoomMessageIndex = -1

  wndControlsAllowMask = CtrlsInGui.CTRL_ALLOW_FULL

  isChatWindowMouseOver = false
  curHoverObjId = null
  static editboxObjIdList = [ "menuchat_input", "search_edit" ]

  constructor(gui_scene, params = {})
  {
    ::g_script_reloader.registerPersistentData("MenuChatHandler", this, ["roomsInited"]) //!!FIX ME: must be in g_chat

    base.constructor(gui_scene, params)
    ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
  }

  function isValid()
  {
    return true
  }

  function getControlsAllowMask()
  {
    if (!isMenuChatActive() || !scene.isEnabled())
      return CtrlsInGui.CTRL_ALLOW_FULL
    return wndControlsAllowMask
  }

  function updateControlsAllowMask()
  {
    local mask = CtrlsInGui.CTRL_ALLOW_FULL

    if (::last_chat_scene_show)
    {
      local focusObj = guiScene.getSelectedObject()
      local hasFocusedObj = ::check_obj(focusObj) && editboxObjIdList.contains(focusObj?.id)

      if (hasFocusedObj || (::show_console_buttons && isChatWindowMouseOver))
        if (::show_console_buttons)
          mask = CtrlsInGui.CTRL_ALLOW_VEHICLE_FULL & ~CtrlsInGui.CTRL_ALLOW_VEHICLE_XINPUT
        else
          mask = CtrlsInGui.CTRL_ALLOW_VEHICLE_FULL & ~CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD
    }

    switchControlsAllowMask(mask)
  }

  function onChatEditboxFocus(obj)
  {
    guiScene.performDelayed(this, function() {
      if (checkScene())
        updateControlsAllowMask()
    })
  }

  function onChatWindowMouseOver(obj)
  {
    if (!::show_console_buttons)
      return
    local isMouseOver = checkScene() && obj.isMouseOver()
    if (isChatWindowMouseOver == isMouseOver)
      return
    isChatWindowMouseOver = isMouseOver
    updateControlsAllowMask()
  }

  function onChatListHover(obj)
  {
    if (checkScene() && obj.isHovered())
      checkListValue(obj)
  }

  function selectEditbox(obj)
  {
    if (checkScene() && ::check_obj(obj) && obj.isVisible() && obj.isEnabled())
      ::select_editbox(obj)
  }

  function selectChatInputEditbox()
  {
    selectEditbox(scene.findObject("menuchat_input"))
  }

  function initChat(obj, resetList = true)
  {
    if (obj!=null && obj == scene)
      return

    needLocalEcho = !::is_vendor_tencent()

    set_gchat_event_cb(null, ::menuChatCb)
    chatSceneShow(false)
    scene = obj
    sceneChanged = true

    if (resetList)
      prevScenes = []
    chatSceneShow(true)
    reloadChatScene()
  }

  function switchScene(obj, onlyShow = false)
  {
    if (!::checkObj(obj) || (::checkObj(scene) && scene.isEqual(obj)))
    {
      if (!onlyShow || !::last_chat_scene_show)
        chatSceneShow()
    } else
    {
      prevScenes.append({
        scene = scene
        show = ::last_chat_scene_show
        roomHandlerWeak = roomHandlerWeak && roomHandlerWeak.weakref()
      })
      roomHandlerWeak = null
      removeFromPrevScenes(obj)
      initChat(obj, false)
    }
  }

  function removeFromPrevScenes(obj)
  {
    for(local i=prevScenes.len()-1; i>=0; i--)
    {
      local scn = prevScenes[i].scene
      if (!::checkObj(scn) || scn.isEqual(obj))
        prevScenes.remove(i)
    }
  }

  function checkScene()
  {
    if (::checkObj(scene))
      return true

    for(local i=prevScenes.len()-1; i>=0; i--)
      if (::checkObj(prevScenes[i].scene))
      {
        scene = prevScenes[i].scene
        guiScene = scene.getScene()
        local prevRoomHandler = prevScenes[i].roomHandlerWeak
        roomHandlerWeak = prevRoomHandler && prevRoomHandler.weakref()
        sceneChanged = true
        chatSceneShow(prevScenes[i].show || ::last_chat_scene_show)
        return true
      } else
        prevScenes.remove(i)
    scene = null
    return false
  }

  function reloadChatScene()
  {
    if (!checkScene())
      return

    if (!scene.findObject("menuchat"))
    {
      guiScene = scene.getScene()
      sceneChanged = true
      guiScene.replaceContent(scene, "gui/chat/menuChat.blk", this)
      setSavedSizes()
      scene.findObject("menu_chat_update").setUserData(this)
      local hasChat = isChatEnabled()
      showSceneBtn("chat_input_place", hasChat)
      local chatObj = showSceneBtn("menuchat_input", hasChat)
      chatObj["max-len"] = ::g_chat.MAX_MSG_LEN.tostring()
      showSceneBtn("btn_send", hasChat)
      searchInited = false

      menuChatRoom.initChatMessageListOn(scene.findObject("menu_chat_messages_container"), this)
      updateRoomsList()
    }
  }

  function fillList(listObj, formatText, listTotal)
  {
    local total = listObj.childrenCount()
    if (total > listTotal)
      for(local i = total-1; i>=listTotal; i--)
        guiScene.destroyElement(listObj.getChild(i))
    else if (total < listTotal)
    {
      local data = ""
      for(local i = total; i<listTotal; i++)
        data += format(formatText, i, i)
      guiScene.appendWithBlk(listObj, data, this)
    }
  }

  function switchCurRoom(room, needUpdateWindow = true)
  {
    if (::u.isString(room))
      room = ::g_chat.getRoomById(room)
    if (!room || room == curRoom)
      return

    curRoom = room
    sceneChanged = true
    if (needUpdateWindow)
      updateRoomsList()
  }

  function updateRoomsList()
  {
    if (!checkScene())
      return
    local obj = scene.findObject("rooms_list")
    if(!::checkObj(obj))
      return

    guiScene.setUpdatesEnabled(false, false)
    local roomFormat = "shopFilter { shopFilterText { id:t='room_txt_%d'; text:t='' } Button_close { id:t='close_%d'; on_click:t='onRoomClose';}}\n"
    fillList(obj, roomFormat, ::g_chat.rooms.len())

    local curVal = -1
    foreach(idx, room in ::g_chat.rooms)
    {
      updateRoomTabByIdx(idx, room, obj)

      if (room == curRoom)
        curVal = idx
    }

    if (curVal<0 && ::g_chat.rooms.len() > 0)
    {
      curVal = obj.getValue()
      if (curVal < 0 || curVal > ::g_chat.rooms.len())
        curVal = ::g_chat.rooms.len()-1
    }

    if (curVal != obj.getValue())
      obj.setValue(curVal)

    guiScene.setUpdatesEnabled(true, true)

    if (!onRoomChanged())
    {
      checkNewMessages()
      updateRoomsIcons()
    }
  }

  function onRoomChanged()
  {
    if (!checkScene())
      return false

    local obj = scene.findObject("rooms_list")
    local value = obj.getValue()
    local roomData = ::getTblValue(value, ::g_chat.rooms)

    if (!roomData)
    {
      updateUsersList()
      updateChatText()
      updateInputText(roomData)
      scene.findObject("chat_input_place").show(false)
      return false
    }

    if (roomData == curRoom && !sceneChanged)
      return false

    curRoom = roomData
    showSceneBtn("btn_showPlayersList", !alwaysShowPlayersList() && roomData.havePlayersList)
    showSceneBtn("btn_showSearchList", ::g_chat.isThreadsView)
    showSceneBtn("chat_input_place", !roomData.hasCustomViewHandler)
    showSceneBtn("menu_chat_text_block", !roomData.hasCustomViewHandler)

    updateUsersList()
    updateChatText()
    updateInputText(roomData)
    checkNewMessages()
    updateRoomsIcons()
    updateSquadInfo()

    if (!::g_chat.isThreadsView)
      showSearch(::g_chat.isSystemChatRoom(curRoom.id))

    checkSwitchRoomHandler(roomData)
    updateHeaderBlock(roomData)

    sceneChanged = false
    return true
  }

  function onRoomRClick(obj)
  {
    if (curRoom.type == ::g_chat_room_type.PRIVATE)
      ::g_chat.showPlayerRClickMenu(curRoom.id, curRoom.id)
  }

  function checkSwitchRoomHandler(roomData)
  {
    showSceneBtn("menu_chat_custom_handler_block", roomData.hasCustomViewHandler)
    if (!roomData.hasCustomViewHandler)
      return

    if (!roomHandlerWeak)
      return createRoomHandler(roomData)

    if (("roomId" in roomHandlerWeak) && roomHandlerWeak.roomId != roomData.id)
    {
      if ("remove" in roomHandlerWeak)
        roomHandlerWeak.remove()
      createRoomHandler(roomData)
      return
    }

    if ("onSceneShow" in roomHandlerWeak)
      roomHandlerWeak.onSceneShow()
  }

  function createRoomHandler(roomData)
  {
    local obj = scene.findObject("menu_chat_custom_handler_block")
    local roomHandler = roomData.type.loadCustomHandler(obj, roomData.id, ::Callback(goBack, this))
    roomHandlerWeak = roomHandler && roomHandler.weakref()
  }

  function updateHeaderBlock(roomData)
  {
    if (!checkScene())
      return

    local hasChatHeader = roomData.type.hasChatHeader
    local obj = showSceneBtn("menu_chat_header_block", hasChatHeader)
    local isRoomChanged = obj?.roomId != roomData.id
    if (!isRoomChanged)
    {
      if (hasChatHeader)
        roomData.type.updateChatHeader(obj, roomData)
      return
    }

    if (!hasChatHeader)
      return //header block is hidden, so no point to remvoe it.

    roomData.type.fillChatHeader(obj, roomData)
    obj.roomId = roomData.id
  }

  function updateInputText(roomData)
  {
    scene.findObject("menuchat_input").setValue(::getTblValue("lastTextInput", roomData, ""))
  }

  function updateRoomTabByIdx(idx, room, listObj = null)
  {
    if (!checkScene())
      return
    if (!listObj)
      listObj = scene.findObject("rooms_list")
    if (listObj.childrenCount() <= idx)
      return
    local roomTab = listObj.getChild(idx)
    if (!::checkObj(roomTab))
      return

    roomTab.canClose = room.canBeClosed? "yes" : "no"
    roomTab.enable(!room.hidden && !room.concealed())
    roomTab.show(!room.hidden && !room.concealed())
    roomTab.tooltip = room.type.getTooltip(room.id)
    local textObj = roomTab.findObject("room_txt_"+idx)
    textObj.colorTag = room.type.getRoomColorTag(room.id)
    textObj.setValue(room.getRoomName())
  }

  function updateRoomTabById(roomId)
  {
    foreach(idx, room in ::g_chat.rooms)
      if (room.id == roomId)
        updateRoomTabByIdx(idx, room)
  }

  function updateAllRoomTabs()
  {
    if (!checkScene())
      return
    local listObj = scene.findObject("rooms_list")
    foreach(idx, room in ::g_chat.rooms)
      updateRoomTabByIdx(idx, room, listObj)
  }

  function onEventChatThreadInfoChanged(p)
  {
    updateRoomTabById(::getTblValue("roomId", p))
  }

  function onEventChatFilterChanged(p)
  {
    updateAllRoomTabs()
  }

  function onEventContactsGroupUpdate(p)
  {
    updateAllRoomTabs()
  }

  function onEventSquadStatusChanged(p)
  {
    updateAllRoomTabs()
  }

  function onEventCrossNetworkChatOptionChanged(p)
  {
    updateAllRoomTabs()
  }

  function onEventContactsBlockStatusUpdated(p) {
    updateAllRoomTabs()
  }

  function onEventVoiceChatOptionUpdated(p)
  {
    updateUsersList()
  }

  function alwaysShowPlayersList()
  {
    return ::show_console_buttons
  }

  function getRoomIdxById(id)
  {
    foreach(idx, item in ::g_chat.rooms)
      if (item.id == id)
        return idx
    return -1
  }

  function updateRoomsIcons()
  {
    if (!checkScene() || !::last_chat_scene_show)
      return

    local roomsObj = scene.findObject("rooms_list")
    if (!roomsObj)
      return

    local total = roomsObj.childrenCount()
    if (total > ::g_chat.rooms.len())
      total = ::g_chat.rooms.len() //Maybe assert here?
    for(local i=0; i<total; i++)
    {
      local childObj = roomsObj.getChild(i)
      local obj = childObj.findObject("new_msgs")
      local haveNew = ::g_chat.rooms[i].newImportantMessagesCount > 0
      if (::checkObj(obj) != haveNew)
        if (haveNew)
        {
          local data = ::handyman.renderCached("gui/cssElems/cornerImg", {
            id = "new_msgs"
            img = "#ui/gameuiskin#chat_new.svg"
            hasGlow = true
          })
          guiScene.appendWithBlk(childObj, data, this)
        } else
          guiScene.destroyElement(obj)
    }
  }

  function updateUsersList()
  {
    if (!checkScene())
      return

    guiScene.setUpdatesEnabled(false, false)
    local listObj = scene.findObject("users_list")
    local leftObj = scene.findObject("middleLine")
    if (!curRoom || !curRoom.havePlayersList || (!showPlayersList && !alwaysShowPlayersList()))
    {
      leftObj.show(false)
      //guiScene.replaceContentFromText(listObj, "", 0, this)
    }
    else
    {
      leftObj.show(true)
      local users = curRoom.users
      if (users==null)
        guiScene.replaceContentFromText(listObj, "", 0, this)
      else
      {
        local userFormat = "text { id:t='user_name_%d'; behaviour:t='button'; " +
                             "on_click:t='onUserListClick'; on_r_click:t='onUserListRClick'; " +
                             "tooltipObj { id:t='tooltip'; uid:t=''; on_tooltip_open:t='onContactTooltipOpen'; on_tooltip_close:t='onTooltipObjClose'; display:t='hide' }\n " +
                             "title:t='$tooltipObj';\n" +
                           "}\n"
        fillList(listObj, userFormat, users.len())
        foreach(idx, user in users)
        {
          local fullName = ::g_contacts.getPlayerFullName(
            getPlayerName(user.name),
            ::clanUserTable?[user.name] ?? ""
          )
          listObj.findObject("user_name_"+idx).setValue(fullName)
        }
      }
    }
    if (curRoom)
      foreach(idx, user in curRoom.users)
      {
        if (user.uid == null && (::g_squad_manager.isInMySquad(user.name, false) || ::is_in_my_clan(user.name)))
          user.uid = ::Contact.getByName(user.name)?.uid

        local contact = (user.uid != null)? ::getContact(user.uid) : null
        updateUserPresence(listObj, idx, contact)
      }

    updateReadyButton()
    guiScene.setUpdatesEnabled(true, true)
  }

  function updateReadyButton()
  {
    if (!checkScene() || !showPlayersList || !curRoom)
      return

    local readyShow = curRoom.id == ::g_chat.getMySquadRoomId() && ::g_squad_manager.canSwitchReadyness()
    local readyObj = scene.findObject("btn_ready")
    showSceneBtn("btn_ready", readyShow)
    if (readyShow)
      readyObj.setValue(::g_squad_manager.isMeReady() ? ::loc("multiplayer/btnNotReady") : ::loc("mainmenu/btnReady"))
  }

  function updateSquadInfo()
  {
    if (!checkScene() || !curRoom)
      return

    local squadBRTextObj = scene.findObject("battle_rating")
    if (!::checkObj(squadBRTextObj))
      return

    local br = ::g_squad_manager.getLeaderBattleRating()
    local isShow = br && ::g_squad_manager.isInSquad() && curRoom.id == ::g_chat.getMySquadRoomId()

    if(isShow)
    {
      local gmText = ::events.getEventNameText(
                       ::events.getEvent(::g_squad_manager.getLeaderGameModeId())
                     ) ?? ""
      local desc = ::loc("shop/battle_rating") +" "+ format("%.1f", br)
      desc = ::g_string.implode([gmText, desc], "\n")
      squadBRTextObj.setValue(desc)
    }
    squadBRTextObj.show(isShow)
  }

  function onEventSquadDataUpdated(params)
  {
    updateSquadInfo()
  }

  function updateUserPresence(listObj, idx, contact)
  {
    local obj = listObj.findObject("user_name_" + idx)
    if (obj)
    {
      local inMySquad = contact && ::g_squad_manager.isInMySquad(contact.name, false)
      local inMyClan = contact && ::is_in_my_clan(contact.name)
      local img = inMySquad ? contact.presence.getIcon() : ""
      local img2 = ""
      local voiceIcon = ""
      if (inMySquad)
      {
        local memberData = ::g_squad_manager.getMemberData(contact.uid)
        if (memberData && checkCountry(memberData.country, "squad member data ( uid = " + contact.uid + ")", true))
          img2 = ::get_country_icon(memberData.country)
      }
      obj.findObject("tooltip").uid = (inMySquad && contact)? contact.uid : ""
      if (::get_option_voicechat()
          && (inMySquad || inMyClan)
          && chatStatesCanUseVoice()
          && contact.voiceStatus in ::voiceChatIcons)
        voiceIcon = "#ui/gameuiskin#" + ::voiceChatIcons[contact.voiceStatus]

      setIcon(obj, "statusImg", "img", img)
      setIcon(obj, "statusImg2", "img2", img2)
      setIcon(obj, "statusVoiceIcon", "voiceIcon", voiceIcon)
      local imgCount = (inMySquad? 2 : 0) + (voiceIcon != ""? 1 : 0)
      obj.imgType = imgCount==0? "none" : (imgCount.tostring()+"ico")
    }
  }

  function setIcon(obj, id, blockName, image)
  {
    if(!checkObj(obj))
      return

    local picObj = obj.findObject(id)
    if(picObj)
      picObj["background-image"] = image
    else
    {
      local string = "%s { id:t='%s'; background-image:t='%s'}"
      local data = format(string, blockName, id, image)
      guiScene.prependWithBlk(obj, data, this)
    }
  }

  function updatePresenceContact(contact)
  {
    if (!checkScene() || !::last_chat_scene_show)
      return

    if (!curRoom) return

    foreach(idx, user in curRoom.users)
      if (user.name == contact.name)
      {
        user.uid = contact.uid
        local listObj = scene.findObject("users_list")
        updateUserPresence(listObj, idx, contact)
        return
      }
  }

  function updateChatText()
  {
    updateCustomChatTexts()
    if (!checkScene())
      return

    local roomToDraw = null
    if (curRoom) {
      if (curRoom.hasCustomViewHandler)
        return
      roomToDraw = curRoom
    }
    else if (!::gchat_is_connected())
    {
      if (::gchat_is_connecting() || ::g_chat.rooms.len()==0)
      {
        roomToDraw = menuChatRoom.newRoom("#___empty___")
        roomToDraw.addMessage(menuChatRoom.newMessage("", ::loc("chat/connecting")))
      } else {
        roomToDraw = emptyChatRoom
        roomToDraw.addMessage(menuChatRoom.newMessage("", ::loc("chat/disconnected")))
      }
    }
    if (roomToDraw)
      drawRoomTo(roomToDraw, scene.findObject("menu_chat_messages_container"), sceneChanged)
  }

  function drawRoomTo(room, messagesContainer, isSceneChanged = false) {
    local lastMessageIndex = (room.mBlocks.len() == 0) ? -1:room.mBlocks.top().messageIndex
    if (lastMessageIndex == lastShowedInRoomMessageIndex && !isSceneChanged)
      return

    lastShowedInRoomMessageIndex = lastMessageIndex

    messagesContainer.getScene().setUpdatesEnabled(false, false)

    local totalMblocks = room.mBlocks.len()
    local numChildrens = messagesContainer.childrenCount()
    for(local i=0; i < numChildrens; i++) {
      local msgObj = messagesContainer.getChild(i)
      local textObj  = msgObj.findObject("chat_message_text")
      if (i < totalMblocks) {
        msgObj.show(true)
        msgObj.messageType=room.mBlocks[i].messageType
        textObj.setValue(room.mBlocks[i].text)
      } else {
        msgObj.show(false)
      }
    }
    messagesContainer.getScene().setUpdatesEnabled(true, true)
  }

  function chatSceneShow(show=null)
  {
    if (!checkScene())
      return

    if (show==null)
      show = !scene.isVisible()
    if (!show)
      loadSizes()
    scene.show(show)
    scene.enable(show)
    ::last_chat_scene_show = show
    if (show)
    {
      setSavedSizes()
      rejoinDefaultRooms(true)
      checkNewMessages()
      updateRoomsList()
      updateSquadInfo()
      guiScene.performDelayed(this, restoreFocus)
      ::update_objects_under_windows_state(guiScene)
    }
    else
      ::clear_objects_under_windows(guiScene)

    onChatWindowMouseOver(scene)
  }

  function restoreFocus()
  {
    if (!checkScene())
      return
    local inputObj = scene.findObject("menuchat_input")
    if (::check_obj(inputObj) && inputObj.isVisible())
      selectEditbox(inputObj)
    else
      ::move_mouse_on_child_by_value(scene.findObject("rooms_list"))
  }

  function loadRoomParams(roomName, joinParams)
  {
    foreach(r in ::default_chat_rooms) //validate incorrect created default chat rooms by cur lang
      if (roomName == "#" + r + "_" + ::cur_chat_lang)  {
        local rList = ::getGlobalRoomsListByLang(::cur_chat_lang, [r])
        // default rooms should have empty joinParams
        return {  roomName = (rList.len()? "#" + rList[0] : roomName)
                  joinParams = ""  }
      }

    local idx = roomName.indexof(" ")
    if ( idx )  {
      //  loading legacy record like '#some_chat password'
      return {  roomName = "#"+::g_chat.validateRoomName( roomName.slice(0, idx) )
                joinParams = roomName.slice(idx+1)  }
    }

    return {  roomName = roomName
              joinParams = joinParams  }
  }

  function rejoinDefaultRooms(initRooms = false)
  {
    if (!::gchat_is_connected() || !::g_login.isProfileReceived())
      return
    if (roomsInited && !initRooms)
      return

    local baseRoomsList = ::g_chat.getBaseRoomsList()
    foreach(idx, roomId in baseRoomsList)
      if (!::g_chat.getRoomById(roomId))
        addRoom(roomId, null, null, idx == 0)

    if (isChatEnabled())
    {
      local chatRooms = ::load_local_account_settings(CHAT_ROOMS_LIST_SAVE_ID)
      local roomIdx = 0
      if (chatRooms != null)
      {
        local storedRooms = []
        for(roomIdx = 0; chatRooms?["room"+roomIdx]; roomIdx++)
          storedRooms.append( loadRoomParams(chatRooms?["room"+roomIdx],
                                             chatRooms?["params"+roomIdx]) )

        foreach (it in storedRooms)
        {
          local roomType = ::g_chat_room_type.getRoomType(it.roomName)
          if (!roomType.needSave()) //"needSave" has changed
            continue

          ::gchat_raw_command(::format("join %s%s",  it.roomName,  (it.joinParams==""?"":" "+it.joinParams) ))
          addChatJoinParams(it.roomName, it.joinParams)
        }
      }

      if (roomIdx==0 && !roomsInited && !::g_chat.isThreadsView)
      {
        local roomsList = ::getGlobalRoomsListByLang(::cur_chat_lang, ::default_chat_rooms)
        foreach(room in roomsList)
          joinRoom("#" + room)
      }
    }
    roomsInited = true
  }

  function saveJoinedRooms()
  {
    if (!roomsInited)
      return

    local saveIdx = 0
    local chatRoomsBlk = ::DataBlock()
    foreach(room in ::g_chat.rooms)
      if (!room.hidden && room.type.needSave())
      {
        chatRoomsBlk["room" + saveIdx] = ::gchat_escape_target(room.id)
        if (room.joinParams != "")
          chatRoomsBlk["params" + saveIdx] = room.joinParams
        saveIdx++
      }
    ::save_local_account_settings(CHAT_ROOMS_LIST_SAVE_ID, chatRoomsBlk)
  }

  function goBack()
  {
    chatSceneShow(false)
  }

  function loadSizes()
  {
    if (isMenuChatActive())
    {
      ::menu_chat_sizes = {}
      local obj = scene.findObject("menuchat")
      ::menu_chat_sizes.pos <- obj.getPosRC()
      ::menu_chat_sizes.size <- obj.getSize()
      obj = scene.findObject("middleLine")
      ::menu_chat_sizes.usersSize <- obj.getSize()
      obj = scene.findObject("searchDiv")
      if (obj.isVisible())
        ::menu_chat_sizes.searchSize <- obj.getSize()

      saveLocalByScreenSize("menu_chat_sizes", save_to_json(::menu_chat_sizes))
    }
  }

  function onRoomCreator()
  {
    ::g_chat.openRoomCreationWnd()
  }

  function setSavedSizes()
  {
    if (!::menu_chat_sizes)
    {
      local data = loadLocalByScreenSize("menu_chat_sizes")
      if (data)
      {
        ::menu_chat_sizes = ::parse_json(data)
        if (!("pos" in ::menu_chat_sizes) || !("size" in ::menu_chat_sizes) || !("usersSize" in ::menu_chat_sizes))
          ::menu_chat_sizes = null
        else
        {
          ::menu_chat_sizes.pos[0] = ::menu_chat_sizes.pos[0].tointeger()
          ::menu_chat_sizes.pos[1] = ::menu_chat_sizes.pos[1].tointeger()
          ::menu_chat_sizes.size[0] = ::menu_chat_sizes.size[0].tointeger()
          ::menu_chat_sizes.size[1] = ::menu_chat_sizes.size[1].tointeger()
          ::menu_chat_sizes.usersSize[0] = ::menu_chat_sizes.usersSize[0].tointeger()
          ::menu_chat_sizes.usersSize[1] = ::menu_chat_sizes.usersSize[1].tointeger()
        }
      }
    }

    if (!isMenuChatActive() || !::menu_chat_sizes)
      return

    local obj = scene.findObject("menuchat")
    if (!obj) return

    local pos = ::getTblValue("pos", ::menu_chat_sizes)
    local size = ::getTblValue("size", ::menu_chat_sizes)
    if (!pos || !size)
      return

    local rootSize = guiScene.getRoot().getSize()
    for(local i=0; i<=1; i++) //pos chat in screen
      if (pos[i] < topMenuBorders[i][0]*rootSize[i])
        pos[i] = (topMenuBorders[i][0]*rootSize[i]).tointeger()
      else
        if (pos[i]+size[i] > topMenuBorders[i][1]*rootSize[i])
          pos[i] = (topMenuBorders[i][1]*rootSize[i] - size[i]).tointeger()

    obj.pos = pos[0] + ", " + pos[1]
    obj.size = size[0] + ", " + size[1]

    if ("usersSize" in ::menu_chat_sizes)
    {
      obj = scene.findObject("middleLine")
      obj.size = ::menu_chat_sizes.usersSize[0] + ", ph" // + ::menu_chat_sizes.usersSize[1]
    }

    if ("searchSize" in ::menu_chat_sizes)
    {
      obj = scene.findObject("searchDiv")
      if (obj.isVisible() && ("searchSize" in ::menu_chat_sizes))
        obj.size = ::menu_chat_sizes.searchSize[0] + ", ph"
    }
  }

  function onPresenceDetectionCheckIn( code )
  {
    if ( (code >= 0) && (code < ::get_pds_code_limit()) )
    {
//      local taskId =
      ::send_pds_presence_check_in( code )
//      if (taskId >= 0)
//      {
//        ::set_char_cb(this, slotOpCb)
//        showTaskProgressBox(::loc("charServer/send"))
//        afterSlotOp = goBack
//      }
    }
  }

  function onPresenceDetectionTick()
  {
    if ( !::gchat_is_connected() )
      return

    if ( !::is_myself_anyof_moderators() )
      return

    if ( presenceDetectionTimer <= 0 )
    {
      presenceDetectionTimer = get_pds_next_time()
    }

    if ( get_charserver_time_sec() > presenceDetectionTimer )
    {
      presenceDetectionTimer = 0
      local msg = format( ::loc("chat/presenceCheck"), ::get_pds_code_suggestion().tostring() )

      addRoomMsg("", "", msg, false, false)
    }
  }

  //once per 1 sec
  function onUpdate(obj, dt)
  {
    if (!::last_chat_scene_show)
      return

    loadSizes()
    onPresenceDetectionTick()
  }

  function onEventCb(event, taskId, db)
  {
//    if (event == ::GCHAT_EVENT_TASK_RESPONSE || event == ::GCHAT_EVENT_TASK_ERROR)
    foreach(idx, t in chatTasks)
      if (t.task==taskId)
      {
        t.handler.call(this, event, db, t)
        chatTasks.remove(idx)
      }
    if (event == ::GCHAT_EVENT_MESSAGE)
    {
      if (isChatEnabled())
        onMessage(db)
    }
    else if (event == ::GCHAT_EVENT_CONNECTED)
    {
      if (roomsInited)
      {
        showRoomPopup(menuChatRoom.newMessage("", ::loc("chat/connected")), ::g_chat.getSystemRoomId())
      }
      rejoinDefaultRooms()
      if (g_chat.rooms.len() > 0)
      {
        local msg = ::loc("chat/connected")
        addRoomMsg("", "", msg)
      }

      foreach (room in ::g_chat.rooms)
      {
        if (room.id.slice(0, 1) != "#" || ::g_chat.isSystemChatRoom(room.id))
          continue

        local cb = (!::checkObj(room.customScene))? null : (@(room) function() { afterReconnectCustomRoom(room.id) })(room)
        joinRoom(room.id, "", cb, null, null, true)
      }
      updateRoomsList()
      ::broadcastEvent("ChatConnected")
    } else if (event == ::GCHAT_EVENT_DISCONNECTED)
      addRoomMsg("", "", ::loc("chat/disconnected"))
    else if (event == ::GCHAT_EVENT_CONNECTION_FAILURE)
      addRoomMsg("", "", ::loc("chat/connectionFail"))
    else if (event == ::GCHAT_EVENT_TASK_RESPONSE)
      onEventTaskResponse(taskId, db)
    else if (event == ::GCHAT_EVENT_VOICE)
    {
      if(db.uid)
      {
        local contact = ::getContact(db.uid)
        local voiceChatStatus = null
        if(db.type == "join")
        {
          voiceChatStatus = ::xbox_is_chat_player_muted(db.uid.tointeger())?
                              voiceChatStats.muted :
                              voiceChatStats.online
        }
        if(db.type == "part")
        {
          voiceChatStatus = voiceChatStats.offline
        }
        if(db.type == "update")
        {
          if (::xbox_is_chat_player_muted(db.uid.tointeger()))
            voiceChatStatus = voiceChatStats.muted
          else if(db.is_speaking)
            voiceChatStatus = voiceChatStats.talking
          else
            voiceChatStatus = voiceChatStats.online
        }

        if(!contact)
          ::collectMissedContactData(db.uid, "voiceStatus", voiceChatStatus)
        else
        {
          contact.voiceStatus = voiceChatStatus
          if (checkScene())
            ::chatUpdatePresence(contact)
        }

        ::broadcastEvent("VoiceChatStatusUpdated", {
                                                    uid = db.uid,
                                                    voiceChatStatus = voiceChatStatus
                                                   })

        ::call_darg("updateVoiceChatStatus", { name = contact?.getName() ?? "",
          isTalking = voiceChatStatus == voiceChatStats.talking})
      }
    }
    /* //!! For debug only!!
    //dlog("GP: New event: " + event + ", " + taskId)
    local msg = "New event: " + event + ", " + taskId
    if (db)
    {
      foreach(name, param in db)
        if (typeof(param) != "instance")
          msg += "\n" + name + " = " + param
        else
        if (name=="list")
        {
          msg+="list = ["
          foreach(idx, val in param % "item")
            msg += ((idx!=0)? ", " : "") + val
          msg+="]\n"
        }
        else
        {
          msg += "\n" + name + " {"
          foreach(n, p in param)
            msg += "\n  " + n + " = " + p
          msg+="\n}"
        }
    }
    addRoomMsg(curRoom.id, "", msg)
    */ //debug end
  }

  function createRoomUserInfo(name, uid = null)
  {
    return {
      name = name
      uid = uid
      isOwner = false
    }
  }

  function onEventTaskResponse(taskId, db)
  {
    if (!checkEventResponseByType(db))
      checkEventResponseByTaskId(taskId, db)
  }

  function checkEventResponseByType(db)
  {
    local dbType = db?.type
    if (!dbType)
      return false

    if (dbType=="rooms")
    {
      searchInProgress = false
      if (db?.list)
        searchRoomList = db.list % "item"
      validateSearchList()
      defaultRoomsInSearch = false
      searchInited = false
      fillSearchList()
    }
    else if (dbType=="names")
    {
      if (!db?.list || !db?.channel)
        return true

      local roomData = ::g_chat.getRoomById(db.channel)
      if (roomData)
      {
        local uList = db.list % "item"
        roomData.users = []
        foreach(idx, u in uList)
          if (::find_in_array(uList, u)==idx) //check duplicates
          {
            local utbl = createRoomUserInfo(u)
            local first = utbl.name.slice(0,1)

            if (::g_chat_room_type.getRoomType(db.channel).isHaveOwner
                && (first == "@" || first == "+"))
            {
              utbl.name = utbl.name.slice(1,utbl.name.len())
              utbl.isOwner = true
            }
            roomData.users.append(utbl)
          }
        roomData.users.sort(sortChatUsers)
        updateUsersList()
      }
      if (::g_chat.isRoomClan(db.channel))
        ::broadcastEvent("ClanRoomMembersChanged");
    }
    else if (dbType=="user_leave")
    {
      if (!db?.channel || !db?.nick)
        return true
      if (db.channel=="")
        foreach(roomData in ::g_chat.rooms)
        {
          removeUserFromRoom(roomData, db.nick)
          if (::g_chat.isRoomClan(roomData.id))
            ::broadcastEvent(
              "ClanRoomMembersChanged",
              {nick = db.nick, presence = ::g_contact_presence.OFFLINE }
            )
        }
      else
      {
        removeUserFromRoom(::g_chat.getRoomById(db.channel), db.nick)
        if (::g_chat.isRoomClan(db.channel))
          ::broadcastEvent(
            "ClanRoomMembersChanged",
            {nick = db.nick, presence = ::g_contact_presence.OFFLINE }
          )
      }
    }
    else if (dbType=="user_join")
    {
      if (!db?.channel || !db?.nick)
        return true
      local roomData = ::g_chat.getRoomById(db.channel)
      if (roomData)
      {
        local found = false
        foreach(u in roomData.users)
          if (u.name == db.nick)
          {
            found = true
            break
          }
        if (!found)
        {
          roomData.users.append(createRoomUserInfo(db.nick))
          roomData.users.sort(sortChatUsers)
          if (::g_chat.isRoomSquad(roomData.id))
            onSquadListMember(db.nick, true)

          updateUsersList()
        }
        if (::g_chat.isRoomClan(db.channel))
          ::broadcastEvent(
            "ClanRoomMembersChanged",
            {nick = db.nick, presence = ::g_contact_presence.ONLINE }
          )
      }
    }
    else if (dbType=="invitation")
    {
      if (!db?.channel || !db?.from)
        return true

      local fromNick = db.from
      local roomId = db.channel
      ::g_invites.addChatRoomInvite(roomId, fromNick)
    }
    else if (dbType == "thread_list" || dbType == "thread_update")
      ::g_chat.updateThreadInfo(db)
    else if (dbType == "progress_caps")
      ::g_chat.updateProgressCaps(db)
    else if ( dbType == "thread_list_end" )
      ::g_chat_latest_threads.onThreadsListEnd()
    else
      return false
    return true
  }

  function checkEventResponseByTaskId(taskId, db)
  {
    if (::g_string.startsWith(taskId, "join_#"))
    {
      local roomId = taskId.slice(5)
      if (::g_chat.isSystemChatRoom(roomId))
        return

      if (::g_chat.isRoomClan(roomId) && !::has_feature("Clans"))
        return

      local room = ::g_chat.getRoomById(roomId)
      if (!room)
        room = addRoom(roomId)
      else
      {
        room.joined = true
        if (room.customScene)
          afterReconnectCustomRoom(roomId)
      }
      if (changeRoomOnJoin == roomId)
        switchCurRoom(room, false)
      updateRoomsList()
      ::broadcastEvent("ChatRoomJoin", { room = room })
    }
    else if (::g_string.startsWith(taskId, "leave_#"))
    {
      local roomId = taskId.slice(6) //auto reconnect to this channel by server
      if (::g_chat.isSystemChatRoom(roomId))
        return
      local room = ::g_chat.getRoomById(roomId)
      if (room)
      {
        room.joined = false
        local isSquad = ::g_chat.isRoomSquad(room.id)
        local isClan = ::g_chat.isRoomClan(room.id)
        local msgId = isSquad ? "squad/leaveChannel" : "chat/leaveChannel"
        if (isSquad || isClan)
          silenceUsersByList(room.users)
        room.users = []
        if (isSquad)
        {
          room.canBeClosed = true
          updateRoomTabById(room.id)
        }
        addRoomMsg(room.id, "", ::format(::loc(msgId), room.getRoomName()))
        sceneChanged = true
        onRoomChanged()
        ::broadcastEvent("ChatRoomLeave", { room = room })
      }
    }
  }

  function silenceUsersByList(users)
  {
    if(!users || !users.len())
      return

    local resultFunc = ::Callback(
      function(contact) {
        if(!contact)
          return

        if(contact?.voiceStatus == voiceChatStats.talking)
          onEventCb(::GCHAT_EVENT_VOICE, null,
            { uid = contact.uid, type = "update", is_speaking = false })
      }, this)

   foreach(user in users)
     ::find_contact_by_name_and_do(user.name, resultFunc)
  }

  function removeUserFromRoom(roomData, nick)
  {
    if(!("users" in roomData))
      return
    foreach(idx, u in roomData.users)
      if (u.name == nick)
      {
        if (::g_chat.isRoomSquad(roomData.id))
          onSquadListMember(nick, false)
        else if("isOwner" in u && u.isOwner == true)
          ::gchat_list_names(::gchat_escape_target(roomData.id))
        roomData.users.remove(idx)
        if (curRoom == roomData)
          updateUsersList()
        break
      }
  }

  function addRoomMsg(roomId, from, msg, privateMsg = false, myPrivate = false, overlaySystemColor = null,
    important=false, isMyActionInfo = false)
  {
    local mBlock = menuChatRoom.newMessage(from, msg, privateMsg, myPrivate, overlaySystemColor,
      important, !::g_chat.isRoomSquad(roomId), isMyActionInfo)
    if (!mBlock)
      return

    updateContactsStatusByContacts([::getContact(mBlock.uid, mBlock.from, mBlock.clanTag)])

    if (::g_chat.rooms.len() == 0)
    {
      if (important) {
        delayedChatRoom.addMessage(mBlock)
        newMessagesGC()
      } else if (roomId=="") {
        emptyChatRoom.addMessage(mBlock)
        updateChatText()
      }
    } else {
      foreach(roomData in ::g_chat.rooms)
      {
        if ((roomId=="") || roomData.id == roomId)
        {
          roomData.addMessage(mBlock)

          if (!curRoom)
            continue

          if (roomData == curRoom || roomData.hidden)
            updateChatText()

          if (roomId != ""
              && (roomData.type.needCountAsImportant || mBlock.important)
              && !mBlock.isMeSender
              && !mBlock.isMyActionInfo
              && (!::last_chat_scene_show || curRoom != roomData)
             )
          {
            roomData.newImportantMessagesCount++
            newMessagesGC()

            if (roomData.type.needShowMessagePopup)
              showRoomPopup(mBlock, roomData.id)
          }
          else if (roomId == "" && mBlock.important
            && curRoom.type == ::g_chat_room_type.SYSTEM && !::last_chat_scene_show)
          {
            roomData.newImportantMessagesCount++
            newMessagesGC()
          }
        }
      }
    }

    if (privateMsg && roomId=="" && !::last_chat_scene_show)
      newMessagesGC()

    updateRoomsIcons()
  }

  function newMessagesGC()
  {
    ::update_gamercards()
  }

  function checkNewMessages()
  {
    if (delayedChatRoom && delayedChatRoom.mBlocks.len() > 0)
      return

    if (!::last_chat_scene_show || !curRoom)
      return

    curRoom.newImportantMessagesCount = 0

    ::update_gamercards()
  }

  function checkLastActionRoom()
  {
    if (lastActionRoom=="" || !::g_chat.getRoomById(lastActionRoom))
      lastActionRoom = ::getTblValue("id", curRoom, "")
  }

  function onMessage(db)
  {
    if (!db || !db.from)
      return

    if (skipMyMessages && db?.sender.nick == ::my_user_name)
      return

    if (db?.type == "xpost")
    {
      if ((db?.message.len() ?? 0) > 0)
        foreach (room in ::g_chat.rooms)
          if (room.id == db?.sender.name)
          {
            local idxLast = db.message.indexof(">")
            if ((db.message.slice(0,1)=="<") && (idxLast != null))
            {
              room.addMessage(menuChatRoom.newMessage(db.message.slice(1, idxLast), db.message.slice(idxLast+1), false, false, mpostColor))
            }
            else
              room.addMessage(menuChatRoom.newMessage("", db.message, false, false, xpostColor))

            if ( room == curRoom )
              updateChatText();
          }
    }
    else if (db?.type == "groupchat" || db?.type == "chat")
    {
      local roomId = ""
      local user = ""
      local userContact = null
      local clanTag = ""
      local privateMsg = false
      local myPrivate = false

      if (!db?.sender || db.sender?.debug)
        return

      local message = ::g_chat.localizeReceivedMessage(db?.message)
      if (::u.isEmpty(message))
        return

      if (!db?.sender.service)
      {
        clanTag = db?.tag ?? ""
        user = db.sender.nick
        if (db?.userId && db.userId != "0")
          userContact = getContact(db.userId, db.sender.nick, clanTag, true)
        else if (db.sender.nick != ::my_user_name)
          ::clanUserTable[db.sender.nick] <- clanTag
        roomId = db?.sender.name
        privateMsg = (db.type == "chat") || !roomRegexp.match(roomId)
        local isSystemMessage = ::g_chat.isSystemUserName(user)

        if (!isSystemMessage && !isCrossNetworkMessageAllowed(user))
          return

        if (privateMsg)  //private message
        {
          if (::isUserBlockedByPrivateSetting(db.userId, user) ||
              !isChatEnableWithPlayer(user))
            return

          if (db.type == "chat")
            roomId = db.sender.nick
          myPrivate = db.sender.nick == ::my_user_name
          if ( myPrivate )
          {
            user = db.sender.name
            userContact = null
          }

          local haveRoom = false;
          foreach (room in ::g_chat.rooms)
            if (room.id == roomId)
            {
              haveRoom = true;
              break;
            }
          if (!haveRoom)
          {
            if (::isPlayerNickInContacts(user, ::EPL_BLOCKLIST))
              return
            addRoom(roomId)
            updateRoomsList()
          }
        }

        // System message
        if (isSystemMessage)
        {
          local nameLen = ::my_user_name.len()
          if (message.len() >= nameLen && message.slice(0, nameLen) == ::my_user_name)
            ::sync_handler_simulate_signal("profile_reload")
        }
      }
      addRoomMsg(
        roomId,
        userContact || user,
        message,
        privateMsg,
        myPrivate
      )
    }
    else if (db?.type == "error")
    {
      if (db?.error == null)
        return

      checkLastActionRoom()
      local errorName = db.error?.errorName
      local roomId = lastActionRoom
      local senderFrom = db?.sender.from
      if (db?.error.param1)
        roomId = db.error.param1
      else if (senderFrom && roomRegexp.match(senderFrom))
        roomId = senderFrom

      if (errorName == chatErrorName.NO_SUCH_NICK_CHANNEL)
      {
        local userName = roomId
        if (!roomRegexp.match(userName)) //private room
        {
          addRoomMsg(lastActionRoom, "",
                     format(::loc("chat/error/401/userNotConnected"),
                            ::gchat_unescape_target(getPlayerName(userName)) ))
          return
        }
      }
      else if (errorName == chatErrorName.CANNOT_JOIN_THE_CHANNEL && roomId.len() > 1)
      {
        if (::g_chat.isRoomSquad(roomId))
        {
          ::g_popups.add(null, ::loc("squad/join_chat_failed"), null, null, null, "squad_chat_failed")
          return
        }

        local wasPasswordEntered = ::getTblValue(roomId, roomJoinParamsTable, "") != ""
        local locId = wasPasswordEntered ? "chat/wrongPassword" : "chat/enterPassword"
        local params = {
          title = roomId.slice(1)
          editboxHeaderText = ::format(::loc(locId), roomId.slice(1))
          allowEmpty = false
          okFunc = ::Callback(@(pass) joinRoom(roomId, pass), ::menu_chat_handler)
        }

        ::gui_modal_editbox_wnd(params)
        return
      }

      local roomType = ::g_chat_room_type.getRoomType(roomId)
      if (::isInArray(errorName, [chatErrorName.NO_SUCH_CHANNEL, chatErrorName.NO_SUCH_NICK_CHANNEL]))
      {
        if (roomId == ::g_chat.getMySquadRoomId())
        {
          leaveSquadRoom()
          return
        }
        if (roomType == ::g_chat_room_type.THREAD)
        {
          local threadInfo = ::g_chat.getThreadInfo(roomId)
          if (threadInfo)
            threadInfo.invalidate()
        }
      }

      //remap roomnames in params
      local locParams = {}
      local errParamCount = db.error?.errorParamCount || db.error.getInt("paramCount", 0) //"paramCount" is a support old client
      for(local i = 0; i < errParamCount; i++)
      {
        local key = "param" + i
        local value = db.error?[key]
        if (!value)
          continue

        if (roomRegexp.match(value))
          value = roomType.getRoomName(value)
        else if (i == 0 && errorName == chatErrorName.CANNOT_JOIN_CHANNEL_NO_INVITATION)
          value = getPlayerName(value)

        locParams[key] <- value
      }

      local errMsg = ::loc("chat/error/" + errorName, locParams)
      local roomToSend = roomId
      if (!::g_chat.getRoomById(roomToSend))
        roomToSend = lastActionRoom
      addRoomMsg(roomToSend, "", errMsg)
      if (roomId != roomToSend)
        addRoomMsg(roomId, "", errMsg)
      if (roomType.isErrorPopupAllowed)
        showRoomPopup(menuChatRoom.newMessage("", errMsg), roomId)
    }
    else
      ::dagor.debug("Chat error: Received message of unknown type = " + (db?.type ?? "null"))
  }

  function joinRoom(id, password = "", onJoinFunc = null, customScene = null, ownerHandler = null, reconnect = false)
  {
    local roomData = ::g_chat.getRoomById(id)
    if (roomData && id == ::g_chat.getMySquadRoomId())
      roomData.canBeClosed = false

    if (roomData && roomData.joinParams != "")
      return ::gchat_raw_command("join " + ::gchat_escape_target(id) + " " + roomData.joinParams)

    if (roomData && reconnect && roomData.joined) //reconnect only to joined rooms
      return

    addChatJoinParams(::gchat_escape_target(id), password)
    if (customScene && !roomData)
      addRoom(id, customScene, ownerHandler) //for correct reconnect

    local task = ::gchat_join_room(::gchat_escape_target(id), password) //FIX ME: better to remove this and work via gchat_raw_command always
    if (task != "")
      chatTasks.append({ task = task, handler = onJoinRoom, roomId = id,
                         onJoinFunc = onJoinFunc, customScene = customScene,
                         ownerHandler = ownerHandler
                       })
  }

  function onJoinRoom(event, db, taskConfig)
  {
    if (event != ::GCHAT_EVENT_TASK_ERROR && db?.type != "error")
    {
      local needNewRoom = true
      foreach(room in ::g_chat.rooms)
        if (taskConfig.roomId == room.id)
        {
          if (!room.joined)
          {
            local msgId = ::g_chat.isRoomSquad(taskConfig.roomId)? "squad/joinChannel" : "chat/joinChannel"
            addRoomMsg(room.id, "", format(::loc(msgId), room.getRoomName()))
          }
          room.joined = true
          needNewRoom = false
        }

      if (needNewRoom)
        addRoom(taskConfig.roomId, taskConfig.customScene, taskConfig.ownerHandler, true)

      if (("onJoinFunc" in taskConfig) && taskConfig.onJoinFunc)
        taskConfig.onJoinFunc.call(this)
    }
  }

  function addRoom(id, customScene = null, ownerHandler = null, selectRoom = false)
  {
    local r = menuChatRoom.newRoom(id, customScene, ownerHandler)
    r.joinParams = roomJoinParamsTable?[::gchat_escape_target(id)] ??  ""

    if (r.type != ::g_chat_room_type.PRIVATE)
      guiScene.playSound("chat_join")
    ::g_chat.addRoom(r)

    if (unhiddenRoomsCount() == 1)
    {
      if (isChatEnabled())
        addRoomMsg(id, "", ::loc("menuchat/hello"))
    }
    if (selectRoom || r.type.needSwitchRoomOnJoin)
      switchCurRoom(r, false)

    if (r.type == ::g_chat_room_type.SQUAD && isChatEnabled())
      addRoomMsg(id, "", ::loc("squad/channelIntro"))

    if (delayedChatRoom && delayedChatRoom.mBlocks.len() > 0)
    {
      for(local i = 0; i < delayedChatRoom.mBlocks.len(); i++) {
        r.mBlocks.append(delayedChatRoom.mBlocks[i])
      }

      delayedChatRoom.clear()
      updateChatText()
      checkNewMessages()
    }
    if (!r.hidden)
      saveJoinedRooms()
    if (chatStatesCanUseVoice() && r.type.canVoiceChat)
    {
      shouldCheckVoiceChatSuggestion = true
      if (::handlersManager.findHandlerClassInScene(::gui_handlers.MainMenu) != null)
        checkVoiceChatSuggestion()
    }
    return r
  }

  function checkVoiceChatSuggestion()
  {
    if (!shouldCheckVoiceChatSuggestion || !::g_login.isProfileReceived())
      return
    shouldCheckVoiceChatSuggestion = false

    local VCdata = get_option(::USEROPT_VOICE_CHAT)
    local voiceChatShowCount = ::load_local_account_settings(VOICE_CHAT_SHOW_COUNT_SAVE_ID, 0)
    if(isFirstAskForSession && voiceChatShowCount < ::g_chat.MAX_MSG_VC_SHOW_TIMES && !VCdata.value)
    {
      msgBox("join_voiceChat", ::loc("msg/enableVoiceChat"),
              [
                ["yes", function(){::set_option(::USEROPT_VOICE_CHAT, true)}],
                ["no", function(){} ]
              ], "no",
              { cancel_fn = function(){}})
      ::save_local_account_settings(VOICE_CHAT_SHOW_COUNT_SAVE_ID, voiceChatShowCount + 1)
    }
    isFirstAskForSession = false
  }

  function onEventClanInfoUpdate(p)
  {
    local haveChanges = false
    foreach(room in ::g_chat.rooms)
      if (::g_chat.isRoomClan(room.id)
          && (room.canBeClosed != (room.id != ::g_chat.getMyClanRoomId())))
      {
        haveChanges = true
        room.canBeClosed = !room.canBeClosed
      }
    if (haveChanges)
      updateRoomsList()
  }

  function unhiddenRoomsCount()
  {
    local count = 0
    foreach(room in ::g_chat.rooms)
      if (!room.hidden && !room.concealed())
        count++
    return count
  }

  function onRoomClose(obj)
  {
    if (!obj) return
    local id = obj?.id
    if (!id || id.len() < 7 || id.slice(0, 6) != "close_")
      return

    local value = id.slice(6).tointeger()
    closeRoom(value)
  }

  function onRemoveRoom(obj)
  {
    closeRoom(obj.getValue(), true)
  }

  function closeRoom(roomIdx, askAllRooms = false)
  {
    if (!(roomIdx in ::g_chat.rooms))
      return
    local roomData = ::g_chat.rooms[roomIdx]
    if (!roomData.canBeClosed)
      return

    if (askAllRooms)
    {
      local msg = format(::loc("chat/ask/leaveRoom"), roomData.getRoomName())
      msgBox("leave_squad", msg,
        [
          ["yes", (@(roomIdx) function() { closeRoom(roomIdx) })(roomIdx)],
          ["no", function() {} ]
        ], "yes",
        { cancel_fn = function() {} })
      return
    }

    if (roomData.id.slice(0, 1) == "#" && roomData.joined)
      ::gchat_raw_command("part " + ::gchat_escape_target(roomData.id))

    ::g_chat.rooms.remove(roomIdx)
    saveJoinedRooms()
    ::broadcastEvent("ChatRoomLeave", { room = roomData })
    guiScene.performDelayed(this, function() {
      updateRoomsList()
    })
  }

  function closeRoomById(id)
  {
    local idx = getRoomIdxById(id)
    if (idx >= 0)
      closeRoom(idx)
  }

  function onUsersListActivate(obj)
  {
    local value = obj.getValue()
    if (value < 0 || value > obj.childrenCount())
      return

    if (!curRoom || curRoom.users.len() <= value || !checkScene())
      return

    local playerName = curRoom.users[value].name
    local roomId = curRoom.id
    local position = obj.getChild(value).getPosRC()
    ::find_contact_by_name_and_do(playerName,
      @(contact) ::g_chat.showPlayerRClickMenu(playerName, roomId, contact, position))
  }

  function onChatCancel(obj)
  {
    if (isCustomRoomActionObj(obj))
    {
      local customRoom = findCustomRoomByObj(obj)
      if (customRoom && customRoom.ownerHandler && ("onCustomChatCancel" in customRoom.ownerHandler))
        customRoom.ownerHandler.onCustomChatCancel.call(customRoom.ownerHandler)
    }
    else
      goBack()
  }

  function onChatEntered(obj)
  {
    chatSendAction(obj, false)
  }

  function checkCmd(msg)
  {
    if (msg.slice(0, 1)=="\\" || msg.slice(0, 1)=="/")
      foreach(cmd in ::available_cmd_list)
        if ((msg.len() > (cmd.len()+2) && msg.slice(1, cmd.len()+2) == (cmd + " "))
            || (msg.len() == (cmd.len()+1) && msg.slice(1, cmd.len()+1) == cmd))
        {
          local hasParam = msg.len() > cmd.len()+2;

          if (cmd == "help" || cmd == "shelp")
            addRoomMsg(curRoom.id, "", ::loc("menuchat/" + cmd))
          else if (cmd == "edit")
            ::g_chat.openModifyThreadWndByRoomId(curRoom.id)
          else if (cmd == "msg")
            return hasParam ? msg.slice(0,1) + msg.slice(cmd.len()+2) : null
          else if (cmd == "p_check")
          {
            if (!hasParam)
            {
              addRoomMsg(curRoom.id, "", ::loc("chat/presenceCheckArg"));
              return null;
            }

            if ( !::is_myself_anyof_moderators() )
            {
              addRoomMsg(curRoom.id, "", ::loc("chat/presenceCheckDenied"));
              return null;
            }

            onPresenceDetectionCheckIn(::to_integer_safe(msg.slice(cmd.len()+2), -1))
            return null;
          }
          else if (cmd == "join" || cmd == "part")
          {
            if (cmd == "join")
            {
              if (!hasParam)
              {
                addRoomMsg(curRoom.id, "", ::loc("chat/error/461"));
                return null;
              }

              local paramStr = msg.slice(cmd.len()+2)
              local spaceidx = paramStr.indexof(" ")
              local roomName = spaceidx ? paramStr.slice(0,spaceidx) : paramStr
              if (roomName.slice(0, 1) != "#")
                roomName = "#" + roomName
              local pass = spaceidx ? paramStr.slice(spaceidx+1) : ""

              addChatJoinParams(::gchat_escape_target(roomName), pass)
            }
            if (msg.len() > cmd.len()+2)
              if (msg.slice(cmd.len()+2, cmd.len()+3)!="#")
                ::gchat_raw_command(msg.slice(1, cmd.len()+2) + "#" + ::gchat_escape_target(msg.slice(cmd.len()+2)))
              else
                ::gchat_raw_command(msg.slice(1))
            return null
          }
          else if (cmd == "invite")
          {
            if (curRoom)
            {
              if (curRoom.id == ::g_chat.getMySquadRoomId())
              {
                if (!hasParam)
                {
                  addRoomMsg(curRoom.id, "", ::loc("chat/error/461"));
                  return null;
                }

                inviteToSquadRoom(msg.slice(cmd.len()+2))
              }
              else
                ::gchat_raw_command(msg.slice(1) + " " + ::gchat_escape_target(curRoom.id))
            } else
              addRoomMsg(curRoom.id, "", ::loc(::g_chat.CHAT_ERROR_NO_CHANNEL))
          }
          else if (cmd == "mode" || cmd == "xpost" || cmd == "mpost")
            gchatRawCmdWithCurRoom(msg, cmd)
          else if (cmd == "squad_invite" || cmd == "sinvite")
          {
            if (!hasParam)
            {
              addRoomMsg(curRoom.id, "", ::loc("chat/error/461"));
              return null;
            }

            inviteToSquadRoom(msg.slice(cmd.len()+2))
          }
          else if (cmd == "squad_remove" || cmd == "sremove" || cmd == "kick")
          {
            if (!hasParam)
            {
              addRoomMsg(curRoom.id, "", ::loc("chat/error/461"));
              return null;
            }

            local playerName = msg.slice(cmd.len()+2)
            if (cmd == "kick")
              kickPlayeFromRoom(playerName)
            else
              ::g_squad_manager.dismissFromSquadByName(playerName)
          }
          else if (cmd == "squad_ready" || cmd == "sready")
            ::g_squad_manager.setReadyFlag()
          else
            ::gchat_raw_command(msg.slice(1))
          return null
        }
    return msg
  }

  function gchatRawCmdWithCurRoom(msg, cmd)
  {
    if (!curRoom)
      addRoomMsg("", "", ::loc(::g_chat.CHAT_ERROR_NO_CHANNEL))
    else
    if (::g_chat.isSystemChatRoom(curRoom.id))
      addRoomMsg(curRoom.id, "", ::loc("chat/cantWriteInSystem"))
    else
    {
      if (msg.len() > cmd.len()+2)
        ::gchat_raw_command(msg.slice(1, cmd.len()+2) + ::gchat_escape_target(curRoom.id) + " " + msg.slice(cmd.len()+2))
      else
        ::gchat_raw_command(msg.slice(1) + " " + ::gchat_escape_target(curRoom.id))
    }
  }

  function kickPlayeFromRoom(playerName)
  {
    if (!curRoom || ::g_chat.isSystemChatRoom(curRoom.id))
      return addRoomMsg(curRoom || "", "", ::loc(::g_chat.CHAT_ERROR_NO_CHANNEL))
    if (curRoom.id == ::g_chat.getMySquadRoomId())
      return ::g_squad_manager.dismissFromSquadByName(playerName)

    ::gchat_raw_command("kick " + ::gchat_escape_target(curRoom.id) + " " + ::gchat_escape_target(playerName))
  }

  function squadMsg(msg, isMyActionInfo = false)
  {
    local sRoom = ::g_chat.getMySquadRoomId()
    addRoomMsg(sRoom, "", msg, false, false, null, false, isMyActionInfo)
    if (curRoom && curRoom.id != sRoom)
      addRoomMsg(curRoom.id, "", msg, false, false, null, false, isMyActionInfo)
  }

  function leaveSquadRoom()
  {
    //squad room can be only one joined at once, but at moment we want to leave it cur squad room id can be missed.
    foreach(room in ::g_chat.rooms)
    {
      if (room.type != ::g_chat_room_type.SQUAD || !room.joined)
        continue

      ::gchat_raw_command("part " + ::gchat_escape_target(room.id))
      room.joined = false //becoase can be disconnected from chat, but this info is still important.
      room.canBeClosed = true
      silenceUsersByList(room.users)
      room.users.clear()
      updateRoomTabById(room.id)

      if(curRoom == room)
        updateUsersList()
    }
  }

  function isInSquadRoom()
  {
    local roomName = ::g_chat.getMySquadRoomId()
    foreach(room in ::g_chat.rooms)
      if (room.id == roomName)
        return room.joined
    return false
  }

  function inviteToSquadRoom(playerName, delayed=false)
  {
    if (!::gchat_is_connected())
      return false

    if (!::has_feature("Squad"))
    {
      addRoomMsg(curRoom.id, "", ::loc("msgbox/notAvailbleYet"))
      return false
    }

    if (!::g_squad_manager.isInSquad())
      return false

    if (!playerName)
      return false

    if (!::g_squad_manager.isSquadLeader())
    {
      addRoomMsg(curRoom.id, "", ::loc("squad/only_leader_can_invite"))
      return false
    }

    if (!isInSquadRoom())
      return false

    if (delayed)
    {
      local dcmd = "xinvite " + ::gchat_escape_target(playerName) + " " + ::gchat_escape_target(::g_chat.getMySquadRoomId())
      dagor.debug(dcmd)
      ::gchat_raw_command(dcmd)
    }

    ::gchat_raw_command("invite " + ::gchat_escape_target(playerName) + " " + ::gchat_escape_target(::g_chat.getMySquadRoomId()))
    return true
  }

  function onSquadListMember(name, join)
  {
    if (!::g_squad_manager.isInSquad())
      return

    addRoomMsg(::g_chat.getMySquadRoomId(),
      "",
      ::format(::loc(join? "squad/player_join" : "squad/player_leave"),
          getPlayerName(name)
    ))
  }

  function squadReady()
  {
    if (::g_squad_manager.canSwitchReadyness())
      ::g_squad_manager.setReadyFlag()
  }

  function onEventSquadSetReady(params)
  {
    updateReadyButton()
    if (::g_squad_manager.isInSquad())
      squadMsg(::loc(::g_squad_manager.isMeReady() ? "squad/change_to_ready" : "squad/change_to_not_ready"), true)
  }

  function onEventQueueChangeState(params)
  {
    updateReadyButton()
  }

  function onEventSquadPlayerInvited(params)
  {
    if (!::g_squad_manager.isSquadLeader())
      return

    local uid = ::getTblValue("uid", params, "")
    if (::u.isEmpty(uid))
      return

    local contact = ::getContact(uid)
    if (contact != null)
       squadMsg(format(::loc("squad/invited_player"), contact.name), ::g_squad_manager.isSquadLeader())
  }

  function checkValidAndSpamMessage(msg, room = null, isPrivate = false)
  {
    if (::is_chat_message_empty(msg))
      return false
    if (isPrivate || ::is_myself_anyof_moderators())
      return true
    if (::is_chat_message_allowed(msg))
      return true
    addRoomMsg(room? room : curRoom.id, "", ::loc("charServer/ban/reason/SPAM"))

    return false
  }

  function checkAndPrintDevoiceMsg(roomId = null)
  {
    if (!roomId)
      roomId = curRoom.id

    local devoice = penalties.getDevoiceMessage()
    if (devoice)
      addRoomMsg(roomId, "", devoice)
    return devoice != null
  }

  function onChatEdit(obj)
  {
    local sceneData = getSceneDataByActionObj(obj)
    if (!sceneData)
      return
    local roomData = ::g_chat.getRoomById(sceneData.room)
    if (roomData)
      roomData.lastTextInput = obj.getValue()
  }

  function onChatSend(obj)
  {
    chatSendAction(obj, true)
  }

  function chatSendAction(obj, isFromButton = false)
  {
    local sceneData = getSceneDataByActionObj(obj)
    if (!sceneData)
      return

    if (sceneData.room=="")
      return

    lastActionRoom = sceneData.room
    local inputObj = sceneData.scene.findObject("menuchat_input")
    local value = ::checkObj(inputObj)? inputObj.getValue() : ""
    if (value == "")
    {
      local roomData = findCustomRoomByObj(obj)
      if (!isFromButton && roomData && roomData.ownerHandler && ("onCustomChatContinue" in roomData.ownerHandler))
        roomData.ownerHandler.onCustomChatContinue.call(roomData.ownerHandler)
      return
    }

    inputObj.setValue("")
    sendMessageToRoom(value, sceneData.room)
  }

  function sendMessageToRoom(msg, roomId)
  {
    ::last_send_messages.append(msg)
    if (::last_send_messages.len() > ::g_chat.MAX_LAST_SEND_MESSAGES)
      ::last_send_messages.remove(0)
    lastSendIdx = -1

    if (!::g_chat.checkChatConnected())
      return

    msg = checkCmd(msg)
    if (!msg)
      return

    if (checkAndPrintDevoiceMsg(roomId))
      return

    msg = ::g_chat.validateChatMessage(msg)

    local privateData = getPrivateData(msg, roomId)
    if (privateData)
      onChatPrivate(privateData)
    else
    {
      if (checkValidAndSpamMessage(msg, roomId))
      {
        if (::g_chat.isSystemChatRoom(roomId))
          addRoomMsg(roomId, "", ::loc("chat/cantWriteInSystem"))
        else {
          skipMyMessages = !needLocalEcho
          ::gchat_chat_message(::gchat_escape_target(roomId), msg)
          skipMyMessages = false
          guiScene.playSound("chat_send")
        }
      }
    }
  }

  function getPrivateData(msg, roomId = null)
  {
    if (msg.slice(0, 1)=="\\" || msg.slice(0, 1)=="/")
    {
      msg = msg.slice(1)
      local res = { user = "", msg = "" }
      local start = msg.indexof(" ") ?? -1
      if (start < 1)
        res.user = msg
      else
      {
        res.user = msg.slice(0, start)
        res.msg = msg.slice(start+1)
      }
      return res
    }
    if (!roomId && curRoom)
      roomId = curRoom.id
    if (roomId && ::g_chat_room_type.PRIVATE.checkRoomId(roomId))
      return { user = roomId, msg = msg }
    return null
  }

  function onChatPrivate(data)
  {
    if (!checkValidAndSpamMessage(data.msg, null, true))
      return
    if (!curRoom)
      return

    if (!::gchat_chat_private_message(::gchat_escape_target(curRoom.id), ::gchat_escape_target(data.user), data.msg))
      return

    if (needLocalEcho)
      addRoomMsg(curRoom.id, ::my_user_name, data.msg, true, true)

    local blocked = ::isPlayerNickInContacts(data.user, ::EPL_BLOCKLIST)
    if (blocked)
      addRoomMsg(curRoom.id, "", format(::loc("chat/cantChatWithBlocked"), "<Link="+::g_chat.generatePlayerLink(data.user)+">"+data.user+"</Link>"))
    else if (data.user != curRoom.id)
    {
      local userRoom = ::g_chat.getRoomById(data.user)
      if (!userRoom)
      {
        addRoom(data.user)
        updateRoomsList()
      }
      if (needLocalEcho)
        addRoomMsg(data.user, ::my_user_name, data.msg, true, true)
    }
  }

  function showLastSendMsg(showScene = null)
  {
    if (!::checkObj(showScene))
      return
    local obj = showScene.findObject("menuchat_input")
    if (!::checkObj(obj))
      return

    obj.setValue((lastSendIdx in ::last_send_messages)? ::last_send_messages[lastSendIdx] : "")
  }

  function openInviteMenu(menu, position)
  {
    if(menu.len() > 0)
      ::gui_right_click_menu(menu, this, position)
  }

  function hasPrefix(roomId, prefix)
  {
    return roomId.len() >= prefix.len() && roomId.slice(0, prefix.len()) == prefix
  }

  function switchLastSendMsg(inc, obj)
  {
    if (::last_send_messages.len()==0)
      return

    local selObj = guiScene.getSelectedObject()
    if (!::check_obj(selObj) || selObj?.id != "menuchat_input")
      return
    local sceneData = getSceneDataByActionObj(selObj)
    if (!sceneData)
      return

    lastSendIdx += inc
    if (lastSendIdx < -1)
      lastSendIdx = ::last_send_messages.len()-1
    if (lastSendIdx >= ::last_send_messages.len())
      lastSendIdx = -1
    showLastSendMsg(sceneData.scene)
  }

  function onPrevMsg(obj)
  {
    switchLastSendMsg(-1, obj)
  }

  function onNextMsg(obj)
  {
    switchLastSendMsg(-1, obj)
  }

  function onShowPlayersList()
  {
    showPlayersList = !showPlayersList
    updateUsersList()
  }

  function onChatLinkClick(obj, itype, link)  { onChatLink(obj, link, !::show_console_buttons) }
  function onChatLinkRClick(obj, itype, link) { onChatLink(obj, link, false) }

  function onChatLink(obj, link, lclick)
  {
    local sceneData = getSceneDataByActionObj(obj)
    if (!sceneData)
      return

    if (link && link.len() < 4)
      return

    if(link.slice(0, 2) == "PL")
    {
      local name = ""
      local contact = null
      if(link.slice(0, 4) == "PLU_")
      {
        contact = getContact(link.slice(4))
        name = contact.name
      }
      else
      {
        name = link.slice(3)
        contact = ::Contact.getByName(name)
      }
      if (lclick)
        addNickToEdit(name, sceneData.scene)
      else
        ::g_chat.showPlayerRClickMenu(name, sceneData.room, contact)
    }
    else if (::g_chat.checkBlockedLink(link))
    {
      local roomData = ::g_chat.getRoomById(sceneData.room)
      if (!roomData)
        return

      local childIndex = obj.childIndex.tointeger()
      roomData.mBlocks[childIndex].text = ::g_chat.revealBlockedMsg(roomData.mBlocks[childIndex].text, link)
      obj.setValue(roomData.mBlocks[childIndex].text)
      updateChatText()
    }
    else
      ::g_invites.acceptInviteByLink(link)
  }

  function onUserListClick(obj)  { onUserList(obj, !::show_console_buttons) }
  function onUserListRClick(obj) { onUserList(obj, false) }

  function onUserList(obj, lclick)
  {
    if (!obj?.id || obj.id.len() <= 10 || obj.id.slice(0,10) != "user_name_")
      return

    local num = obj.id.slice(10).tointeger()
    local name = obj.text
    if (curRoom && checkScene())
      if(curRoom.users.len() > num)
        {
          name = curRoom.users[num].name
          scene.findObject("users_list").setValue(num)
        }

    local sceneData = getSceneDataByActionObj(obj)
    if (!sceneData)
      return
    if (lclick)
      addNickToEdit(name, sceneData.scene)
    else
      ::g_chat.showPlayerRClickMenu(name, sceneData.room)
  }

  function changePrivateTo(user)
  {
    if (!::g_chat.checkChatConnected())
      return
    if (!checkScene())
      return

    if (user!=curRoom.id)
    {
      local userRoom = ::g_chat.getRoomById(user)
      if (!userRoom)
        addRoom(user)
      switchCurRoom(user)
    }
    ::broadcastEvent("ChatOpenPrivateRoom", { room = user })
  }

  function addNickToEdit(user, showScene = null)
  {
    if (!showScene)
    {
      if (!checkScene())
        return
      showScene = scene
    }

    local inputObj = showScene.findObject("menuchat_input")
    if (!::checkObj(inputObj))
      return

    ::add_text_to_editbox(inputObj, getPlayerName(user) + " ")
    selectEditbox(inputObj)
  }

  function onShowSearchList()
  {
    showSearch(null, true)
  }

  function showSearch(show=null, selectSearchEditbox = false)
  {
    if (!checkScene())
      return

    local sObj = scene.findObject("searchDiv")
    local wasVisible = sObj.isVisible()
    if (show==null)
      show = !wasVisible

    if (!show && wasVisible)
      loadSizes()

    sObj.show(show)
    if (show)
    {
      setSavedSizes()
      if (!searchInited)
        fillSearchList()
      showSceneBtn("btn_join_room", !::show_console_buttons)
      if (selectSearchEditbox)
        selectEditbox(scene.findObject("search_edit"))
    }
  }

  function validateSearchList()
  {
    if (!searchRoomList)
      return

    for(local i = searchRoomList.len() - 1; i >= 0; i--)
      if (!::g_chat_room_type.getRoomType(searchRoomList[i]).isVisibleInSearch())
        searchRoomList.remove(i)
  }

  function resetSearchList()
  {
    if (::g_chat_room_type.GLOBAL.isVisibleInSearch())
      searchRoomList = ::getGlobalRoomsList()
    else
      searchRoomList = []
    searchShowNotFound = false
    defaultRoomsInSearch = true
  }

  function fillSearchList()
  {
    if (!checkScene())
      return

    if (!searchRoomList)
      resetSearchList()

    showSceneBtn("btn_mainChannels", !defaultRoomsInSearch && ::g_chat_room_type.GLOBAL.isVisibleInSearch())

    local listObj = scene.findObject("searchList")
    if (!::checkObj(listObj))
      return

    guiScene.setUpdatesEnabled(false, false)
    local data = ""
    local total = ::min(searchRoomList.len(), ::g_chat.MAX_ROOMS_IN_SEARCH)
    if (searchRoomList.len() > 0)
    {
      for(local i = 0; i < total; i++)
      {
        local rName = searchRoomList[i]
        rName = (rName.slice(0, 1)=="#")? rName.slice(1) : ::loc("chat/channel/" + rName, rName)
        data += ::format("text { id:t='search_room_txt_%d'; text:t='%s'; tooltip:t='%s'; }",
                    i, ::g_string.stripTags(rName), ::g_string.stripTags(rName))
      }
    }
    else
    {
      if (searchInProgress)
        data = "animated_wait_icon { pos:t='0.5(pw-w),0.03sh'; position:t='absolute'; background-rotation:t='0' }"
      else if (searchShowNotFound)
        data = "textAreaCentered { text:t='#contacts/searchNotFound'; enable:t='no' }"
      searchShowNotFound = true
    }

    guiScene.replaceContentFromText(listObj, data, data.len(), this)
    guiScene.setUpdatesEnabled(true, true)

    searchInited = true
  }

  last_search_time = -10000000
  function onSearchStart()
  {
    if (!checkScene())
      return

    if (!::ps4_is_ugc_enabled())
    {
      ::ps4_show_ugc_restriction()
      return
    }

    if (searchInProgress && (::dagor.getCurTime() - last_search_time < 5000))
      return

    local sObj = scene.findObject("search_edit")
    local value = sObj.getValue()
    if (!value || ::is_chat_message_empty(value))
      return

    value = "#" + clearBorderSymbols(value, [" ", "*"]) + "*"
    searchInProgress = true
    defaultRoomsInSearch = false
    searchRoomList = []
    ::gchat_list_rooms(::gchat_escape_target(value))
    fillSearchList()

    last_search_time = ::dagor.getCurTime()
  }

  function closeSearch()
  {
    if (::g_chat.isSystemChatRoom(curRoom.id))
      goBack()
    else if (checkScene())
    {
      scene.findObject("searchDiv").show(false)
      selectChatInputEditbox()
    }
  }

  function onCancelSearchEdit(obj)
  {
    if (!::checkObj(obj))
      return

    if (obj.getValue()=="" && defaultRoomsInSearch)
      closeSearch()
    else
    {
      onMainChannels()
      obj.setValue("")
    }

    searchShowNotFound = false
  }

  function onCancelSearchRooms(obj)
  {
    if (!checkScene())
      return

    if (defaultRoomsInSearch)
      return closeSearch()

    local searchObj = scene.findObject("search_edit")
    selectEditbox(searchObj)
    onMainChannels()
  }

  function onSearchRoomJoin(obj)
  {
    if (!checkScene())
      return

    if (!::checkObj(obj))
      obj = scene.findObject("searchList")

    local value = obj.getValue()
    if (value in searchRoomList)
    {
      if (!isChatEnabled(true))
        return
      if (!::isInArray(searchRoomList[value], ::global_chat_rooms_list) && !::ps4_is_ugc_enabled())
      {
        ::ps4_show_ugc_restriction()
        return
      }

      selectChatInputEditbox()
      local rName = (searchRoomList[value].slice(0,1)!="#")? "#"+searchRoomList[value] : searchRoomList[value]
      local room = ::g_chat.getRoomById(rName)
      if (room)
        switchCurRoom(room)
      else
      {
        changeRoomOnJoin = rName
        joinRoom(changeRoomOnJoin)
      }
    }
  }

  function onMainChannels()
  {
    if (checkScene() && !defaultRoomsInSearch)
      guiScene.performDelayed(this, function()
      {
        if (!defaultRoomsInSearch)
        {
          resetSearchList()
          fillSearchList()
        }
      })
  }

  function isMenuChatActive()
  {
    return checkScene() && ::last_chat_scene_show;
  }

  function addChatJoinParams(roomName, pass)
  {
    roomJoinParamsTable[roomName] <- pass
  }

  function showRoomPopup(msgBlock, roomId)
  {
    if (::get_gui_option_in_mode(::USEROPT_SHOW_SOCIAL_NOTIFICATIONS, ::OPTIONS_MODE_GAMEPLAY))
      ::g_popups.add(msgBlock.fullName && msgBlock.fullName.len()? (msgBlock.fullName + ":") : null,
        msgBlock.msgs.top(),
        @() ::g_chat.openChatRoom(roomId)
      )
  }

  function popupAcceptInvite(roomId)
  {
    if (::g_chat_room_type.THREAD.checkRoomId(roomId))
    {
      ::g_chat.joinThread(roomId)
      changeRoomOnJoin = roomId
      return
    }

    openChatRoom(curRoom.id)
    joinRoom(roomId)
    changeRoomOnJoin = roomId
  }

  function openChatRoom(roomId)
  {
    local curScene = getLastGamercardScene()

    switchMenuChatObj(getChatDiv(curScene))
    chatSceneShow(true)

    local roomList = scene.findObject("rooms_list")
    foreach (idx, room in ::g_chat.rooms)
      if (room.id == roomId)
      {
        roomList.setValue(idx)
        break
      }
    onRoomChanged()
  }

  function onEventPlayerPenaltyStatusChanged(params)
  {
    checkAndPrintDevoiceMsg()
  }

  function onEventNewSceneLoaded(p)
  {
    guiScene.performDelayed(this, function() //need delay becoase of in the next scene can be obj for this chat room too (mpLobby)
    {
      updateCustomChatTexts()
    })
  }

  function updateCustomChatTexts()
  {
    for(local idx = ::g_chat.rooms.len()-1; idx>=0; idx--)
    {
      local room = ::g_chat.rooms[idx]
      if (::checkObj(room.customScene))
      {
        local obj = room.customScene.findObject("custom_chat_text_block")
        if (::checkObj(obj))
          drawRoomTo(room, obj)
      }
      else if (room.existOnlyInCustom)
        closeRoom(idx)
    }
  }

  function isCustomRoomActionObj(obj)
  {
    return (obj?._customRoomId ?? "") != ""
  }

  function findCustomRoomByObj(obj)
  {
    local id = obj?._customRoomId ?? ""
    if (id != "")
      return ::g_chat.getRoomById(id)

    //try to find by scene
    foreach(item in ::g_chat.rooms)
      if (::checkObj(item.customScene) && item.customScene.isEqual(obj))
        return item
    return null
  }

  function getSceneDataByActionObj(obj)
  {
    if (isCustomRoomActionObj(obj))
    {
      local customRoom = findCustomRoomByObj(obj)
      if (!customRoom || !::checkObj(customRoom.customScene))
        return null

      return { room = customRoom.id, scene = customRoom.customScene }
    } else if (checkScene())
      return { room = curRoom.id, scene = scene }

    return null
  }

  function joinCustomObjRoom(sceneObj, roomId, password, ownerHandler)
  {
    local prevRoom = findCustomRoomByObj(sceneObj)
    if (prevRoom)
      if (prevRoom.id == roomId)
        return
      else
        closeRoomById(prevRoom.id)

    local objGuiScene = sceneObj.getScene()
    objGuiScene.replaceContent(sceneObj, "gui/chat/customChat.blk", this)
    foreach(name in ["menuchat_input", "btn_send", "btn_prevMsg", "btn_nextMsg"])
    {
      local obj = sceneObj.findObject(name)
      obj._customRoomId = roomId
    }

    menuChatRoom.initChatMessageListOn(sceneObj.findObject("custom_chat_text_block"), this, roomId)

    local room = ::g_chat.getRoomById(roomId)
    if (room)
    {
      room.customScene = sceneObj
      room.ownerHandler = ownerHandler
      room.joined = true
      afterReconnectCustomRoom(roomId)
      updateChatText()
    }

    joinRoom(roomId, password,
      function() {
        afterReconnectCustomRoom(roomId)
      },
      sceneObj, ownerHandler)
  }

  function afterReconnectCustomRoom(roomId)
  {
    local roomData = ::g_chat.getRoomById(roomId)
    if (!roomData || !::checkObj(roomData.customScene))
      return

    foreach(objName in ["menuchat_input", "btn_send"])
    {
      local obj = roomData.customScene.findObject(objName)
      if (::checkObj(obj))
        obj.enable(isChatEnabled())
    }
  }

  function checkListValue(obj)
  {
    if (obj.getValue() < 0 && obj.childrenCount())
      obj.setValue(0)
  }

  function onEventInviteReceived(params)
  {
    local invite = ::getTblValue("invite", params)
    if (!invite || !invite.isVisible())
      return

    local msg = invite.getChatInviteText()
    if (msg.len())
      addRoomMsg("", "", msg, false, false, invite.inviteColor, true)
  }

  function onEventInviteUpdated(params)
  {
    onEventInviteReceived(params)
  }

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

::menuChatCb <- function menuChatCb(event, taskId, db)
{
  if (::menu_chat_handler)
    ::menu_chat_handler.onEventCb.call(::menu_chat_handler, event, taskId, db)
}

::initEmptyMenuChat <- function initEmptyMenuChat()
{
  if (!::menu_chat_handler)
  {
    ::menu_chat_handler = ::MenuChatHandler(::get_gui_scene())
    ::menu_chat_handler.initChat(null)
  }
}

if (::g_login.isLoggedIn())
  initEmptyMenuChat()

::loadMenuChatToObj <- function loadMenuChatToObj(obj)
{
  if (!::checkObj(obj))
    return

  local guiScene = obj.getScene()
  if (!::menu_chat_handler)
    ::menu_chat_handler = ::MenuChatHandler(guiScene)
  ::menu_chat_handler.initChat(obj)
}

::switchMenuChatObj <- function switchMenuChatObj(obj)
{
  if (!::menu_chat_handler)
  {
    ::loadMenuChatToObj(obj)
  } else
    ::menu_chat_handler.switchScene(obj)
}

::switchMenuChatObjIfVisible <- function switchMenuChatObjIfVisible(obj)
{
  if (::menu_chat_handler &&
      ::last_chat_scene_show &&
      !(isPlatformSony && ::is_in_loading_screen()) //!!!HACK, till hover is not working on loading
     )
    ::menu_chat_handler.switchScene(obj, true)
}

::checkMenuChatBack <- function checkMenuChatBack()
{
  if (::menu_chat_handler)
    ::menu_chat_handler.checkScene()
}

::openChatScene <- function openChatScene(ownerHandler = null)
{
  if (!gchat_is_enabled() || !::has_feature("Chat"))
  {
    ::showInfoMsgBox(::loc("msgbox/notAvailbleYet"))
    return false
  }

  local scene = ownerHandler ? ownerHandler.scene : ::getLastGamercardScene()
  if(!::checkObj(scene))
    return false

  local obj = getChatDiv(scene)
  if (!::menu_chat_handler)
    ::loadMenuChatToObj(obj)
  else
    ::menu_chat_handler.switchScene(obj, true)
  return ::menu_chat_handler!=null
}

::openChatPrivate <- function openChatPrivate(playerName, ownerHandler = null)
{
  if (!isPlayerFromXboxOne(playerName))
    return ::g_chat.openPrivateRoom(playerName, ownerHandler)

  ::find_contact_by_name_and_do(playerName, function(contact) {
    if (contact.xboxId == "")
      return contact.getXboxId(@() ::openChatPrivate(contact.name, ownerHandler))

    if (contact.canChat())
      ::g_chat.openPrivateRoom(contact.name, ownerHandler)
  })
}

::isMenuChatActive <- function isMenuChatActive()
{
  if (!::menu_chat_handler)
    return false;

  return ::menu_chat_handler.isMenuChatActive();
}

::chatUpdatePresence <- function chatUpdatePresence(contact)
{
  if (::menu_chat_handler)
    ::menu_chat_handler.updatePresenceContact.call(::menu_chat_handler, contact)
}

::resetChat <- function resetChat()
{
  ::g_chat.rooms = []
  ::new_menu_chat_messages <- false
  ::last_send_messages = []
  ::last_chat_scene_show = false
  if (::menu_chat_handler)
    ::menu_chat_handler.roomsInited = false
}

::getChatDiv <- function getChatDiv(scene)
{
  if(!::checkObj(scene))
    scene = null
  local guiScene = get_gui_scene()
  local chatObj = scene ? scene.findObject("menuChat_scene") : guiScene["menuChat_scene"]
  if (!chatObj)
  {
    guiScene.appendWithBlk(scene? scene : "", "tdiv { id:t='menuChat_scene' }")
    chatObj = scene ? scene.findObject("menuChat_scene") : guiScene["menuChat_scene"]
  }
  return chatObj
}


::open_invite_menu <- function open_invite_menu(menu, position)
{
  if (::menu_chat_handler)
    ::menu_chat_handler.openInviteMenu.call(::menu_chat_handler, menu, position)
}

::joinCustomObjRoom <- function joinCustomObjRoom(obj, roomName, password = "", owner = null)
//owner need if you want to handle custom room events:
//  onCustomChatCancel   (press esc when room input in focus)
//  onCustomChatContinue (press enter on empty message)
{
  if (::menu_chat_handler)
    ::menu_chat_handler.joinCustomObjRoom.call(::menu_chat_handler, obj, roomName, password, owner)
}

::getCustomObjEditbox <- function getCustomObjEditbox(obj)
{
  if (!::checkObj(obj))
    return null
  local inputBox = obj.findObject("menuchat_input")
  return ::checkObj(inputBox)? inputBox : null
}

::isUserBlockedByPrivateSetting <- function isUserBlockedByPrivateSetting(uid = null, userName = "")
{
  local checkUid = uid != null

  local privateValue = ::get_gui_option_in_mode(::USEROPT_ONLY_FRIENDLIST_CONTACT, ::OPTIONS_MODE_GAMEPLAY)
  return (privateValue && !::isPlayerInFriendsGroup(uid, checkUid, userName))
    || ::isPlayerNickInContacts(userName, ::EPL_BLOCKLIST)
}

