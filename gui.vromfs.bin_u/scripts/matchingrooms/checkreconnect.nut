//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { showMsgboxIfEacInactive } = require("%scripts/penitentiary/antiCheat.nut")
let { showMsgboxIfSoundModsNotAllowed } = require("%scripts/penitentiary/soundMods.nut")
let { isMeBanned } = require("%scripts/penitentiary/penalties.nut")
let { isInBattleState } = require("%scripts/clientState/clientStates.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

let isReconnectChecking = persist("isReconnectChecking", @() Watched(false))

let function reconnect(roomId, gameModeName) {
  let event = ::events.getEvent(gameModeName)
  if (!showMsgboxIfEacInactive(event) || !showMsgboxIfSoundModsNotAllowed(event))
    return

  ::SessionLobby.joinRoom(roomId)
}

let function onCheckReconnect(response) {
  isReconnectChecking(false)

  let roomId = response?.roomId
  let gameModeName = response?.game_mode_name
  if (!roomId || !gameModeName)
    return

  ::scene_msg_box("backToBattle_dialog", null, loc("msgbox/return_to_battle_session"), [
    ["yes", @() reconnect(roomId, gameModeName)],
    ["no"]], "yes")
}

let function checkReconnect() {
  if (isReconnectChecking.value || !::g_login.isLoggedIn() || isInBattleState.value || isMeBanned())
    return

  isReconnectChecking(true)
  ::matching_api_func("match.check_reconnect", onCheckReconnect)
}

addListenersWithoutEnv({
  MatchingConnect = @(_) checkReconnect()
})

return checkReconnect