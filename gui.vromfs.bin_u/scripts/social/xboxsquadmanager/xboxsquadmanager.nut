from "%scripts/squads/squadState.nut" import getLeaderUid, getMaxSquadSize, getSquadSize, getState, isInSquad, isSquadLeader
from "%scripts/crossModuleEvents.nut" import SQUAD_JOIN_REQUESTED
from "%scripts/contacts/externalContactsService.nut" import requestUnknownXboxIds
from "%scripts/invites/invitesClasses.nut" import findInviteClass
from "%scripts/user/profileStates.nut" import userIdStr
from "%scripts/clientState/clientStates.nut" import isInMenu
from "%scripts/sqDagui/framework/msgBox.nut" import add_msg_box
from "%scripts/hud/startHud.nut" import quitMission
from "%scripts/contacts/contactsListState.nut" import findContactByXboxId
from "%scripts/invites/invites.nut" import findInviteByUid
from "%scripts/gdk/permissions.nut" import check_multiplayer_sessions_privilege
from "%scripts/contacts/contacts.nut" import getContact
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv, broadcastEvent
from "%appGlobals/login/loginState.nut" import isLoggedIn
from "%gdkLib/mpa.nut" import set_activity, clear_activity, send_invitations, JoinRestriction
from "%gdkLib/impl/user.nut" import is_any_user_active
from "gameplayBinding" import isInFlight
from "%scripts/dagui_library.nut" import *
from "%scripts/squads/squadsConsts.nut" import squadState

let logX = require("%sqstd/log.nut")().with_prefix("[MPA_MANAGER] ")

local needCheckSquadInvites = false 
let postponedInvitation = mkHardPersistWatched("social.xboxSquadManager.xboxSquadManager")("postponedInvitation", "0")

let getCurSquadId = @() isInSquad() ? getLeaderUid().tostring() : userIdStr.get()

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
  if (isInSquad()) {
    maxPlayers = getMaxSquadSize()
    curPlayers = getSquadSize()
  }
  let haveUser = is_any_user_active()
  let shouldSetActivity = isSquadLeader() || !isInSquad()
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
  let state = getState()
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
        broadcastEvent(SQUAD_JOIN_REQUESTED, { uid })
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
  let newContact = getContact(uid, name)

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
      getContact(uid, data.nick).update({ xboxId = data.id })
      cb(uid)
    }
  }, this))
}


function onSystemInviteAccept(xuid) {
  logX($"onSquadInviteAccept: sender {xuid}")

  if (!isLoggedIn.get() || !isInMenu.get()) {
    postponedInvitation.set(xuid)
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
  LoginComplete  = @(...) updateActivity()
})

return freeze({
  sendInvitation
  onSystemInviteAccept
  sendSystemInvite = @(uid, name) requestPlayerAndDo(uid, name, sendInvitation)
  needProceedSquadInvitesAccept = @() needCheckSquadInvites
  isPlayerFromXboxSquadList = @(...) true
  checkAfterFlight = @() postponedInvitation.get() == "0"
    ? null
    : requestXboxPlayerAndDo(postponedInvitation.get(), acceptExistingIngameInvite)
})