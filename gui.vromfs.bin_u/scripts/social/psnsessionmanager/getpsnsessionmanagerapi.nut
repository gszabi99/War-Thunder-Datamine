from "%scripts/dagui_library.nut" import *

let { isPlatformSony } = require("%scripts/clientState/platform.nut")

let {
  invite = @(...) null,
  checkInvitesAfterFlight = @() null
} = isPlatformSony
  ? (require("%scripts/social/psnSessionManager/psnSessionManagerApi.nut"))
  : null


return {
  invite
  checkInvitesAfterFlight
}