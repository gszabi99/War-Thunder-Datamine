local psnsm = require("scripts/social/psnSessionManager/psnSessionManagerApi.nut")
local psnNotify = require("sonyLib/notifications.nut")
// local base64 = ::require_native("base64")

local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")
local { isEmpty, copy } = require("sqStdLibs/helpers/u.nut")

local PSN_SESSION_TYPE = {
  SKIRMISH = "skirmish"
  SQUAD = "squad"
}

/*
[sessionId] = {
  sType = [PSN_SESSION_TYPE]
  data = [getSessionData()]
}
*/
local createdSessionData = persist("createdSessionData", @() ::Watched({}))
local dumpSessionData = function(sessionId, sType, pushContextId, sessionData) {
   createdSessionData.update(@(v) v[sessionId] <- {
      sType = sType
      pushContextId = pushContextId
      data = copy(sessionData)
    })
}

// { [PSN_SESSION_TYPE] = data }
local pendingSessions = persist("pendingSessions", @() ::Watched({}))

//[sessionId] = {activityId, isSpectator}
local postponedInvitations = persist("postponedInvitations", @() ::Watched([]))

local getLocalizedTextInfo = function(locIdsArray) {
  local textsData = ::g_localization.getFilledFeedTextByLang(locIdsArray)
  local res = {}
  foreach (block in textsData)
    res[block.abbreviation] <- block.text

  return res
}

local getCustomDataByType = @(sType) sType == PSN_SESSION_TYPE.SKIRMISH
  ? [
      {roomId = ::SessionLobby.roomId}
      {inviterUid = ::my_user_id_str}
      {sType = PSN_SESSION_TYPE.SKIRMISH}
    ]
  : sType == PSN_SESSION_TYPE.SQUAD
    ? [
        {squadId = ::my_user_id_str}
        {leaderId = ::g_squad_manager.getLeaderUid()}
        {sType = PSN_SESSION_TYPE.SQUAD}
      ]
    : []

// TODO: replace with normal base64 encode/decode
// Just in time of psn tests.
local BASE64_SEPARATOR = "/"
local BASE64_GARBAGE = "+"
local encodeDataToBase64Like = function(data) {
  local res = []
  foreach (block in data) {
    foreach (key, val in block)
      res.append(val)
  }

  local base64Str = BASE64_SEPARATOR.join(res)
  local isEq4 = base64Str.len() % 4

  if (isEq4) {
    base64Str = "".concat(base64Str, BASE64_SEPARATOR)
    for (local i = 0; i < (3 - isEq4); i++)
      base64Str = "".concat(base64Str, BASE64_GARBAGE)
  }

  //It is basically string with
  //  '/' is delimiter
  //  '+' is just a garbage for ending %4 length string
  return base64Str
}

local decodeBase64LikeToArray = function(str) {
  local params = str.split(BASE64_SEPARATOR)
  if (params.top().indexof(BASE64_GARBAGE) != null || isEmpty(params.top()))
    params.remove(params.len() - 1)

  local sType = params.top()
  local typeData = getCustomDataByType(sType)

  local parsedData = {}
  foreach (idx, block in typeData)
    foreach (key, val in block)
      parsedData[key] <- params[idx]

  return parsedData
}

local getSessionData = @(sType, pushContextId) sType == PSN_SESSION_TYPE.SKIRMISH
  ? {
      playerSessions = [{
        supportedPlatforms = ["PS4", "PS5"]
        maxPlayers = ::SessionLobby.getMaxMembersCount()
        maxSpectators = 50 //default value by PSN
        joinDisabled = !::SessionLobby.getPublicParam("allowJIP", true) && ::SessionLobby.isRoomInSession //todo update during battle - by allowJip && isInSession
        member = {
          players = [{
            accountId = "me"
            platform = "me"
            pushContexts = [{ pushContextId = pushContextId }]
          }]
        }
        localizedSessionName = {
          defaultLanguage = "en-US"
          localizedText = getLocalizedTextInfo(::SessionLobby.getMissionNameLocIdsArray())
        }
        joinableUserType = "NO_ONE"
        invitableUserType = "LEADER"
        exclusiveLeaderPrivileges = [
          "KICK"
          "UPDATE_JOINABLE_USER_TYPE"
          "UPDATE_INVITABLE_USER_TYPE"
        ]
        swapSupported = !::SessionLobby.isSpectatorSelectLocked
        customData1 = encodeDataToBase64Like(getCustomDataByType(PSN_SESSION_TYPE.SKIRMISH))
        /*customData1 = base64.encodeJson({
          roomId = ::SessionLobby.roomId,
          inviterUid = ::my_user_id_str,
          inviterName = ::my_user_name
          password = ::SessionLobby.password
          key = PSN_SESSION_TYPE.SKIRMISH
        })?.result ?? ""*/
      }]
    }
  : sType == PSN_SESSION_TYPE.SQUAD
  ? {
      playerSessions = [{
        supportedPlatforms = ["PS4", "PS5"]
        maxPlayers = ::g_squad_manager.getMaxSquadSize()
        maxSpectators = 0
        joinDisabled = false
        member = {
          players = [{
            accountId = "me"
            platform = "me"
            pushContexts = [{ pushContextId = pushContextId }]
          }]
        }
        localizedSessionName = {
          defaultLanguage = "en-US"
          localizedText = getLocalizedTextInfo(["ps4/session/squad"])
        }
        joinableUserType = "NO_ONE"
        invitableUserType = "LEADER"
        exclusiveLeaderPrivileges = [
          "KICK"
          "UPDATE_JOINABLE_USER_TYPE"
          "UPDATE_INVITABLE_USER_TYPE"
        ]
        swapSupported = false
        customData1 = encodeDataToBase64Like(getCustomDataByType(PSN_SESSION_TYPE.SQUAD))
      }]
    }
  : {}

local getSessionJoinData = @(pushContextId, isSpectator = false) {
  [isSpectator? "spectators" : "players"] = [{
    accountId = "me"
    platform = "me"
    pushContexts = [{ pushContextId = pushContextId }]
  }]
}

local create = function(sType, saveSessionIdCb) {
  local pushContextId = psnNotify.createPushContext()
  local sessionData = getSessionData(sType, pushContextId)
  pendingSessions.update(@(v) v[sType] <- copy(sessionData))

  psnsm.create(
    pendingSessions.value[sType],
    ::Callback(function(r, err) {
      local sessionId = r?.playerSessions[0].sessionId
      saveSessionIdCb(sessionId, err)

      if (!err && !isEmpty(sessionId)) {
        dumpSessionData(sessionId, sType, pushContextId, pendingSessions.value[sType])
      }

      pendingSessions.update(@(v) delete v[sType])
    }, this)
  )
}

local destroy = function(sType) {
  //Delete all sessions for [sType], anyway, there must be only one
  foreach (sessionId, info in createdSessionData.value)
    if (!isEmpty(sessionId) && info.sType == sType) {
      local sId = sessionId
      psnsm.destroy(
        sId,
        ::Callback(function(r, err) {
          createdSessionData.update(@(v) delete v[sId])
        }, this)
      )
    }
}

local update = function(sessionId, sType) {
  local existSessionInfo = createdSessionData.value?[sessionId]
  local sessionData = getSessionData(sType, existSessionInfo?.pushContextId)
  psnsm.updateInfo(
    sessionId,
    existSessionInfo?.data.playerSessions[0],
    sessionData.playerSessions[0],
    ::Callback(function(r, err) {
      createdSessionData.update(@(v) v[sessionId].data = copy(sessionData))
    }, this)
  )
}

local join = function(sessionId, isSpectator, onFinishCb) {
  local pushContextId = psnNotify.createPushContext()
  local sessionData = getSessionJoinData(pushContextId, isSpectator)
  if (isSpectator)
    psnsm.joinAsSpectator(sessionId, sessionData, pushContextId, onFinishCb)
  else
    psnsm.joinAsPlayer(sessionId, sessionData, pushContextId, onFinishCb)
}

local postponeInvite = @(params) postponedInvitations.update(@(v) v.append(params))

local afterAcceptInviteCb = function(sessionId, pushContextId, r, err) {
  if (err) {
    ::dagor.debug($"[PSGI] accepted PSN invite, error {err}")
    return
  }

  psnsm.list([sessionId], ::Callback(function(r, err) {
    foreach (sessionData in (r?.playerSessions ?? [])) {
      if (sessionData.sessionId != sessionId)
        continue

      local parsedData = decodeBase64LikeToArray(sessionData?.customData1 ?? "")
      if (!parsedData.len())
        continue

      switch (parsedData.sType) {
        case PSN_SESSION_TYPE.SKIRMISH:
          dumpSessionData(sessionId, parsedData.sType, pushContextId, copy(sessionData))
          local contact = ::getContact(parsedData.inviterUid)
          ::g_invites.addSessionRoomInvite(parsedData.roomId, parsedData.inviterUid, contact.name, parsedData?.password ?? "").accept()
          break
        case PSN_SESSION_TYPE.SQUAD:
          dumpSessionData(sessionId, parsedData.sType, pushContextId, copy(sessionData))
          ::g_invites.addInviteToSquad(parsedData.squadId, parsedData.leaderId).checkAutoAcceptInvite()
          break
      }
    }
  }))
}

local proceedInvite = function(p) {
  local sessionId = p?.sessionId ?? ""

  local isInPsnSession = sessionId in createdSessionData.value

  if (u.isEmpty(sessionId) || isInPsnSession)
    return // Most-likely we are joining from PSN Overlay

  if (!::g_login.isLoggedIn() || ::is_in_loading_screen()) {
    ::dagor.debug("[PSGI:PI] delaying PSN invite until logged in and loaded")
    postponeInvite(p)
    return
  }

  if (isInPsnSession) {
    //There is no deactivation, so just do nothing
    ::dagor.debug("[PSGI:PI] stale PSN invite: already joined")
    return
  }

  if (!::isInMenu()) {
    ::dagor.debug("[PSGI:PI] delaying PSN invite until in menu")
    postponeInvite(p)
    ::get_cur_gui_scene().performDelayed(this, function() {
      ::showInfoMsgBox(::loc("msgbox/add_to_squad_after_fight"), "add_to_squad_after_fight")
    })
    return
  }

  join(
    sessionId,
    p?.isSpectator ?? false,
    afterAcceptInviteCb
  )
}

addListenersWithoutEnv({
  SquadStatusChanged = function(p) {
    switch (::g_squad_manager.state) {
      case squadState.IN_SQUAD:
        if (PSN_SESSION_TYPE.SQUAD in pendingSessions.value)
          break

        local sessionId = ::g_squad_manager.getPsnSessionId()
        local isLeader = ::g_squad_manager.isSquadLeader()
        local isInPsnSession = sessionId in createdSessionData.value
        ::dagor.debug($"[PSSM] onEventSquadStatusChanged {::g_squad_manager.state} for {sessionId}")
        ::dagor.debug($"[PSSM] onEventSquadStatusChanged leader: {isLeader}, psnSessions: {createdSessionData.value.len()}")
        ::dagor.debug($"[PSSM] onEventSquadStatusChanged session bound to PSN: {isInPsnSession}")

        if (!isLeader && !isInPsnSession) // Invite accepted on normal relogin
          join(
            sessionId,
            false,
            function(sId, pushContextId, r, err) {
              if (!err)
                dumpSessionData(sId, PSN_SESSION_TYPE.SQUAD, pushContextId, {})
            }
          )
        else if (isLeader && (isEmpty(sessionId) || isEmpty(createdSessionData.value))) {// Squad implicitly created || Autotransfer on login
          create(
            PSN_SESSION_TYPE.SQUAD,
            function(sId, err) {
              if (!err)
                ::g_squad_manager.setPsnSessionId(sId)
              ::g_squad_manager.processDelayedInvitations()
            }
          )
        }
        break

      case squadState.LEAVING:
        destroy(PSN_SESSION_TYPE.SQUAD)
        break
    }
  }
  SquadSizeChanged = function(p) {
    if (!::g_squad_manager.isSquadLeader())
      return

    local sessionId = ::g_squad_manager.getPsnSessionId()
    if (!isEmpty(sessionId))
      update(sessionId, PSN_SESSION_TYPE.SQUAD)
  }
  SquadLeadershipTransfer = function(p) {
    if (!::g_squad_manager.isSquadLeader())
      return

    local newLeaderData = ::g_squad_manager.getMemberData(p?.uid)
    if (!newLeaderData) {
      ::dagor.debug($"PSN: Session Manager: Didn't found any info for new leader {p?.uid}")
      return
    }

    local sessionId = ::g_squad_manager.getPsnSessionId()
    local contact = ::getContact(p.uid)
    contact.updatePSNIdAndDo(function() {
      psnsm.changeLeadership(
      sessionId,
      contact.psnId,
      newLeaderData.platform.toupper(),
      ::Callback(function(r, err) {
        local existSessionInfo = createdSessionData.value?[sessionId]
        local pushContextId = existSessionInfo?.pushContextId
        local sessionData = getSessionData(PSN_SESSION_TYPE.SQUAD, pushContextId)
        dumpSessionData(sessionId, PSN_SESSION_TYPE.SQUAD, pushContextId, sessionData)
      }, this)
    )})
  }
  GameIntentJoinSession = proceedInvite
  MainMenuReturn = function(p) {
    local invites = copy(postponedInvitations.value)
    postponedInvitations([])

    invites.each(@(p) proceedInvite(p))
  }

  GameIntentLaunchActivity = function(p) { }
  GameIntentLaunchMultiplayerActivity = function(p) { }
})
