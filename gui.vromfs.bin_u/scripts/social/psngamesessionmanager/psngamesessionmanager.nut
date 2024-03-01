from "%scripts/dagui_library.nut" import *
let psnsm = require("%scripts/social/psnGameSessionManager/psnGameSessionManagerApi.nut")
let psnNotify = require("%sonyLib/notifications.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isEmpty, copy } = require("%sqStdLibs/helpers/u.nut")
let { get_game_mode } = require("mission")
let { isInSessionRoom, isMeSessionLobbyRoomOwner, isRoomInSession
} = require("%scripts/matchingRooms/sessionLobbyState.nut")

let getSessionData = @(pushContextId) {
  gameSessions = [{
    supportedPlatforms = ["PS4", "PS5"]
    maxPlayers = ::SessionLobby.getMaxMembersCount()
    maxSpectators = 50 //default value by PSN
    joinDisabled = !::SessionLobby.getPublicParam("allowJIP", true) && isRoomInSession.get() //todo update during battle - by allowJip && isInSession
    member = {
      players = [{
        accountId = "me"
        platform = "me"
        joinState = "JOINED"
        pushContexts = [{ pushContextId = pushContextId }]
      }]
    }
    usePlayerSession = false
  }]
}

let getSessionJoinData = function(pushContextId, isSpectator = false) {
  let res = {
    accountId = "me"
    platform = "me"
  }
  if (pushContextId != null)
    res.pushContexts <- [{ pushContextId = pushContextId }]

  return { [isSpectator ? "spectators" : "players"] = [res] }
}

let createdSessionData = mkWatched(persist, "createdSessionData", {})
let dumpSessionData = function(sessionId, pushContextId, sessionData) {
  createdSessionData.mutate(@(v) v[sessionId] <- {
    pushContextId = pushContextId
    data = copy(sessionData)
  })
}


let pendingSessions = mkWatched(persist, "pendingSessions", {})


let create = function() {
  let pushContextId = psnNotify.createPushContext()
  let sessionData = getSessionData(pushContextId)
  pendingSessions.mutate(@(v) v[pushContextId] <- copy(sessionData))

  psnsm.create(
    pendingSessions.value[pushContextId],
    Callback(function(r, err) {
      let sessionId = r?.gameSessions[0].sessionId

      if (!err && !isEmpty(sessionId)) {
        ::SessionLobby.setExternalId(sessionId)
        dumpSessionData(sessionId, pushContextId, pendingSessions.value[pushContextId])
      }
      pendingSessions.mutate(@(v) v?.$rawdelete(pushContextId))
    }, this)
  )
}

let destroy = function() {
  foreach (sessionId, _info in createdSessionData.value)
    if (!isEmpty(sessionId)) {
      let sId = sessionId
      psnsm.destroy(
        sId,
        Callback(function(_r, _err) {
          createdSessionData.mutate(@(v) v?.$rawdelete(sId))
        }, this)
      )
    }
}

function update(sessionId) {
  let existSessionInfo = createdSessionData.value?[sessionId]
  let sessionData = getSessionData(existSessionInfo?.pushContextId)
  psnsm.updateInfo(
    sessionId,
    existSessionInfo?.data.gameSessions[0],
    sessionData.gameSessions[0],
    Callback(function(_r, err) {
      if (err != null || (sessionId not in createdSessionData.value))
        return
      createdSessionData.mutate(@(v) v[sessionId].data = copy(sessionData))
    }, this)
  )
}

let join = function(sessionId, isSpectator, pushContextId, onFinishCb) {
  let sessionData = getSessionJoinData(pushContextId, isSpectator)
  if (isSpectator)
    psnsm.joinAsSpectator(sessionId, sessionData, pushContextId, onFinishCb)
  else
    psnsm.joinAsPlayer(sessionId, sessionData, pushContextId, onFinishCb)
}

addListenersWithoutEnv({
  RoomJoined = function(_p) {
    if (get_game_mode() != GM_SKIRMISH)
      return

    let sessionId = ::SessionLobby.getExternalId()

    if (isEmpty(sessionId) && isMeSessionLobbyRoomOwner.get())
      create()
    else if (!isEmpty(sessionId)
             && !(sessionId in createdSessionData.value)
             && !(sessionId in pendingSessions.value)) {
      pendingSessions.mutate(@(v) v[sessionId] <- {})
      join(
        sessionId,
        ::SessionLobby.getIsSpectator(),
        psnNotify.createPushContext(),
        Callback(function(sId, pushContextId, _r, err) {
          if (!err)
            dumpSessionData(sId, pushContextId, {})
          pendingSessions.mutate(@(v) v?.$rawdelete(sId))
        }, this)
      )
    }
  }
  LobbyStatusChange = function(_p) {
    if (!isInSessionRoom.get()) {
      destroy()
      return
    }

    if (!isMeSessionLobbyRoomOwner.get())
      return

    let sessionId = ::SessionLobby.getExternalId()
    if (!isEmpty(sessionId) &&
      (!(sessionId in createdSessionData.value) && !(sessionId in pendingSessions.value))
    ) {
      create()
    }
  }
  LobbySettingsChange = function(_p) {
    let sessionId = ::SessionLobby.getExternalId()
    if (isEmpty(sessionId) || !isInSessionRoom.get())
      return

    if (isMeSessionLobbyRoomOwner.get())
      update(sessionId)
    else if (!(sessionId in createdSessionData.value) && !(sessionId in pendingSessions.value)) {
      pendingSessions.mutate(@(v) v[sessionId] <- {})
      join(
        sessionId,
        ::SessionLobby.getIsSpectator(),
        psnNotify.createPushContext(),
        Callback(function(sId, pushContextId, _r, err) {
          if (!err)
            dumpSessionData(sId, pushContextId, {})
          pendingSessions.mutate(@(v) v?.$rawdelete(sId))
        }, this)
      )
    }
  }
})