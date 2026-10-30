from "%sqstd/platform.nut" import isSony
from "%scripts/dagui_library.nut" import *

let {
  invite = @(...) null,
  checkInvitesAfterFlight = @() null
} = isSony
  ? (require("%scripts/social/psnSessionManager/psnSessionManagerApi.nut"))
  : null


return freeze({
  invite
  checkInvitesAfterFlight
})