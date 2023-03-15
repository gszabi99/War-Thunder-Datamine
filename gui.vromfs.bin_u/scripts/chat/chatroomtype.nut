//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
let enums = require("%sqStdLibs/helpers/enums.nut")
let platformModule = require("%scripts/clientState/platform.nut")
let { isCrossNetworkMessageAllowed, isChatEnableWithPlayer } = require("%scripts/chat/chatStates.nut")
let { hasMenuGeneralChats, hasMenuChatPrivate, hasMenuChatSquad, hasMenuChatClan,
  hasMenuChatSystem, hasMenuChatMPlobby } = require("%scripts/user/matchingFeature.nut")

enum chatRoomCheckOrder {
  CUSTOM
  GLOBAL
  REGULAR
}

enum chatRoomTabOrder {
  THREADS_LIST
  SYSTEM
  STATIC  //cant be closed
  REGULAR
  PRIVATE
  HIDDEN
}

::g_chat_room_type <- {
  types = []
}

::g_chat_room_type.template <- {
  typeName = "" //Generic from type.
  roomPrefix = "#"
  checkOrder = chatRoomCheckOrder.CUSTOM
  tabOrder = chatRoomTabOrder.REGULAR
  isErrorPopupAllowed = true

  checkRoomId = function(roomId) { return ::g_string.startsWith(roomId, this.roomPrefix) }

  //roomId params depend on roomType
  getRoomId   = function(param1, _param2 = null) { return this.roomPrefix + param1 }

  roomNameLocId = null
    //localized roomName
  getRoomName = function(roomId, _isColored = false) {
    if (this.roomNameLocId)
      return loc(this.roomNameLocId)
    let roomName = roomId.slice(1)
    return loc("chat/channel/" + roomName, roomName)
  }
  getTooltip = @(roomId) this.getRoomName(roomId, true)
  getRoomColorTag = @(_roomId) ""

  havePlayersList = true
  canVoiceChat = false
  canBeClosed = function(_roomId) { return true }
  needSave = function() { return false }
  needSwitchRoomOnJoin = false //do not use it in pair with needSave
  canInviteToRoom = false
  onlyOwnerCanInvite = true
  isVisibleInSearch = function() { return false }
  hasCustomViewHandler = false
  loadCustomHandler = @(_scene, _roomId, _backFunc) null

  inviteLocIdNoNick = "chat/receiveInvite/noNick"
  inviteLocIdFull = "chat/receiveInvite"
  inviteIcon = "#ui/gameuiskin#chat.svg"
  getInviteClickNameText = function(roomId) {
    let locId = ::show_console_buttons ? "chat/receiveInvite/acceptToJoin" : "chat/receiveInvite/clickToJoin"
    return format(loc(locId), this.getRoomName(roomId))
  }

  canCreateRoom = function() { return false }

  hasChatHeader = false
  fillChatHeader = function(_obj, _roomData) {}
  updateChatHeader = function(_obj, _roomData) {}
  isAllowed = @() true
  isConcealed = @(_roomId) false
  isVisible = @() false

  needCountAsImportant = false
  needShowMessagePopup = true

  isHaveOwner =  true //To remove "@" symbol in nickname of creator of room added by the IRC server
                      //!!!FIX ME: Nickname can start with "@" symbol. And there is no way to find out the owner by the config from the IRC server
}

enums.addTypesByGlobalName("g_chat_room_type", {
  DEFAULT_ROOM = {
    checkOrder = chatRoomCheckOrder.REGULAR
    needSave = function() { return true }
    canInviteToRoom = true
    getTooltip = function(roomId) { return roomId.slice(1) }
    isVisibleInSearch = function() { return true }
    isAllowed = ::ps4_is_ugc_enabled
    canCreateRoom = @() this.isAllowed()
    isVisible = @() hasMenuGeneralChats.value
  }

  PRIVATE = {
    checkOrder = chatRoomCheckOrder.REGULAR
    tabOrder = chatRoomTabOrder.PRIVATE
    havePlayersList = false
    needCountAsImportant = true

    checkRoomId  = function(roomId) { return !::g_string.startsWith(roomId, this.roomPrefix) }
    getRoomId    = function(playerName, ...) { return playerName }
    getRoomName  = function(roomId, isColored = false) { //roomId == playerName
      local res = ::g_contacts.getPlayerFullName(
        platformModule.getPlayerName(roomId),
        ::clanUserTable?[roomId] ?? ""
      )
      if (isColored)
        res = colorize(::g_chat.getSenderColor(roomId), res)
      return res
    }
    getRoomColorTag = function(roomId) { //roomId == playerName
      if (::g_squad_manager.isInMySquad(roomId, false))
        return "squad"
      if (::isPlayerNickInContacts(roomId, EPL_FRIENDLIST))
        return "friend"
      return ""
    }

    isConcealed = @(roomId) !isCrossNetworkMessageAllowed(roomId) || !isChatEnableWithPlayer(roomId)
    isVisible = @() hasMenuChatPrivate.value
  }

  SQUAD = { //param - random
    roomPrefix = "#_msquad_"
    roomNameLocId = "squad/name"
    inviteLocIdNoNick = "squad/receiveInvite/noNick"
    inviteLocIdFull = "squad/receiveInvite"
    inviteIcon = "#ui/gameuiskin#squad_leader"
    canVoiceChat = true
    needCountAsImportant = true

    getRoomName = function(roomId, isColored = false, isFull = false) {
      let isMySquadRoom = roomId == ::g_chat.getMySquadRoomId()
      local res = !isFull || isMySquadRoom ? loc(this.roomNameLocId) : loc("squad/disbanded/name")
      if (isColored && isMySquadRoom)
        res = colorize(::g_chat.color.senderSquad[true], res)
      return res
    }
    getTooltip = @(roomId) this.getRoomName(roomId, true, true)
    getRoomColorTag = @(roomId) roomId == ::g_chat.getMySquadRoomId() ? "squad" : "disbanded_squad"

    canBeClosed = function(roomId) { return !::g_squad_manager.isInSquad() || roomId != ::g_chat.getMySquadRoomId() }
    getInviteClickNameText = function(_roomId) {
      return loc(::show_console_buttons ? "squad/inviteSquadName/acceptToJoin" : "squad/inviteSquadName")
    }
    isVisible = @() hasMenuChatSquad.value
  }

  CLAN = { //para - clanId
    tabOrder = chatRoomTabOrder.STATIC
    roomPrefix = "#_clan_"
    roomNameLocId = "clan/name"
    canVoiceChat = true
    isErrorPopupAllowed = false
    needShowMessagePopup = false
    needCountAsImportant = true
    isHaveOwner = false

    canBeClosed = function(roomId) { return roomId != this.getRoomId(::clan_get_my_clan_id()) }
    isVisible = @() hasMenuChatClan.value
  }

  SYSTEM = { //param none
    tabOrder = chatRoomTabOrder.SYSTEM
    roomPrefix = "#___empty___"
    havePlayersList = false
    isErrorPopupAllowed = false
    isHaveOwner = false
    checkRoomId = function(roomId) { return roomId == this.roomPrefix }
    getRoomId   = function(...) { return this.roomPrefix }
    canBeClosed = function(_roomId) { return false }
    isVisible = @() hasMenuChatSystem.value
  }

  MP_LOBBY = { //param SessionLobby.roomId
    tabOrder = chatRoomTabOrder.HIDDEN
    roomPrefix = "#lobby_room_"
    havePlayersList = false
    isErrorPopupAllowed = false
    isHaveOwner = false
    isVisible = @() hasMenuChatMPlobby.value
  }

  GLOBAL = {
    checkOrder = chatRoomCheckOrder.GLOBAL
    havePlayersList = false
    checkRoomId = function(roomId) {
      if (!::g_string.startsWith(roomId, "#"))
        return false
      foreach (r in ::global_chat_rooms)
        if (roomId.indexof(r.name + "_", 1) == 1) {
          let lang = ::g_string.slice(roomId, r.name.len() + 2)
          local langsList = getTblValue("langs", r, ::langs_list)
          return isInArray(lang, langsList)
        }
      return false
    }
    getRoomId = function(roomName, lang = null) { //room id is  #<<roomName>>_<<validated lang>>
      if (!lang)
        lang = ::cur_chat_lang
      foreach (r in ::global_chat_rooms) {
        if (r.name != roomName)
          continue

        let langsList = getTblValue("langs", r, ::langs_list)
        if (!isInArray(lang, langsList))
          lang = langsList[0]
        return format("#%s_%s", roomName, lang)
      }
      return ""
    }
    getTooltip = function(roomId) { return roomId.slice(1) }
    isVisible = @() hasMenuGeneralChats.value
  }

  THREAD = {
    roomPrefix = "#_x_thread_"
    roomNameLocId = "chat/thread"
    needSwitchRoomOnJoin = true
    havePlayersList = false
    canInviteToRoom = true
    onlyOwnerCanInvite = false

    threadNameLen = 15
    getRoomName = function(roomId, _isColored = false) {
      let threadInfo = ::g_chat.getThreadInfo(roomId)
      if (!threadInfo)
        return loc(this.roomNameLocId)

      local title = threadInfo.getTitle()
      //use text only before first linebreak
      let idx = title.indexof("\n")
      if (idx)
        title = title.slice(0, idx)

      if (utf8(title).charCount() > this.threadNameLen)
        return utf8(title).slice(0, this.threadNameLen)
      return title
    }
    getTooltip = function(roomId) {
      let threadInfo = ::g_chat.getThreadInfo(roomId)
      return threadInfo ? threadInfo.getRoomTooltipText() : ""
    }

    canCreateRoom = function() { return ::g_chat.canCreateThreads() }

    hasChatHeader = true
    fillChatHeader = function(obj, roomData) {
      let handler = ::handlersManager.loadHandler(::gui_handlers.ChatThreadHeader,
                                                    {
                                                      scene = obj
                                                      roomId = roomData.id
                                                    })
      obj.setUserData(handler)
    }
    updateChatHeader = function(obj, _roomData) {
      let ud = obj.getUserData()
      if ("onSceneShow" in ud)
        ud.onSceneShow()
    }

    isConcealed = @(roomId) ::g_chat.getThreadInfo(roomId)?.isConcealed() ?? false
    isVisible = @() hasMenuGeneralChats.value
  }

  THREADS_LIST = {
    tabOrder = chatRoomTabOrder.THREADS_LIST
    roomPrefix = "#___threads_list___"
    roomNameLocId = "chat/threadsList"
    havePlayersList = false
    checkRoomId = function(roomId) { return roomId == this.roomPrefix }
    getRoomId   = function(...) { return this.roomPrefix }
    canBeClosed = function(_roomId) { return false }


    hasCustomViewHandler = true
    loadCustomHandler = @(scene, roomId, backFunc) ::handlersManager.loadHandler(
      ::gui_handlers.ChatThreadsListView, {
        scene = scene,
        roomId = roomId,
        backFunc = backFunc
    })
    isVisible = @() hasMenuGeneralChats.value
  }
}, null, "typeName")

::g_chat_room_type.types.sort(function(a, b) {
  if (a.checkOrder != b.checkOrder)
    return a.checkOrder < b.checkOrder ? -1 : 1
  return 0
})

::g_chat_room_type.getRoomType <- function getRoomType(roomId) {
  foreach (roomType in this.types)
    if (roomType.checkRoomId(roomId))
      return roomType

  assert(false, "Cant get room type by roomId = " + roomId)
  return this.DEFAULT_ROOM
}
