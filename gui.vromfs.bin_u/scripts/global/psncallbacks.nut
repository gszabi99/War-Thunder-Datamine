//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { onPsnInvitation } = require("%scripts/social/psnSessionManager/getPsnSessionManagerApi.nut")

::on_ps4_session_invitation <- onPsnInvitation