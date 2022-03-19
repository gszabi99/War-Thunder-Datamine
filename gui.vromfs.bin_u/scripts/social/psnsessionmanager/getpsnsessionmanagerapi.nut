local { isPlatformSony } = require("scripts/clientState/platform.nut")

local {
  getPreferredVersion = @() -1
} = isPlatformSony
  ? require("sonyLib/webApi.nut")
  : null

local {
  onPsnInvitation = @(...) null,
  invite = @(...) null,
  checkInvitesAfterFlight = @() null
} = isPlatformSony
  ? ( getPreferredVersion() == 2
      ? require("scripts/social/psnSessionManager/psnSessionManagerApi.nut")
      : require("scripts/social/psnSessions.nut")
    )
  : null


return {
  onPsnInvitation
  invite
  checkInvitesAfterFlight
}