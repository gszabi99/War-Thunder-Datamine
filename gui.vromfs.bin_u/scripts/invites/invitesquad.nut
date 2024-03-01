//-file:plus-string
from "%scripts/dagui_library.nut" import *

let { g_chat_room_type } = require("%scripts/chat/chatRoomType.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let platformModule = require("%scripts/clientState/platform.nut")
let { checkAndShowMultiplayerPrivilegeWarning,
  isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")
let { requestUsersInfo } = require("%scripts/user/usersInfoManager.nut")
let { needProceedSquadInvitesAccept,
  isPlayerFromXboxSquadList } = require("%scripts/social/xboxSquadManager/xboxSquadManager.nut")
let { isShowGoldBalanceWarning } = require("%scripts/user/balanceFeatures.nut")
let { add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { registerInviteClass } = require("%scripts/invites/invitesClasses.nut")
let BaseInvite = require("%scripts/invites/inviteBase.nut")
let { isInMenu } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { format } = require("string")

let Squad = class (BaseInvite) {
  //custom class params, not exist in base invite
  squadId = 0
  leaderId = 0
  isAccepted = false
  leaderContact = null
  needCheckSystemRestriction = true

  roomId = ""
  roomType = g_chat_room_type.SQUAD

  static function getUidByParams(params) {
    return "SQ_" + getTblValue("squadId", params, "")
  }

  function updateCustomParams(params, initial = false) {
    this.squadId = getTblValue("squadId", params, this.squadId)
    this.leaderId = getTblValue("leaderId", params, this.leaderId)

    this.updateInviterContact()

    if (this.inviterName.len() != 0) {
      //Don't show invites from xbox players, as notification comes from system overlay
      log("InviteSquad: invitername != 0 " + platformModule.isPlayerFromXboxOne(this.inviterName))
      if (platformModule.isPlayerFromXboxOne(this.inviterName))
        this.setDelayed(true)
    }
    else {
      this.setDelayed(true)
      let cb = Callback(function(_r) {
                              this.updateInviterContact()
                              log("InviteSquad: Callback: invitername == 0 " + platformModule.isPlayerFromXboxOne(this.inviterName))
                              if (platformModule.isPlayerFromXboxOne(this.inviterName)) {
                                this.setDelayed(true)
                                this.checkAutoAcceptXboxInvite()
                              }
                              else
                                this.setDelayed(false)
                            }, this)
      requestUsersInfo([this.leaderId], cb, cb)
    }
    this.isAccepted = false

    if (initial)
      add_event_listener("SquadStatusChanged",
        function (_p) {
          if (g_squad_manager.isInSquad()
              && g_squad_manager.getLeaderUid() == this.squadId.tostring())
            this.onSuccessfulAccept()
        }, this)

    this.checkAutoAcceptXboxInvite()
  }

  function updateInviterContact() {
    this.leaderContact = ::getContact(this.leaderId)
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
    if (!is_platform_xbox
        || !this.leaderContact
        || (this.haveRestrictions() && !isInMenu())
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
    if (!::g_squad_utils.canSquad() || !this.leaderContact.canInvite())
      this.reject()
  }

  function checkAutoAcceptInvite() {
    let invite = this
    ::queues.leaveAllQueues(null, function() {
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
    if (!isMultiplayerPrivilegeAvailable.value)
      return loc("xbox/noMultiplayer")
    if (!this.isAvailableByCrossPlay())
      return loc("xbox/crossPlayRequired")
    if (!this.isAvailableByChatRestriction())
      return loc("xbox/actionNotAvailableLiveCommunications")
    if (this.haveRestrictions())
      return loc("squad/cant_join_in_flight")
    return ""
  }

  function haveRestrictions() {
    return !g_squad_manager.canManageSquad()
    || !this.isAvailableByCrossPlay()
    || !this.isAvailableByChatRestriction()
    || !isMultiplayerPrivilegeAvailable.value
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
    if (!isMultiplayerPrivilegeAvailable.value) {
      checkAndShowMultiplayerPrivilegeWarning()
      return
    }

    if (isShowGoldBalanceWarning())
      return

    let acceptCallback = Callback(this._implAccept, this)
    let callback = function () { ::queues.checkAndStart(acceptCallback, null, "isCanNewflight") }
    let canJoin = ::g_squad_utils.canJoinFlightMsgBox(
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
    ::g_invites.removeInviteToSquad(this.squadId)
    this.onSuccessfulReject()
  }

  function _implAccept() {
    if (this.isOutdated()) {
      ::g_invites.showExpiredInvitePopup()
      return false
    }
    if (!g_squad_manager.canJoinSquad())
      return false

    g_squad_manager.acceptSquadInvite(this.squadId)
    return true
  }
}

registerInviteClass("Squad", Squad)
