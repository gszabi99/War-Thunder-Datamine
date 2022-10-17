let logX = require("%sqstd/log.nut")().with_prefix("[MPA_MANAGER] ")
let { set_activity, clear_activity, send_invitations, JoinRestriction } = require("%xboxLib/mpa.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { register_activation_callback, get_sender_xuid } = require("%xboxLib/activation.nut")
let { requestUnknownXboxIds } = require("%scripts/contacts/externalContactsService.nut")

local needCheckSquadInvites = false // It required 'in moment', no need to save in persist
let postponedInvitation = persist("postponedInvitation", @() ::Watched("0"))

let function getCurSquadId() {
  let squadLeaderUid = ::g_squad_manager.getLeaderUid().tostring()
  return squadLeaderUid != "" ? squadLeaderUid : ::my_user_id_str
}

let function sendInvitation(xuid) {
  let squadId = getCurSquadId()
  send_invitations(squadId, [xuid.tointeger()], function(success) {
    logX($"Invitation sent: {success}, squadId {squadId}, xuid {xuid.tointeger()}")
  })
}


let function updateActivity() {
  let maxPlayers = ::g_squad_manager.getMaxSquadSize()
  let curPlayers = ::g_squad_manager.getSquadSize()
  let squadId = getCurSquadId()
  set_activity(squadId, JoinRestriction.InviteOnly, maxPlayers, curPlayers, squadId, function(success) {
    logX($"Set activity succeeded: {success}",
      $"squadId {squadId}, restriction {JoinRestriction.InviteOnly}, maxPlayers {maxPlayers}, curPlayers {curPlayers}")
  })
}

let function clearActivity() {
  clear_activity(function(_) {
    logX("Activity cleared")
  })
}


let function onSquadJoin() {
  logX("onSquadJoin")
  updateActivity()
}


let function onSquadLeave() {
  logX("onSquadLeave")
  clearActivity()
}


let function onSquadStatusChanged() {
  logX("onSquadStatusChanged")
  switch (::g_squad_manager.state) {
    case squadState.IN_SQUAD:
      onSquadJoin()
      break
    case squadState.LEAVING:
      onSquadLeave()
      break
  }
}


let function onSquadSizeChange() {
  logX("onSquadSizeChange")
  updateActivity()
}


let function onSquadLeadershipTransfer() {
  logX("onSquadLeadershipTransfer")
  updateActivity()
}

let function acceptExistingIngameInvite(uid)
{
  let inviteUid = ::g_invites_classes.Squad.getUidByParams({squadId = uid})
  let invite = ::g_invites.findInviteByUid(inviteUid)
  logX($"Accept ingame invite: uid {uid}, inviteUid {inviteUid}, {invite}")
  if (!invite)
    return

  needCheckSquadInvites = true
  invite.checkAutoAcceptXboxInvite()
  ::broadcastEvent("XboxInviteAccepted")
  needCheckSquadInvites = false
}

let function requestPlayerAndDo(uid, name, cb) {
  let newContact = ::getContact(uid, name)

  if (newContact.needCheckXboxId())
    newContact.getXboxId(::Callback(@() cb(newContact.xboxId), this))
  else if (newContact.xboxId != "")
    cb(newContact.xboxId)
}

let function requestXboxPlayerAndDo(xuid, cb) {
  let newContact = ::findContactByXboxId(xuid)
  if (newContact) {
    cb(newContact.uid)
    return
  }

  requestUnknownXboxIds([xuid], {}, ::Callback(function(res) {
    foreach(uid, data in res) {
      ::getContact(uid, data.nick).update({xboxId = data.id})
      cb(uid)
    }
  }, this))
}

register_activation_callback(function() {
  let xuid = get_sender_xuid().tostring()
  logX($"onSquadInviteAccept: sender {xuid}")

  if (!::isInMenu()) {
    postponedInvitation(xuid)
    logX($"postpone invite accept, while not in menu")
    if (::is_in_flight())
      ::g_popups.add(::loc("squad/name"), ::loc("squad/wait_until_battle_end"))
    return
  }

  requestXboxPlayerAndDo(xuid, acceptExistingIngameInvite)
})


addListenersWithoutEnv({
  SquadStatusChanged = @(...) onSquadStatusChanged()
  SquadSizeChanged = @(...) onSquadSizeChange()
  SquadLeadershipTransfered = @(...) onSquadLeadershipTransfer()
  SignOut = @(...) clearActivity()
  LoginComplete = @(...) updateActivity()
})

return {
  sendInvitation
  sendSystemInvite = @(uid, name) requestPlayerAndDo(uid, name, sendInvitation)
  needProceedSquadInvitesAccept = @() needCheckSquadInvites
  isPlayerFromXboxSquadList = @(...) true
  checkAfterFlight = @() postponedInvitation.value == "0"
    ? null
    : requestXboxPlayerAndDo(postponedInvitation.value, acceptExistingIngameInvite)
}