from "%scripts/dagui_library.nut" import *
from "%scripts/squads/squadsConsts.nut" import squadState

let logX = require("%sqstd/log.nut")().with_prefix("[MPA_MANAGER] ")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { set_activity, clear_activity, send_invitations, JoinRestriction } = require("%xboxLib/mpa.nut")
let { isLoggedIn } = require("%xboxLib/loginState.nut")
let { register_activation_callback, get_sender_xuid } = require("%xboxLib/activation.nut")
let { requestUnknownXboxIds } = require("%scripts/contacts/externalContactsService.nut")
let { findInviteClass } = require("%scripts/invites/invitesClasses.nut")
let { isInFlight } = require("gameplayBinding")
let { userIdStr } = require("%scripts/user/myUser.nut")
let { isInMenu } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { add_msg_box } = require("%sqDagui/framework/msgBox.nut")

local needCheckSquadInvites = false // It required 'in moment', no need to save in persist
let postponedInvitation = mkWatched(persist, "postponedInvitation", "0")

let getCurSquadId = @() ::g_squad_manager.isInSquad() ? ::g_squad_manager.getLeaderUid().tostring() : userIdStr.value

let function sendInvitation(xuid) {
  if (xuid == "") {
    logX($"Invitation sent: error, xuid is empty string")
    return
  }
  let squadId = getCurSquadId()
  send_invitations(squadId, [xuid.tointeger()], function(success) {
    logX($"Invitation sent: {success}, squadId {squadId}, xuid {xuid.tointeger()}")
  })
}


let function updateActivity() {
  local maxPlayers = 4
  local curPlayers = 1
  let squadId = getCurSquadId()
  if (::g_squad_manager.isInSquad()) {
    maxPlayers = ::g_squad_manager.getMaxSquadSize()
    curPlayers = ::g_squad_manager.getSquadSize()
  }
  let shouldSetActivity = ::g_squad_manager.isSquadLeader() || !::g_squad_manager.isInSquad()
  if (shouldSetActivity) {
    set_activity(squadId, JoinRestriction.InviteOnly, maxPlayers, curPlayers, squadId, function(success) {
      logX($"Set activity succeeded: {success}",
        $"squadId {squadId}, restriction {JoinRestriction.InviteOnly}, maxPlayers {maxPlayers}, curPlayers {curPlayers}")
    })
  }
  else {
    logX("Skip setting activity for regular squad member")
  }
}

let function clearActivity(callback = null) {
  if (!isLoggedIn.value) {
    logX("Not logged in, skip activity clear")
    callback?()
    return
  }

  clear_activity(function(_) {
    logX("Activity cleared")
    callback?()
  })
}


let function onSquadJoin() {
  logX("onSquadJoin")
  clearActivity(updateActivity)
}


let function onSquadLeave() {
  logX("onSquadLeave")
  clearActivity(updateActivity)
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
  clearActivity(updateActivity)
}

let function acceptExistingIngameInvite(uid) {
  let inviteUid = findInviteClass("Squad")?.getUidByParams({ squadId = uid })
  let invite = ::g_invites.findInviteByUid(inviteUid)
  logX($"Accept ingame invite: uid {uid}, invite {invite}")
  if (!invite) {
    logX($"invite not found. Try join squad.")
    ::g_squad_manager.joinToSquad(uid)
    return
  }

  needCheckSquadInvites = true
  invite.checkAutoAcceptXboxInvite()
  broadcastEvent("XboxInviteAccepted")
  needCheckSquadInvites = false
}

let function requestPlayerAndDo(uid, name, cb) {
  let newContact = ::getContact(uid, name)

  if (newContact.needCheckXboxId())
    newContact.updateXboxIdAndDo(Callback(@() cb(newContact.xboxId), this))
  else if (newContact.xboxId != "")
    cb(newContact.xboxId)
}

let function requestXboxPlayerAndDo(xuid, cb) {
  let newContact = ::findContactByXboxId(xuid)
  if (newContact) {
    cb(newContact.uid)
    return
  }

  requestUnknownXboxIds([xuid], {}, Callback(function(res) {
    foreach (uid, data in res) {
      ::getContact(uid, data.nick).update({ xboxId = data.id })
      cb(uid)
    }
  }, this))
}

register_activation_callback(function() {
  let xuid = get_sender_xuid().tostring()
  logX($"onSquadInviteAccept: sender {xuid}")

  if (!::g_login.isLoggedIn() || !isInMenu()) {
    postponedInvitation(xuid)
    logX($"postpone invite accept, while not in menu")
    if (isInFlight()) {
      add_msg_box($"xbox_accept_squad_in_game_{xuid}", loc("xbox/acceptSquadInGame"), [
        ["ok", function() {
            logX("In flight: quit mission")
            ::quit_mission()
          }
        ],
        ["no", @() null]
      ], "ok")
    }

    broadcastEvent("XboxInviteAccepted")
    return
  }

  requestXboxPlayerAndDo(xuid, acceptExistingIngameInvite)
})


addListenersWithoutEnv({
  SquadStatusChanged = @(...) onSquadStatusChanged()
  SquadSizeChanged = @(...) onSquadSizeChange()
  SquadLeadershipTransfered = @(...) onSquadLeadershipTransfer()
  SignOut = @(...) clearActivity()
  LoginComplete  = @(...) updateActivity()
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