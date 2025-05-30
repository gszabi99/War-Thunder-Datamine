from "%scripts/dagui_natives.nut" import ps4_is_ugc_enabled, clan_get_my_clan_id
from "%scripts/dagui_library.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { format } = require("string")
let { enumsAddTypes } = require("%sqStdLibs/helpers/enums.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { isCrossNetworkMessageAllowed, checkChatEnableWithPlayer } = require("%scripts/chat/chatStates.nut")
let { hasMenuGeneralChats, hasMenuChatPrivate, hasMenuChatSquad, hasMenuChatClan,
  hasMenuChatSystem, hasMenuChatMPlobby } = require("%scripts/user/matchingFeature.nut")
let { startsWith, slice } = require("%sqstd/string.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { getThreadInfo, canCreateThreads } = require("%scripts/chat/chatStorage.nut")
let { chatColors, getSenderColor } = require("%scripts/chat/chatColors.nut")
let { clanUserTable } = require("%scripts/contacts/contactsManager.nut")
let { isPlayerNickInContacts } = require("%scripts/contacts/contactsChecks.nut")
let { getPlayerFullName } = require("%scripts/contacts/contactsInfo.nut")
let { langsList, globalChatRooms } = require("%scripts/chat/chatConsts.nut")

enum chatRoomCheckOrder {
  CUSTOM
  GLOBAL
  REGULAR
}

enum chatRoomTabOrder {
  THREADS_LIST
  SYSTEM
  STATIC  
  REGULAR
  PRIVATE
  HIDDEN
}

let g_chat_room_type = {
  types = []
}

g_chat_room_type.template <- {
  typeName = "" 
  roomPrefix = "#"
  checkOrder = chatRoomCheckOrder.CUSTOM
  tabOrder = chatRoomTabOrder.REGULAR
  isErrorPopupAllowed = true

  checkRoomId = function(roomId) { return startsWith(roomId, this.roomPrefix) }

  
  getRoomId   = function(param1, _param2 = null) { return $"{this.roomPrefix}{param1}" }

  roomNameLocId = null
    
  getRoomName = function(roomId, _isColored = false) {
    if (this.roomNameLocId)
      return loc(this.roomNameLocId)
    let roomName = roomId.slice(1)
    return loc($"chat/channel/{roomName}", roomName)
  }
  getTooltip = @(roomId) this.getRoomName(roomId, true)
  getRoomColorTag = @(_roomId) ""

  havePlayersList = true
  canVoiceChat = false
  canBeClosed = function(_roomId) { return true }
  needSave = function() { return false }
  needSwitchRoomOnJoin = false 
  canInviteToRoom = false
  onlyOwnerCanInvite = true
  isVisibleInSearch = function() { return false }
  hasCustomViewHandler = false
  loadCustomHandler = @(_scene, _roomId, _backFunc) null

  inviteLocIdNoNick = "chat/receiveInvite/noNick"
  inviteLocIdFull = "chat/receiveInvite"
  leaveLocId = "chat/leaveChannel"
  inviteIcon = "#ui/gameuiskin#chat.svg"
  errorLocPostfix = {}
  getErrorPostfix = @(code) this.errorLocPostfix?[code] ?? ""
  getInviteClickNameText = function(roomId) {
    let locId = showConsoleButtons.value ? "chat/receiveInvite/acceptToJoin" : "chat/receiveInvite/clickToJoin"
    return format(loc(locId), this.getRoomName(roomId))
  }

  canCreateRoom = function() { return false }

  hasChatHeader = false
  fillChatHeader = function(_obj, _roomData) {}
  updateChatHeader = function(_obj, _roomData) {}
  isAllowed = @() true
  checkConcealed = @(_roomId, cb) cb?(false)
  isVisible = @() false

  needCountAsImportant = false
  needShowMessagePopup = true

  isHaveOwner =  true 
                      
}

enumsAddTypes(g_chat_room_type, {
  DEFAULT_ROOM = {
    checkOrder = chatRoomCheckOrder.REGULAR
    needSave = function() { return true }
    canInviteToRoom = true
    getTooltip = function(roomId) { return roomId.slice(1) }
    isVisibleInSearch = function() { return true }
    isAllowed = ps4_is_ugc_enabled
    canCreateRoom = @() this.isAllowed()
    isVisible = @() hasMenuGeneralChats.value
  }

  PRIVATE = {
    checkOrder = chatRoomCheckOrder.REGULAR
    tabOrder = chatRoomTabOrder.PRIVATE
    havePlayersList = false
    needCountAsImportant = true

    checkRoomId  = function(roomId) { return !startsWith(roomId, this.roomPrefix) }
    getRoomId    = function(playerName, ...) { return playerName }
    getRoomName  = function(roomId, isColored = false) { 
      local res = getPlayerFullName(getPlayerName(roomId), clanUserTable.get()?[roomId] ?? "")
      if (isColored)
        res = colorize(getSenderColor(roomId), res)
      return res
    }
    getRoomColorTag = function(roomId) { 
      if (g_squad_manager.isInMySquad(roomId, false))
        return "squad"
      if (isPlayerNickInContacts(roomId, EPL_FRIENDLIST))
        return "friend"
      return ""
    }

    checkConcealed = function(roomId, callback) {
      if (!isCrossNetworkMessageAllowed(roomId)) {
        callback?(true);
        return
      }
      checkChatEnableWithPlayer(roomId, function(is_enabled) {
        callback?(!is_enabled)
      })
    }

    isVisible = @() hasMenuChatPrivate.value
  }

  SQUAD = { 
    roomPrefix = "#_msquad_"
    roomNameLocId = "squad/name"
    inviteLocIdNoNick = "squad/receiveInvite/noNick"
    inviteLocIdFull = "squad/receiveInvite"
    leaveLocId = "squad/leaveChannel"
    inviteIcon = "#ui/gameuiskin#squad_leader"
    canVoiceChat = true
    needCountAsImportant = true

    getRoomName = function(roomId, isColored = false, isFull = false) {
      let isMySquadRoom = roomId == g_chat_room_type.getMySquadRoomId()
      local res = !isFull || isMySquadRoom ? loc(this.roomNameLocId) : loc("squad/disbanded/name")
      if (isColored && isMySquadRoom)
        res = colorize(chatColors.senderSquad[true], res)
      return res
    }
    getTooltip = @(roomId) this.getRoomName(roomId, true, true)
    getRoomColorTag = @(roomId) roomId == g_chat_room_type.getMySquadRoomId() ? "squad" : "disbanded_squad"

    canBeClosed = function(roomId) { return !g_squad_manager.isInSquad() || roomId != g_chat_room_type.getMySquadRoomId() }
    getInviteClickNameText = function(_roomId) {
      return loc(showConsoleButtons.value ? "squad/inviteSquadName/acceptToJoin" : "squad/inviteSquadName")
    }
    isVisible = @() hasMenuChatSquad.value
  }

  CLAN = { 
    tabOrder = chatRoomTabOrder.STATIC
    roomPrefix = "#_clan_"
    roomNameLocId = "clan/name"
    canVoiceChat = true
    isErrorPopupAllowed = false
    needShowMessagePopup = false
    needCountAsImportant = true
    isHaveOwner = false

    canBeClosed = function(roomId) { return roomId != this.getRoomId(clan_get_my_clan_id()) }
    isVisible = @() hasMenuChatClan.value
  }

  SYSTEM = { 
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

  MP_LOBBY = { 
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
      if (!startsWith(roomId, "#"))
        return false
      foreach (r in globalChatRooms)
        if (roomId.indexof($"{r.name}_", 1) == 1) {
          let lang = slice(roomId, r.name.len() + 2)
          return isInArray(lang, r?.langs ?? langsList)
        }
      return false
    }
    getRoomId = function(roomName, lang = null) { 
      if (!lang)
        lang = loc("current_lang")
      foreach (r in globalChatRooms) {
        if (r.name != roomName)
          continue

        let langs = r?.langs ?? langsList
        if (!isInArray(lang, langs))
          lang = langs[0]
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
      let threadInfo = getThreadInfo(roomId)
      if (!threadInfo)
        return loc(this.roomNameLocId)

      local title = threadInfo.getTitle()
      
      let idx = title.indexof("\n")
      if (idx)
        title = title.slice(0, idx)

      if (utf8(title).charCount() > this.threadNameLen)
        return utf8(title).slice(0, this.threadNameLen)
      return title
    }
    getTooltip = function(roomId) {
      let threadInfo = getThreadInfo(roomId)
      return threadInfo ? threadInfo.getRoomTooltipText() : ""
    }

    canCreateRoom = function() { return canCreateThreads() }

    hasChatHeader = true
    fillChatHeader = function(obj, roomData) {
      let handler = handlersManager.loadHandler(gui_handlers.ChatThreadHeader,
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

    checkConcealed = @(roomId, cb) cb?(getThreadInfo(roomId)?.isConcealed() ?? false)
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
    loadCustomHandler = @(scene, roomId, backFunc) handlersManager.loadHandler(
      gui_handlers.ChatThreadsListView, {
        scene = scene,
        roomId = roomId,
        backFunc = backFunc
    })
    isVisible = @() hasMenuGeneralChats.value
  }
}, null, "typeName")

let resortRooms = @() g_chat_room_type.types.sort(@(a, b) a.checkOrder <=> b.checkOrder)

resortRooms()

g_chat_room_type.getRoomType <- function getRoomType(roomId) {
  foreach (roomType in this.types)
    if (roomType.checkRoomId(roomId))
      return roomType
  assert(false, $"Cant get room type by roomId = {roomId}")
  return this.DEFAULT_ROOM
}

g_chat_room_type.getMySquadRoomId <- function getMySquadRoomId() {
  if (!g_squad_manager.isInSquad())
    return null

  let squadRoomName = g_squad_manager.getSquadRoomName()
  if (u.isEmpty(squadRoomName))
    return null

  return g_chat_room_type.SQUAD.getRoomId(squadRoomName)
}

function addChatRoomType(roomType) {
  enumsAddTypes(g_chat_room_type, roomType, null, "typeName")
  resortRooms()
}

const WWRoomPrefix = "#_ww_"
let wwRoomsTypeData = {
  roomPrefix = WWRoomPrefix
  getOperationId = @(roomId) roomId.split("_")[3].tointeger()
  getOperationSide = @(roomId) roomId.split("_")[5].tointeger()
  checkRoomId = @(roomId) roomId.contains(WWRoomPrefix)
}
let isRoomWWOperation = @(roomId) wwRoomsTypeData.checkRoomId(roomId)

return {
  g_chat_room_type
  addChatRoomType
  wwRoomsTypeData
  isRoomWWOperation
}