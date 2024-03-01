from "%scripts/dagui_library.nut" import *

let invitesClasses = {}

function registerInviteClass(key, inviteClass) {
  if (key in invitesClasses) {
    logerr($"[Invites] invitesClasses already has {key} class")
    return
  }
  invitesClasses[key] <- inviteClass
}

let findInviteClass = @(key) invitesClasses?[key]

return {
  registerInviteClass
  findInviteClass
  invitesClasses = freeze(invitesClasses)
}