from "%scripts/dagui_natives.nut" import get_player_user_id_str
from "%scripts/dagui_library.nut" import *
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

let myUserId = Watched(get_player_user_id_str())

let function updateStates() {
  myUserId(get_player_user_id_str())
}

addListenersWithoutEnv({
  LoginStateChanged = @(_) updateStates()
})

return {
  myUserId
}