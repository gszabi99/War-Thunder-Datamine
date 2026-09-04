import "%sqStdLibs/helpers/u.nut" as u
import "%scripts/squads/squadApplications.nut" as squadApplications
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%scripts/dagui_library.nut" import *

let { g_squad_manager } = require("%scripts/squads/squadManager.nut")
let { matchingRpcSubscribe } = require("%scripts/matching/api.nut")
let { userIdStr, userIdInt64 } = require("%scripts/user/profileStates.nut")
let { removeInviteToSquad, addInviteToSquad } = require("%scripts/invites/invites.nut")

matchingRpcSubscribe("msquad.notify_invite", function(params) {
  let replaces = (params?.replaces ?? "").tostring()
  let squad = params?.squad ?? {id = ""}
  let invite = params?.invite
  let leader = params?.leader ?? {id = ""}

  if (invite == null || invite.id.tostring() == userIdStr.get()) {
    if (!u.isEmpty(replaces))
      removeInviteToSquad(replaces)
    addInviteToSquad(squad.id, leader.id.tostring())
  }
  else
    g_squad_manager.addInvitedPlayers(invite.id.tostring())
})

matchingRpcSubscribe("msquad.notify_invite_revoked", function(params) {
  let invite = params?.invite
  let squad = params?.squad ?? {id = ""}
  if (invite == null || invite.id.tostring() == userIdStr.get())
    removeInviteToSquad(squad.id.tostring())
  else
    g_squad_manager.removeInvitedPlayers(invite.id.tostring())
})

matchingRpcSubscribe("msquad.notify_invite_rejected", function(params) {
  let invite = params?.invite ?? {id = ""}
  g_squad_manager.removeInvitedPlayers(invite.id.tostring())
  if (g_squad_manager.getSquadSize(true) == 1)
    g_squad_manager.disbandSquad()
})

matchingRpcSubscribe("msquad.notify_invite_expired", function(params) {
  let invite = params?.invite
  let squad = params?.squad ?? {id = ""}
  if (invite == null || invite.id.tostring() == userIdStr.get())
    removeInviteToSquad(squad.id.tostring())
  else {
    g_squad_manager.removeInvitedPlayers(invite.id.tostring())
    if (g_squad_manager.getSquadSize(true) == 1)
      g_squad_manager.disbandSquad()
  }
})

matchingRpcSubscribe("msquad.notify_member_joined", function(params) {
  let userId = (params?.userId ?? "")
  if (userId != userIdInt64.get() && g_squad_manager.isInSquad()) {
    g_squad_manager.addMember(userId.tostring())
    g_squad_manager.joinSquadChatRoom()
  }
})

matchingRpcSubscribe("msquad.notify_member_leaved", function(params) {
  let userId = (params?.userId ?? "")
  if (userId.tostring() == userIdStr.get())
    g_squad_manager.reset()
  else {
    g_squad_manager.removeMember(userId.tostring())
    if (g_squad_manager.getSquadSize(true) == 1)
      g_squad_manager.disbandSquad()
  }
})

matchingRpcSubscribe("msquad.notify_leader_changed", function(_params) {
  if (g_squad_manager.isInSquad())
    g_squad_manager.requestSquadData(g_squad_manager.onLeadershipTransfered)
})

matchingRpcSubscribe("msquad.notify_disbanded", function(_params) {
  g_squad_manager.reset()
})

matchingRpcSubscribe("msquad.notify_data_changed", function(_params) {
  if (g_squad_manager.isInSquad())
    g_squad_manager.requestSquadData()
})

matchingRpcSubscribe("msquad.notify_member_data_changed", function(params) {
  let userId = (params?.userId ?? "").tostring()
  if (userId != userIdStr.get() && g_squad_manager.isInSquad())
    g_squad_manager.requestMemberData(userId)
})

matchingRpcSubscribe("msquad.notify_member_data_updated", function(params) {
  let userId = (params?.userId ?? "").tostring()
  if (userId != userIdStr.get() && g_squad_manager.isInSquad())
    g_squad_manager.updateMemberData(params)
})

matchingRpcSubscribe("msquad.notify_member_login", function(params) {
  let userId = (params?.userId ?? "").tostring()
  if (userId != userIdStr.get() && g_squad_manager.isInSquad())
    g_squad_manager.setMemberOnlineStatus(userId, true)
})

matchingRpcSubscribe("msquad.notify_member_logout", function(params) {
  let userId = (params?.userId ?? "").tostring()
  if (userId != userIdStr.get() && g_squad_manager.isInSquad())
    g_squad_manager.setMemberOnlineStatus(userId, false)
})

matchingRpcSubscribe("msquad.notify_application", function(params) {
  let replaces = params?.replaces
  let squad = params?.squad
  let applicant = params?.applicant
  let leader = params?.leader

  if (applicant == null || applicant.id == userIdInt64.get()) {
    if (replaces)
      squadApplications.deleteApplication(replaces)
    if (!squad || !leader)
      return
    squadApplications.addApplication(squad.id, leader.id)
  }
  else
    g_squad_manager.addApplication(applicant.id)
})

matchingRpcSubscribe("msquad.notify_application_denied", function(params) {
  let applicant = params?.applicant
  let squad = params?.squad

  if (applicant == null || applicant.id == userIdInt64.get())
    squadApplications.onDeniedApplication(squad?.id, true)
  else
    g_squad_manager.removeApplication(applicant.id)
})

matchingRpcSubscribe("msquad.notify_application_revoked", function(params) {
  let applicant = params?.applicant

  if (!applicant)
    return
  if (!g_squad_manager.isInSquad())
    return
  g_squad_manager.removeApplication(applicant.id)
})

matchingRpcSubscribe("msquad.notify_applications_denied", function(params) {
  let applications = params?.applications

  if (!u.isArray(applications))
    return

  g_squad_manager.removeApplication(applications)
})

matchingRpcSubscribe("msquad.notify_application_accepted", function(_params) {
  g_squad_manager.requestSquadData()
})

matchingRpcSubscribe("msquad.notify_squad_created", function(_params) {
  g_squad_manager.requestSquadData()
})

matchingRpcSubscribe("msquad.on_squad_event", function(p) {
  broadcastEvent(p.eventName, p)
})
