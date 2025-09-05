from "%scripts/dagui_library.nut" import *
from "%scripts/squads/squadsConsts.nut" import squadState

let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let logX = require("%sqstd/log.nut")().with_prefix("[MPA_MANAGER] ")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { set_activity, clear_activity, send_invitations, JoinRestriction } = require("%gdkLib/mpa.nut")
let { is_any_user_active } = require("%gdkLib/impl/user.nut")
let { requestUnknownXboxIds } = require("%scripts/contacts/externalContactsService.nut")
let { findInviteClass } = require("%scripts/invites/invitesClasses.nut")
let { isInFlight } = require("gameplayBinding")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { add_msg_box } = require("%sqDagui/framework/msgBox.nut")
let { quitMission } = require("%scripts/hud/startHud.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")
let { findContactByXboxId } = require("%scripts/contacts/contactsManager.nut")
let { findInviteByUid } = require("%scripts/invites/invites.nut")
let { check_multiplayer_sessions_privilege } = require("%scripts/gdk/permissions.nut")

local needCheckSquadInvites = false 
let postponedInvitation = mkWatched(persist, "postponedInvitation", "0")

let getCurSquadId = @() g_squad_manager.isInSquad() ? g_squad_manager.getLeaderUid().tostring() : userIdStr.get()

function sendInvitation(xuid) {
  if (xuid == "") {
    logX($"Invitation sent: error, xuid is empty string")
    return
  }
  let squadId = getCurSquadId()
  send_invitations(squadId, [xuid.tointeger()], true, function(success) {
    logX($"Invitation sent: {success}, squadId {squadId}, xuid {xuid.tointeger()}")
  })
}


function updateActivity() {
  local maxPlayers = 4
  local curPlayers = 1
  let squadId = getCurSquadId()
  if (g_squad_manager.isInSquad()) {
    maxPlayers = g_squad_manager.getMaxSquadSize()
    curPlayers = g_squad_manager.getSquadSize()
  }
  let haveUser = is_any_user_active()
  let shouldSetActivity = g_squad_manager.isSquadLeader() || !g_squad_manager.isInSquad()
  if (shouldSetActivity && haveUser) {
    set_activity(squadId, JoinRestriction.InviteOnly, maxPlayers, curPlayers, squadId, true, function(success) {
      logX($"Set activity succeeded: {success}",
        $"squadId {squadId}, restriction {JoinRestriction.InviteOnly}, maxPlayers {maxPlayers}, curPlayers {curPlayers}")
    })
  }
  else {
    if (haveUser)
      logX("Skip setting activity for regular squad member")
    else
      logX("There is no active user, skip setting activity")
  }
}

function clearActivity(callback = null) {
  if (!is_any_user_active()) {
    logX("Not logged in, skip activity clear")
    callback?()
    return
  }

  clear_activity(function(_) {
    logX("Activity cleared")
    callback?()
  })
}


function onSquadJoin() {
  logX("onSquadJoin")
  clearActivity(updateActivity)
}


function onSquadLeave() {
  logX("onSquadLeave")
  clearActivity(updateActivity)
}


function onSquadStatusChanged() {
  logX("onSquadStatusChanged")
  let state = g_squad_manager.getState()
  if (state == squadState.IN_SQUAD)
    onSquadJoin()
  else if (squadState.LEAVING == state)
    onSquadLeave()
}


function onSquadSizeChange() {
  logX("onSquadSizeChange")
  updateActivity()
}


function onSquadLeadershipTransfer() {
  logX("onSquadLeadershipTransfer")
  clearActivity(updateActivity)
}

function acceptExistingIngameInvite(uid) {
  check_multiplayer_sessions_privilege(true, function(is_allowed) {
    if (is_allowed) {
      let inviteUid = findInviteClass("Squad")?.getUidByParams({ squadId = uid })
      let invite = findInviteByUid(inviteUid)
      logX($"Accept ingame invite: uid {uid}, invite {invite}")
      if (!invite) {
        logX($"invite not found. Try join squad.")
        g_squad_manager.joinToSquad(uid)
        return
      }

      needCheckSquadInvites = true
      invite.checkAutoAcceptXboxInvite()
      broadcastEvent("XboxInviteAccepted")
      needCheckSquadInvites = false
    }
  })
}

function requestPlayerAndDo(uid, name, cb) {
  let newContact = ::getContact(uid, name)

  if (newContact.needCheckXboxId())
    newContact.updateXboxIdAndDo(Callback(@() cb(newContact.xboxId), this))
  else if (newContact.xboxId != "")
    cb(newContact.xboxId)
}

function requestXboxPlayerAndDo(xuid, cb) {
  let newContact = findContactByXboxId(xuid)
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


function onSystemInviteAccept(xuid) {
  logX($"onSquadInviteAccept: sender {xuid}")

  if (!isLoggedIn.get() || !isInMenu.get()) {
    postponedInvitation(xuid)
    logX($"postpone invite accept, while not in menu")
    if (isInFlight()) {
      add_msg_box($"xbox_accept_squad_in_game_{xuid}", loc("xbox/acceptSquadInGame"), [
        ["ok", function() {
            logX("In flight: quit mission")
            quitMission()
          }
        ],
        ["no", @() null]
      ], "ok")
    }

    broadcastEvent("XboxInviteAccepted")
    return
  }

  requestXboxPlayerAndDo(xuid, acceptExistingIngameInvite)
}


addListenersWithoutEnv({
  SquadStatusChanged = @(...) onSquadStatusChanged()
  SquadSizeChanged = @(...) onSquadSizeChange()
  SquadLeadershipTransfered = @(...) onSquadLeadershipTransfer()
  XboxSignOut = @(...) clearActivity()
  LoginComplete  = @(...) updateActivity()
})

return {
  sendInvitation
  onSystemInviteAccept
  sendSystemInvite = @(uid, name) requestPlayerAndDo(uid, name, sendInvitation)
  needProceedSquadInvitesAccept = @() needCheckSquadInvites
  isPlayerFromXboxSquadList = @(...) true
  checkAfterFlight = @() postponedInvitation.get() == "0"
    ? null
    : requestXboxPlayerAndDo(postponedInvitation.get(), acceptExistingIngameInvite)
}