local psnsm = require("scripts/social/psnGameSessionManager/psnGameSessionManagerApi.nut")
local psnNotify = require("sonyLib/notifications.nut")

local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")
local { isEmpty, copy } = require("sqStdLibs/helpers/u.nut")

local getSessionData = @(pushContextId) {
  gameSessions = [{
    supportedPlatforms = ["PS4", "PS5"]
    maxPlayers = ::SessionLobby.getMaxMembersCount()
    maxSpectators = 50 //default value by PSN
    joinDisabled = !::SessionLobby.getPublicParam("allowJIP", true) && ::SessionLobby.isRoomInSession //todo update during battle - by allowJip && isInSession
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

local getSessionJoinData = function(pushContextId, isSpectator = false) {
  local res = {
    accountId = "me"
    platform = "me"
  }
  if (pushContextId != null)
    res.pushContexts <- [{ pushContextId = pushContextId }]

  return {[isSpectator? "spectators" : "players"] = [res]}
}

local createdSessionData = persist("createdSessionData", @() ::Watched({}))
local dumpSessionData = function(sessionId, pushContextId, sessionData) {
  createdSessionData.update(@(v) v[sessionId] <- {
    pushContextId = pushContextId
    data = copy(sessionData)
  })
}


local pendingSessions = persist("pendingSessions", @() ::Watched({}))


local create = function() {
  local pushContextId = psnNotify.createPushContext()
  local sessionData = getSessionData(pushContextId)
  pendingSessions.update(@(v) v[pushContextId] <- copy(sessionData))

  psnsm.create(
    pendingSessions.value[pushContextId],
    ::Callback(function(r, err) {
      local sessionId = r?.gameSessions[0].sessionId

      if (!err && !isEmpty(sessionId)) {
        ::SessionLobby.setExternalId(sessionId)
        dumpSessionData(sessionId, pushContextId, pendingSessions.value[pushContextId])
      }

      pendingSessions.update(@(v) delete v[pushContextId])
    }, this)
  )
}

local destroy = function() {
  foreach (sessionId, info in createdSessionData.value)
    if (!isEmpty(sessionId)) {
      local sId = sessionId
      psnsm.destroy(
        sId,
        ::Callback(function(r, err) {
          createdSessionData.update(@(v) delete v[sId])
        }, this)
      )
    }
}

local update = function(sessionId) {
  local existSessionInfo = createdSessionData.value?[sessionId]
  local sessionData = getSessionData(existSessionInfo?.pushContextId)
  psnsm.updateInfo(
    sessionId,
    existSessionInfo?.data.gameSessions[0],
    sessionData.gameSessions[0],
    ::Callback(function(r, err) {
      createdSessionData.update(@(v) v[sessionId].data = copy(sessionData))
    }, this)
  )
}

local join = function(sessionId, isSpectator, pushContextId, onFinishCb) {
  local sessionData = getSessionJoinData(pushContextId, isSpectator)
  if (isSpectator)
    psnsm.joinAsSpectator(sessionId, sessionData, pushContextId, onFinishCb)
  else
    psnsm.joinAsPlayer(sessionId, sessionData, pushContextId, onFinishCb)
}

addListenersWithoutEnv({
  RoomJoined = function(p) {
    if (::get_game_mode() != ::GM_SKIRMISH)
      return

    local sessionId = ::SessionLobby.getExternalId()

    if (isEmpty(sessionId) && ::SessionLobby.isRoomOwner)
      create()
    else if (!isEmpty(sessionId)
             && !(sessionId in createdSessionData.value)
             && !(sessionId in pendingSessions.value)) {
      pendingSessions.update(@(v) v[sessionId] <- {})
      join(
        sessionId,
        ::SessionLobby.spectator,
        psnNotify.createPushContext(),
        ::Callback(function(sId, pushContextId, r, err) {
          if (!err)
            dumpSessionData(sId, pushContextId, {})
          pendingSessions.update(@(v) delete v[sId])
        }, this)
      )
    }
  }
  LobbyStatusChange = function(p) {
    if (!::SessionLobby.isInRoom()) {
      destroy()
      return
    }

    if (!::SessionLobby.isRoomOwner)
      return

    local sessionId = ::SessionLobby.getExternalId()
    if (!isEmpty(sessionId) &&
      (!(sessionId in createdSessionData.value) && !(sessionId in pendingSessions.value))
    ) {
      create()
    }
  }
  LobbySettingsChange = function(p) {
    local sessionId = ::SessionLobby.getExternalId()
    if (isEmpty(sessionId) || !::SessionLobby.isInRoom())
      return

    if (::SessionLobby.isRoomOwner)
      update(sessionId)
    else if (!(sessionId in createdSessionData.value) && !(sessionId in pendingSessions.value)) {
      pendingSessions.update(@(v) v[sessionId] <- {})
      join(
        sessionId,
        ::SessionLobby.spectator,
        psnNotify.createPushContext(),
        ::Callback(function(sId, pushContextId, r, err) {
          if (!err)
            dumpSessionData(sId, pushContextId, {})
          pendingSessions.update(@(v) delete v[sId])
        }, this)
      )
    }
  }
})