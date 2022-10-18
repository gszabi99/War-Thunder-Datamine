from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let platformModule = require("%scripts/clientState/platform.nut")
let { checkAndShowMultiplayerPrivilegeWarning,
  isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")
let { requestUsersInfo } = require("%scripts/user/usersInfoManager.nut")
let { needProceedSquadInvitesAccept,
  isPlayerFromXboxSquadList } = require("%scripts/social/xboxSquadManager/xboxSquadManager.nut")

::g_invites_classes.Squad <- class extends ::BaseInvite
{
  //custom class params, not exist in base invite
  squadId = 0
  leaderId = 0
  isAccepted = false
  leaderContact = null
  needCheckSystemRestriction = true

  static function getUidByParams(params)
  {
    return "SQ_" + getTblValue("squadId", params, "")
  }

  function updateCustomParams(params, initial = false)
  {
    squadId = getTblValue("squadId", params, squadId)
    leaderId = getTblValue("leaderId", params, leaderId)

    updateInviterContact()

    if (this.inviterName.len() != 0)
    {
      //Don't show invites from xbox players, as notification comes from system overlay
      log("InviteSquad: invitername != 0 " + platformModule.isPlayerFromXboxOne(this.inviterName))
      if (platformModule.isPlayerFromXboxOne(this.inviterName))
        this.setDelayed(true)
    }
    else
    {
      this.setDelayed(true)
      let cb = Callback(function(_r)
                            {
                              updateInviterContact()
                              log("InviteSquad: Callback: invitername == 0 " + platformModule.isPlayerFromXboxOne(this.inviterName))
                              if (platformModule.isPlayerFromXboxOne(this.inviterName))
                              {
                                this.setDelayed(true)
                                checkAutoAcceptXboxInvite()
                              }
                              else
                                this.setDelayed(false)
                            }, this)
      requestUsersInfo([leaderId], cb, cb)
    }
    isAccepted = false

    if (initial)
      ::add_event_listener("SquadStatusChanged",
        function (_p) {
          if (::g_squad_manager.isInSquad()
              && ::g_squad_manager.getLeaderUid() == squadId.tostring())
            onSuccessfulAccept()
        }, this)

    checkAutoAcceptXboxInvite()
  }

  function updateInviterContact()
  {
    leaderContact = ::getContact(leaderId)
    updateInviterName()
  }

  function updateInviterName()
  {
    if (leaderContact)
      this.inviterName = leaderContact.name
  }

  function checkAutoAcceptXboxInvite()
  {
    if (!is_platform_xbox
        || !leaderContact
        || (haveRestrictions() && !::isInMenu())
        || !needProceedSquadInvitesAccept()
      )
      return

    if (leaderContact.xboxId != "")
      autoacceptXboxInvite(leaderContact.xboxId)
    else
      leaderContact.getXboxId(Callback(@() autoacceptXboxInvite(leaderContact.xboxId), this))
  }

  function autoacceptXboxInvite(leaderXboxId = "") {
    if (!isPlayerFromXboxSquadList(leaderXboxId))
      return autorejectInvite()

    checkAutoAcceptInvite()
  }

  function autoacceptInviteImpl() {
    if (!_implAccept())
      autorejectInvite()
  }

  function autorejectInvite() {
    if (!::g_squad_utils.canSquad() || !leaderContact.canInvite())
      reject()
  }

  function checkAutoAcceptInvite() {
    let invite = this
    ::queues.leaveAllQueues(null, function() {
      if (!invite.isValid())
        return

      if (!::g_squad_manager.isInSquad())
        invite.autoacceptInviteImpl()
      else
        ::g_squad_manager.leaveSquad(@() invite.isValid() && invite.autoacceptInviteImpl())
    })
  }

  function isValid()
  {
    return !isAccepted
  }

  function getInviteText()
  {
    return loc("multiplayer/squad/invite/desc",
                 {
                   name = this.getInviterName() || platformModule.getPlayerName(this.inviterName)
                 })
  }

  function getPopupText()
  {
    return loc("multiplayer/squad/invite/desc",
                 {
                   name = this.getInviterName() || platformModule.getPlayerName(this.inviterName)
                 })
  }

  function getRestrictionText()
  {
    if (!isMultiplayerPrivilegeAvailable.value)
      return loc("xbox/noMultiplayer")
    if (!this.isAvailableByCrossPlay())
      return loc("xbox/crossPlayRequired")
    if (!this.isAvailableByChatRestriction())
      return loc("xbox/actionNotAvailableLiveCommunications")
    if (haveRestrictions())
      return loc("squad/cant_join_in_flight")
    return ""
  }

  function haveRestrictions()
  {
    return !::g_squad_manager.canManageSquad()
    || !this.isAvailableByCrossPlay()
    || !this.isAvailableByChatRestriction()
    || !isMultiplayerPrivilegeAvailable.value
  }

  function getIcon()
  {
    return "#ui/gameuiskin#lb_each_player_session.svg"
  }

  function onSuccessfulReject() {}

  function onSuccessfulAccept()
  {
    isAccepted = true
    this.remove()
  }

  function accept()
  {
    if (!isMultiplayerPrivilegeAvailable.value) {
      checkAndShowMultiplayerPrivilegeWarning()
      return
    }

    let acceptCallback = Callback(_implAccept, this)
    let callback = function () { ::queues.checkAndStart(acceptCallback, null, "isCanNewflight")}
    let canJoin = ::g_squad_utils.canJoinFlightMsgBox(
      { allowWhenAlone = false, msgId = "squad/leave_squad_for_invite" },
      callback
    )

    if (!canJoin)
      return

    callback()
  }

  function reject()
  {
    if (this.isOutdated())
      return this.remove()

    this.isRejected = true
    ::g_squad_manager.rejectSquadInvite(squadId)
    this.remove()
    ::g_invites.removeInviteToSquad(squadId)
    onSuccessfulReject()
  }

  function _implAccept()
  {
    if (this.isOutdated())
    {
      ::g_invites.showExpiredInvitePopup()
      return false
    }
    if (!::g_squad_manager.canJoinSquad())
      return false

    ::g_squad_manager.acceptSquadInvite(squadId)
    return true
  }
}
