from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { is_available } = require("%xboxLib/impl/mpa.nut")

if (is_available()) {
  let impl = require("%scripts/social/xboxSquadManager/mpa.nut")
  return { send_invitation = impl.sendInvitation }
} else {
  let impl = require("%scripts/social/xboxSquadManager/mpsd.nut")
  return { send_invitation = impl.send_invitation }
}