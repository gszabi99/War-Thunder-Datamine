from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { isInBattleState } = require("%scripts/clientState/clientStates.nut")

::g_user_presence <- {
  inited = false
  currentPresence = {}
  helperObj = {}
}

::g_user_presence.init <- function init()
{
  updateBattlePresence()

  // Call updateClanTagPresence()
  // is not needed as this info comes
  // to client from char-server on login.

  if (!inited)
  {
    inited = true
    ::subscribe_handler(this, ::g_listener_priority.USER_PRESENCE_UPDATE)

    isInBattleState.subscribe(function(isInBattle) {
      updateBattlePresence()
    }.bindenv(this))
  }
}

::g_user_presence.updateBattlePresence <- function updateBattlePresence()
{
  if (isInBattleState.value || ::SessionLobby.isInRoom())
    setBattlePresence("in_game", ::SessionLobby.getRoomEvent())
  else if (::queues.isAnyQueuesActive())
  {
    let queue = ::queues.findQueue({})
    let event = ::events.getEvent(getTblValue("name", queue, null))
    setBattlePresence("in_queue", event)
  }
  else
    setBattlePresence(null)
}

::g_user_presence.setBattlePresence <- function setBattlePresence(presenceName = null, event = null)
{
  if (presenceName == null || event == null)
    setPresence({status = null}) // Sets presence to "Online".
  else
  {
    setPresence({status = {
      [presenceName] = {
        country = ::get_profile_country_sq()
        diff = ::events.getEventDiffCode(event)
        eventId = event.name
      }
    }})
  }
}

::g_user_presence.updateClanTagPresence <- function updateClanTagPresence()
{
  let clanTag = getTblValue("tag", ::my_clan_info, null) || ""
  setPresence({ clanTag = clanTag })
}

::g_user_presence.onEventLobbyStatusChange <- function onEventLobbyStatusChange(params)
{
  updateBattlePresence()
}

::g_user_presence.onEventQueueChangeState <- function onEventQueueChangeState(params)
{
  updateBattlePresence()
}

::g_user_presence.onEventClanInfoUpdate <- function onEventClanInfoUpdate(params)
{
  updateClanTagPresence()
}

::g_user_presence.setPresence <- function setPresence(presence)
{
  if (!::g_login.isLoggedIn() || !checkPresence(presence))
    return

  // Copy new values to current presence object.
  foreach (key, value in presence)
    currentPresence[key] <- value
  ::set_presence(presence)
  ::broadcastEvent("MyPresenceChanged", presence)
}

/**
 * Checks if presence has something new
 * comparing to current presence. Used
 * to skip 'set_presence' call if nothing
 * changed.
 */
::g_user_presence.checkPresence <- function checkPresence(presence)
{
  if (presence == null)
    return false
  helperObj.clear()

  // Selecting only properties that can
  // be inequal with current presence.
  foreach (key, value in presence)
    helperObj[key] <- getTblValue(key, currentPresence)

  return !::u.isEqual(helperObj, presence)
}
