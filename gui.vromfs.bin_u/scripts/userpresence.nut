from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { isEqual } = require("%sqStdLibs/helpers/u.nut")
let { isInBattleState } = require("%scripts/clientState/clientStates.nut")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { matchingApiFunc } = require("%scripts/matching/api.nut")
let { isInSessionRoom } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")
let { getRoomEvent } = require("%scripts/matchingRooms/sessionLobbyInfo.nut")
let { myClanInfo } = require("%scripts/clans/clanState.nut")

let currentPresence = {}
let helperObj = {}

/**
 * Checks if presence has something new
 * comparing to current presence. Used
 * to skip 'set_presence' call if nothing
 * changed.
 */
function checkPresence(presence) {
  if (presence == null)
    return false
  helperObj.clear()

  // Selecting only properties that can
  // be inequal with current presence.
  foreach (key, _value in presence)
    helperObj[key] <- currentPresence?[key]

  return !isEqual(helperObj, presence)
}

function setUserPresence(presence) {
  if (!isLoggedIn.get() || !checkPresence(presence))
    return

  // Copy new values to current presence object.
  foreach (key, value in presence)
    currentPresence[key] <- value
  matchingApiFunc("mpresence.set_presence", @(_) null, presence)
  broadcastEvent("MyPresenceChanged", presence)
}

function setBattlePresence(presenceName = null, event = null) {
  if (presenceName == null || event == null)
    setUserPresence({ status = null }) // Sets presence to "Online".
  else {
    setUserPresence({ status = {
      [presenceName] = {
        country = profileCountrySq.value
        diff = events.getEventDiffCode(event)
        eventId = event.name
      }
    } })
  }
}

function updateClanTagPresence() {
  let clanTag = myClanInfo.get()?.tag ?? ""
  setUserPresence({ clanTag = clanTag })
}

function updateBattlePresence() {
  if (isInBattleState.value || isInSessionRoom.get())
    setBattlePresence("in_game", getRoomEvent())
  else if (::queues.isAnyQueuesActive()) {
    let queue = ::queues.findQueue({})
    let event = events.getEvent(getTblValue("name", queue, null))
    setBattlePresence("in_queue", event)
  }
  else
    setBattlePresence(null)
}

function initUserPresence() {
  updateBattlePresence()
  // Call updateClanTagPresence()
  // is not needed as this info comes
  // to client from char-server on login.
}

addListenersWithoutEnv({
  LobbyStatusChange           = @(_) updateBattlePresence()
  QueueChangeState            = @(_) updateBattlePresence()
  ClanInfoUpdate              = @(_) updateClanTagPresence()
}, g_listener_priority.USER_PRESENCE_UPDATE)

isInBattleState.subscribe(@(_) updateBattlePresence())

return {
  initUserPresence
  setUserPresence
}
