from "%scripts/dagui_library.nut" import *

let { g_chat } = require("%scripts/chat/chat.nut")
let { g_chat_room_type } = require("%scripts/chat/chatRoomType.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { format } = require("string")
let { add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")
let { registerInviteClass } = require("%scripts/invites/invitesClasses.nut")
let BaseInvite = require("%scripts/invites/inviteBase.nut")
let { menuChatHandler } = require("%scripts/chat/chatHandler.nut")

let ChatRoom = class (BaseInvite) {
  
  roomId = ""
  roomType = g_chat_room_type.DEFAULT_ROOM
  needCheckCanChatWithPlayer = true

  static function getUidByParams(params) {
    return "".concat("CR_", getTblValue("inviterName", params, ""), "/", getTblValue("roomId", params, ""))
  }

  function updateCustomParams(params, initial = false) {
    this.roomId = getTblValue("roomId", params, "")
    this.roomType = g_chat_room_type.getRoomType(this.roomId)
    let cb = Callback(@() this.checkInviteRoomType(initial), this)
    this.setDelayed(true)
    this.updateCanChatWithPlayer(cb)
  }

  function checkInviteRoomType(initial) {
    if (this.roomType == g_chat_room_type.THREAD) {
      let threadInfo = g_chat.addThreadInfoById(this.roomId)
      threadInfo.checkRefreshThread()
      if (threadInfo.lastUpdateTime < 0)
        this.setDelayed(true)
      else
        this.setDelayed(false)
      if (initial)
        add_event_listener("ChatThreadInfoChanged",
                             function (data) {
                               if (getTblValue("roomId", data) == this.roomId)
                                 this.setDelayed(false)
                             },
                             this)
      return
    }
    if (this.roomType == g_chat_room_type.SQUAD
        && this.inviterName == g_squad_manager.getLeaderNick()) {
      this.autoAccept()
      return
    }

    this.setDelayed(false)
  }

  function isValid() {
    return this.roomId != "" && this.roomType.isAllowed()
  }

  function haveRestrictions() {
    return !this.isAvailableByChatRestriction()
  }

  function getChatInviteText() {
    let nameF = "".concat("<Link=%s><Color=", this.inviteActiveColor, ">%s</Color></Link>")

    let clickNameText = this.roomType.getInviteClickNameText(this.roomId)
    return loc(this.roomType.inviteLocIdFull,
                 { player = format(nameF, this.getChatInviterLink(), this.getInviterName()),
                   channel = format(nameF, this.getChatLink(), clickNameText) })
  }

  function getInviteText() {
    return loc(this.roomType.inviteLocIdNoNick,
                 {
                   channel = this.roomType.getRoomName(this.roomId)
                 })
  }

  function getPopupText() {
    return loc(this.roomType.inviteLocIdFull,
                 {
                   player = this.getInviterName()
                   channel = this.roomType.getRoomName(this.roomId)
                 })
  }

  function getIcon() {
    if (this.roomType == g_chat_room_type.SQUAD)
      return ""

    return this.roomType.inviteIcon
  }

  function accept() {
    if (menuChatHandler.get() == null)
      return

    menuChatHandler.get().popupAcceptInvite(this.roomId)
    this.remove()
  }
}

registerInviteClass("ChatRoom", ChatRoom)
