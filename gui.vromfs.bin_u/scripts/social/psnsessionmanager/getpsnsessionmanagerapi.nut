from "%scripts/dagui_library.nut" import *

let { isPlatformSony } = require("%scripts/clientState/platform.nut")

let {
  onPsnInvitation = @(...) null,
  invite = @(...) null,
  checkInvitesAfterFlight = @() null
} = isPlatformSony
  ? (require("%scripts/social/psnSessionManager/psnSessionManagerApi.nut"))
  : null


return {
  onPsnInvitation
  invite
  checkInvitesAfterFlight
}