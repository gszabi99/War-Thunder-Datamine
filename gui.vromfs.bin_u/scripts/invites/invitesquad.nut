let platformModule = require("%scripts/clientState/platform.nut")
let { checkAndShowMultiplayerPrivilegeWarning,
  isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")

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
    return "SQ_" + ::getTblValue("squadId", params, "")
  }

  function updateCustomParams(params, initial = false)
  {
    squadId = ::getTblValue("squadId", params, squadId)
    leaderId = ::getTblValue("leaderId", params, leaderId)

    updateInviterContact()

    if (inviterName.len() != 0)
    {
      //Don't show invites from xbox players, as notification comes from system overlay
      ::dagor.debug("InviteSquad: invitername != 0 " + platformModule.isPlayerFromXboxOne(inviterName))
      if (platformModule.isPlayerFromXboxOne(inviterName))
        setDelayed(true)
    }
    else
    {
      setDelayed(true)
      let cb = ::Callback(function(r)
                            {
                              updateInviterContact()
                              ::dagor.debug("InviteSquad: Callback: invitername == 0 " + platformModule.isPlayerFromXboxOne(inviterName))
                              if (platformModule.isPlayerFromXboxOne(inviterName))
                              {
                                setDelayed(true)
                                checkAutoAcceptXboxInvite()
                              }
                              else
                                setDelayed(false)
                            }, this)
      ::g_users_info_manager.requestInfo([leaderId], cb, cb)
    }
    isAccepted = false

    if (initial)
      ::add_event_listener("SquadStatusChanged",
        function (p) {
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
      inviterName = leaderContact.name
  }

  function checkAutoAcceptXboxInvite()
  {
    if (!::is_platform_xbox
        || !leaderContact
        || (haveRestrictions() && !::isInMenu())
        || !::g_xbox_squad_manager.needProceedSquadInvitesAccept()
      )
      return

    if (leaderContact.xboxId != "")
      autoacceptXboxInvite(leaderContact.xboxId)
    else
      leaderContact.getXboxId(::Callback(@() autoacceptXboxInvite(leaderContact.xboxId), this))
  }

  function autoacceptXboxInvite(leaderXboxId = "") {
    if (!::g_xbox_squad_manager.isPlayerFromXboxSquadList(leaderXboxId))
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
    return ::loc("multiplayer/squad/invite/desc",
                 {
                   name = getInviterName() || platformModule.getPlayerName(inviterName)
                 })
  }

  function getPopupText()
  {
    return ::loc("multiplayer/squad/invite/desc",
                 {
                   name = getInviterName() || platformModule.getPlayerName(inviterName)
                 })
  }

  function getRestrictionText()
  {
    if (!isMultiplayerPrivilegeAvailable.value)
      return ::loc("xbox/noMultiplayer")
    if (!isAvailableByCrossPlay())
      return ::loc("xbox/crossPlayRequired")
    if (!isAvailableByChatRestriction())
      return ::loc("xbox/actionNotAvailableLiveCommunications")
    if (haveRestrictions())
      return ::loc("squad/cant_join_in_flight")
    return ""
  }

  function haveRestrictions()
  {
    return !::g_squad_manager.canManageSquad()
    || !isAvailableByCrossPlay()
    || !isAvailableByChatRestriction()
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
    remove()
  }

  function accept()
  {
    if (!isMultiplayerPrivilegeAvailable.value) {
      checkAndShowMultiplayerPrivilegeWarning()
      return
    }

    let acceptCallback = ::Callback(_implAccept, this)
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
    if (isOutdated())
      return remove()

    isRejected = true
    ::g_squad_manager.rejectSquadInvite(squadId)
    remove()
    ::g_invites.removeInviteToSquad(squadId)
    onSuccessfulReject()
  }

  function _implAccept()
  {
    if (isOutdated())
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
