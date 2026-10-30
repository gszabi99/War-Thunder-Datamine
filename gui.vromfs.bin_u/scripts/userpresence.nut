import "%scripts/g_listener_priority.nut" as g_listener_priority
from "%scripts/clientState/clientStates.nut" import isInBattleState
from "%scripts/user/playerCountry.nut" import profileCountrySq
from "%scripts/matching/api.nut" import matchingApiFunc
from "%scripts/matchingRooms/sessionLobbyState.nut" import isInSessionRoom
from "%scripts/events/eventsState.nut" import getEvent, getEventDiffCode
from "%scripts/matchingRooms/sessionLobbyInfo.nut" import getRoomEvent
from "%scripts/clans/clanState.nut" import myClanInfo
from "%scripts/queue/queueState.nut" import findQueue, isAnyQueuesActive
from "%sqStdLibs/helpers/u.nut" import isEqual
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv, broadcastEvent
from "%appGlobals/login/loginState.nut" import isLoggedIn
from "%scripts/dagui_library.nut" import *

let currentPresence = {}
let helperObj = {}







function checkPresence(presence) {
  if (presence == null)
    return false
  helperObj.clear()

  
  
  foreach (key, _value in presence)
    helperObj[key] <- currentPresence?[key]

  return !isEqual(helperObj, presence)
}

function setUserPresence(presence) {
  if (!isLoggedIn.get() || !checkPresence(presence))
    return

  
  foreach (key, value in presence)
    currentPresence[key] <- value
  matchingApiFunc("mpresence.set_presence", @(_) null, presence)
  broadcastEvent("MyPresenceChanged", presence)
}

function setBattlePresence(presenceName = null, event = null) {
  if (presenceName == null || event == null)
    setUserPresence({ status = null }) 
  else {
    setUserPresence({ status = {
      [presenceName] = {
        country = profileCountrySq.get()
        diff = getEventDiffCode(event)
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
  if (isInBattleState.get() || isInSessionRoom.get())
    setBattlePresence("in_game", getRoomEvent())
  else if (isAnyQueuesActive()) {
    let queue = findQueue({})
    let event = getEvent(queue?.name)
    setBattlePresence("in_queue", event)
  }
  else
    setBattlePresence(null)
}

function initUserPresence() {
  updateBattlePresence()
  
  
  
}

addListenersWithoutEnv({
  LobbyStatusChange           = @(_) updateBattlePresence()
  QueueChangeState            = @(_) updateBattlePresence()
  ClanInfoUpdate              = @(_) updateClanTagPresence()
}, g_listener_priority.USER_PRESENCE_UPDATE)

isInBattleState.subscribe(@(_) updateBattlePresence())

return freeze({
  initUserPresence
  setUserPresence
})
