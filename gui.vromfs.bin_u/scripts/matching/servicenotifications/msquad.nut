from "%scripts/dagui_library.nut" import *
import "%scripts/squads/squadApplications.nut" as squadApplications

let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let u = require("%sqStdLibs/helpers/u.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { matchingRpcSubscribe } = require("%scripts/matching/api.nut")
let { userIdStr, userIdInt64 } = require("%scripts/user/profileStates.nut")
let { removeInviteToSquad, addInviteToSquad } = require("%scripts/invites/invites.nut")

matchingRpcSubscribe("msquad.notify_invite", function(params) {
  let replaces = getTblValue("replaces", params, "").tostring()
  let squad = getTblValue("squad", params, null)
  let invite = getTblValue("invite", params, null)
  let leader = getTblValue("leader", params, null)

  if (invite == null || invite.id.tostring() == userIdStr.value) {
    if (!u.isEmpty(replaces))
      removeInviteToSquad(replaces)
    addInviteToSquad(squad.id, leader.id.tostring())
  }
  else
    g_squad_manager.addInvitedPlayers(invite.id.tostring())
})

matchingRpcSubscribe("msquad.notify_invite_revoked", function(params) {
  let invite = getTblValue("invite", params, null)
  let squad = getTblValue("squad", params, null)
  if (invite == null || invite.id.tostring() == userIdStr.value)
    removeInviteToSquad(squad.id.tostring())
  else
    g_squad_manager.removeInvitedPlayers(invite.id.tostring())
})

matchingRpcSubscribe("msquad.notify_invite_rejected", function(params) {
  let invite = getTblValue("invite", params, null)
  g_squad_manager.removeInvitedPlayers(invite.id.tostring())
  if (g_squad_manager.getSquadSize(true) == 1)
    g_squad_manager.disbandSquad()
})

matchingRpcSubscribe("msquad.notify_invite_expired", function(params) {
  let invite = getTblValue("invite", params, null)
  let squad = getTblValue("squad", params, null)
  if (invite == null || invite.id.tostring() == userIdStr.value)
    removeInviteToSquad(squad.id.tostring())
  else {
    g_squad_manager.removeInvitedPlayers(invite.id.tostring())
    if (g_squad_manager.getSquadSize(true) == 1)
      g_squad_manager.disbandSquad()
  }
})

matchingRpcSubscribe("msquad.notify_member_joined", function(params) {
  let userId = getTblValue("userId", params, "")
  if (userId != userIdInt64.value && g_squad_manager.isInSquad()) {
    g_squad_manager.addMember(userId.tostring())
    g_squad_manager.joinSquadChatRoom()
  }
})

matchingRpcSubscribe("msquad.notify_member_leaved", function(params) {
  let userId = getTblValue("userId", params, "")
  if (userId.tostring() == userIdStr.value)
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
  let userId = getTblValue("userId", params, "").tostring()
  if (userId != userIdStr.value && g_squad_manager.isInSquad())
    g_squad_manager.requestMemberData(userId)
})

matchingRpcSubscribe("msquad.notify_member_login", function(params) {
  let userId = getTblValue("userId", params, "").tostring()
  if (userId != userIdStr.value && g_squad_manager.isInSquad())
    g_squad_manager.setMemberOnlineStatus(userId, true)
})

matchingRpcSubscribe("msquad.notify_member_logout", function(params) {
  let userId = getTblValue("userId", params, "").tostring()
  if (userId != userIdStr.value && g_squad_manager.isInSquad())
    g_squad_manager.setMemberOnlineStatus(userId, false)
})

matchingRpcSubscribe("msquad.notify_application", function(params) {
  let replaces = params?.replaces
  let squad = params?.squad
  let applicant = params?.applicant
  let leader = params?.leader

  if (applicant == null || applicant.id == userIdInt64.value) {
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

  if (applicant == null || applicant.id == userIdInt64.value)
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
