//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { format } = require("string")
let { add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")
let { registerInviteClass } = require("%scripts/invites/invitesClasses.nut")
let BaseInvite = require("%scripts/invites/inviteBase.nut")

let ChatRoom = class extends BaseInvite {
  //custom class params, not exist in base invite
  roomId = ""
  roomType = ::g_chat_room_type.DEFAULT_ROOM

  static function getUidByParams(params) {
    return "CR_" + getTblValue("inviterName", params, "") + "/" + getTblValue("roomId", params, "")
  }

  function updateCustomParams(params, initial = false) {
    this.roomId = getTblValue("roomId", params, "")
    this.roomType = ::g_chat_room_type.getRoomType(this.roomId)

    if (this.roomType == ::g_chat_room_type.THREAD) {
      let threadInfo = ::g_chat.addThreadInfoById(this.roomId)
      threadInfo.checkRefreshThread()
      if (threadInfo.lastUpdateTime < 0)
        this.setDelayed(true)
      if (initial)
        add_event_listener("ChatThreadInfoChanged",
                             function (data) {
                               if (getTblValue("roomId", data) == this.roomId)
                                 this.setDelayed(false)
                             },
                             this)
    }
    else if (this.roomType == ::g_chat_room_type.SQUAD
             && this.inviterName == ::g_squad_manager.getLeaderNick())
      this.autoAccept()
  }

  function isValid() {
    return this.roomId != "" && this.roomType.isAllowed() && !this.haveRestrictions()
  }

  function haveRestrictions() {
    return !this.isAvailableByChatRestriction()
  }

  function getChatInviteText() {
    let nameF = "<Link=%s><Color=" + this.inviteActiveColor + ">%s</Color></Link>"

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
    if (this.roomType == ::g_chat_room_type.SQUAD)
      return ""

    return this.roomType.inviteIcon
  }

  function accept() {
    if (!::menu_chat_handler)
      return

    ::menu_chat_handler.popupAcceptInvite(this.roomId)
    this.remove()
  }
}

registerInviteClass("ChatRoom", ChatRoom)
