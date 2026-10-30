from "%appGlobals/clientState/platform.nut" import isPlayerFromXboxOne
from "%scripts/squads/squadManager.nut" import g_squad_manager
from "%scripts/user/xboxFeatures.nut" import checkAndShowMultiplayerPrivilegeWarning, isMultiplayerPrivilegeAvailable
from "%scripts/user/usersInfoManager.nut" import requestUsersInfo
from "%scripts/social/xboxSquadManager/xboxSquadManager.nut" import needProceedSquadInvitesAccept, isPlayerFromXboxSquadList
from "%scripts/user/balanceFeatures.nut" import isShowGoldBalanceWarning
from "%scripts/user/remapNick.nut" import getPlayerName
from "%scripts/invites/invitesClasses.nut" import registerInviteClass
from "%scripts/clientState/clientStates.nut" import isInMenu
from "%scripts/contacts/contacts.nut" import getContact
from "%scripts/queue/queueManager.nut" import checkQueueAndStart, leaveAllQueues
from "%scripts/invites/invites.nut" import showExpiredInvitePopup, removeInviteToSquad
from "%scripts/squads/squadUtils.nut" import canJoinFlightMsgBox, canSquad
from "%sqStdLibs/helpers/subscriptions.nut" import add_event_listener
from "%sqstd/platform.nut" import is_gdk
from "string" import format
from "%globalScripts/loc_helpers.nut" import locByVendor
from "%scripts/dagui_library.nut" import *

let { g_chat_room_type } = require("%scripts/chat/chatRoomType.nut")
let BaseInvite = require("%scripts/invites/inviteBase.nut")

let Squad = class (BaseInvite) {
  
  squadId = 0
  leaderId = 0
  isAccepted = false
  leaderContact = null
  needCheckSystemRestriction = true
  needCheckCanChatWithPlayer = true

  roomId = ""
  roomType = g_chat_room_type.SQUAD

  static function getUidByParams(params) {
    return $"SQ_{(params?.squadId ?? "")}"
  }

  function updateCustomParams(params, initial = false) {
    this.squadId = (params?.squadId ?? this.squadId)
    this.leaderId = (params?.leaderId ?? this.leaderId)

    this.updateInviterContact()
    if (initial) {
      add_event_listener("SquadStatusChanged",
        function (_p) {
          if (g_squad_manager.isInSquad()
              && g_squad_manager.getLeaderUid() == this.squadId.tostring())
            this.onSuccessfulAccept()
        }, this)

      add_event_listener("UserInfoManagerDataUpdated",
        function(p) {
          if (this.leaderId not in p.usersInfo)
            return
          this.updateInviterContact()
          this.updateCanChatWithPlayerAndCheckAutoAccept()
        }, this)
    }

    if (this.inviterName.len() != 0) {
      this.updateCanChatWithPlayerAndCheckAutoAccept()
      return
    }

    this.setDelayed(true)
    requestUsersInfo([this.leaderId])
  }

  function updateCanChatWithPlayerAndCheckAutoAccept() {
    let cb = Callback(function() {
      
      let isFromXbox = isPlayerFromXboxOne(this.inviterName)
      log($"InviteSquad: invitername != 0 {isFromXbox}")
      if (isFromXbox) {
        this.setDelayed(true)
        this.checkAutoAcceptXboxInvite()
      } else
        this.setDelayed(false)
    }, this)
    this.setDelayed(true)
    this.updateCanChatWithPlayer(cb)
  }

  function updateInviterContact() {
    this.leaderContact = getContact(this.leaderId)
    this.updateInviterName()
  }

  function getChatInviteText() {
    let name = this.getInviterName() || getPlayerName(this.inviterName)
    let joinToSquadText = this.roomType.getInviteClickNameText(this.roomId)
    let colorFormat = $"<Link=%s><Color={this.inviteActiveColor}>%s</Color></Link>"
    return loc(this.roomType.inviteLocIdFull, {
      player = format(colorFormat, this.getChatInviterLink(), name)
      channel = format(colorFormat, this.getChatLink(), joinToSquadText)
    })
  }

  function updateInviterName() {
    if (this.leaderContact)
      this.inviterName = this.leaderContact.name
  }

  function checkAutoAcceptXboxInvite() {
    if (!is_gdk
        || !this.leaderContact
        || (this.haveRestrictions() && !isInMenu.get())
        || !needProceedSquadInvitesAccept()
      )
      return

    if (this.leaderContact.xboxId != "")
      this.autoacceptXboxInvite(this.leaderContact.xboxId)
    else
      this.leaderContact.updateXboxIdAndDo(Callback(@() this.autoacceptXboxInvite(this.leaderContact.xboxId), this))
  }

  function autoacceptXboxInvite(leaderXboxId = "") {
    if (!isPlayerFromXboxSquadList(leaderXboxId))
      return this.autorejectInvite()

    this.checkAutoAcceptInvite()
  }

  function autoacceptInviteImpl() {
    if (!this._implAccept())
      this.autorejectInvite()
  }

  function autorejectInvite() {
    local thisCapture = this
    this.leaderContact.checkCanInvite(function(canInvite) {
      if (!canSquad() || !canInvite)
        thisCapture.reject()
    })
  }

  function checkAutoAcceptInvite() {
    let invite = this
    leaveAllQueues(null, function() {
      if (!invite.isValid())
        return

      if (!g_squad_manager.isInSquad())
        invite.autoacceptInviteImpl()
      else
        g_squad_manager.leaveSquad(@() invite.isValid() && invite.autoacceptInviteImpl())
    })
  }

  function isValid() {
    return !this.isAccepted
  }

  function getInviteText() {
    return loc("multiplayer/squad/invite/desc",
                 {
                   name = this.getInviterName() || getPlayerName(this.inviterName)
                 })
  }

  function getPopupText() {
    return loc("multiplayer/squad/invite/desc",
                 {
                   name = this.getInviterName() || getPlayerName(this.inviterName)
                 })
  }

  function getRestrictionText() {
    if (!isMultiplayerPrivilegeAvailable.get())
      return loc("xbox/noMultiplayer")
    if (!this.isAvailableByCrossPlay())
      return locByVendor("xbox/crossPlayRequired")
    if (!this.isAvailableByChatRestriction())
      return locByVendor("xbox/actionNotAvailableLiveCommunications")
    if (this.haveRestrictions())
      return loc("squad/cant_join_in_flight")
    return ""
  }

  function haveRestrictions() {
    return !g_squad_manager.canManageSquad()
    || !this.isAvailableByCrossPlay()
    || !this.isAvailableByChatRestriction()
    || !isMultiplayerPrivilegeAvailable.get()
  }

  function getIcon() {
    return "#ui/gameuiskin#lb_each_player_session.svg"
  }

  function onSuccessfulReject() {}

  function onSuccessfulAccept() {
    this.isAccepted = true
    this.remove()
  }

  function accept() {
    if (!isMultiplayerPrivilegeAvailable.get()) {
      checkAndShowMultiplayerPrivilegeWarning()
      return
    }

    if (isShowGoldBalanceWarning())
      return

    let acceptCallback = Callback(this._implAccept, this)
    let callback = function () { checkQueueAndStart(acceptCallback, null, "isCanNewflight") }
    let canJoin = canJoinFlightMsgBox(
      { allowWhenAlone = false, msgId = "squad/leave_squad_for_invite" },
      callback
    )

    if (!canJoin)
      return

    callback()
  }

  function reject() {
    if (this.isOutdated())
      return this.remove()

    this.isRejected = true
    g_squad_manager.rejectSquadInvite(this.squadId)
    this.remove()
    removeInviteToSquad(this.squadId)
    this.onSuccessfulReject()
  }

  function _implAccept() {
    if (this.isOutdated()) {
      showExpiredInvitePopup()
      return false
    }
    if (!g_squad_manager.canJoinSquad())
      return false

    g_squad_manager.acceptSquadInvite(this.squadId)
    return true
  }
}

registerInviteClass("Squad", Squad)
