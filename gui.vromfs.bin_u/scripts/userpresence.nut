from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { isInBattleState } = require("%scripts/clientState/clientStates.nut")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { matchingApiFunc } = require("%scripts/matching/api.nut")
let { isInSessionRoom } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")

::g_user_presence <- {
  inited = false
  currentPresence = {}
  helperObj = {}
}

::g_user_presence.init <- function init() {
  this.updateBattlePresence()

  // Call updateClanTagPresence()
  // is not needed as this info comes
  // to client from char-server on login.

  if (!this.inited) {
    this.inited = true
    subscribe_handler(this, g_listener_priority.USER_PRESENCE_UPDATE)

    isInBattleState.subscribe(function(_isInBattle) {
      this.updateBattlePresence()
    }.bindenv(this))
  }
}

::g_user_presence.updateBattlePresence <- function updateBattlePresence() {
  if (isInBattleState.value || isInSessionRoom.get())
    this.setBattlePresence("in_game", ::SessionLobby.getRoomEvent())
  else if (::queues.isAnyQueuesActive()) {
    let queue = ::queues.findQueue({})
    let event = events.getEvent(getTblValue("name", queue, null))
    this.setBattlePresence("in_queue", event)
  }
  else
    this.setBattlePresence(null)
}

::g_user_presence.setBattlePresence <- function setBattlePresence(presenceName = null, event = null) {
  if (presenceName == null || event == null)
    this.setPresence({ status = null }) // Sets presence to "Online".
  else {
    this.setPresence({ status = {
      [presenceName] = {
        country = profileCountrySq.value
        diff = events.getEventDiffCode(event)
        eventId = event.name
      }
    } })
  }
}

::g_user_presence.updateClanTagPresence <- function updateClanTagPresence() {
  let clanTag = getTblValue("tag", ::my_clan_info, null) || ""
  this.setPresence({ clanTag = clanTag })
}

::g_user_presence.onEventLobbyStatusChange <- function onEventLobbyStatusChange(_params) {
  this.updateBattlePresence()
}

::g_user_presence.onEventQueueChangeState <- function onEventQueueChangeState(_params) {
  this.updateBattlePresence()
}

::g_user_presence.onEventClanInfoUpdate <- function onEventClanInfoUpdate(_params) {
  this.updateClanTagPresence()
}

::g_user_presence.setPresence <- function setPresence(presence) {
  if (!::g_login.isLoggedIn() || !this.checkPresence(presence))
    return

  // Copy new values to current presence object.
  foreach (key, value in presence)
    this.currentPresence[key] <- value
  matchingApiFunc("mpresence.set_presence", @(_) null, presence)
  broadcastEvent("MyPresenceChanged", presence)
}

/**
 * Checks if presence has something new
 * comparing to current presence. Used
 * to skip 'set_presence' call if nothing
 * changed.
 */
::g_user_presence.checkPresence <- function checkPresence(presence) {
  if (presence == null)
    return false
  this.helperObj.clear()

  // Selecting only properties that can
  // be inequal with current presence.
  foreach (key, _value in presence)
    this.helperObj[key] <- getTblValue(key, this.currentPresence)

  return !u.isEqual(this.helperObj, presence)
}
