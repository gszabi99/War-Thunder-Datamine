local { isEqual } = require("sqStdLibs/helpers/u.nut")
local psn = require("sonyLib/webApi.nut")
local statsd = require("statsd")

local create = @(data, onFinishCb) psn.send(
  psn.sessionManager.create(data),
  function(response, err) {
    ::dagor.debug($"[PSSM] Player Sessions: Create: Response: {::toString(response, 4)}")

    if (err) {
      statsd.send_counter("sq.psn_player_sessions.create", 1,
        {status = "error", request = "create_session", error_code = err.code})
      ::dagor.debug($"[PSSM] Player Sessions: Create: Error: {::toString(err, 4)}")
      ::debugTableData(data, {recursionLevel = 10})
    }

    onFinishCb(response, err)
  }
)

local updateInfo = function(sessionId, curData, newData, onFinishCb) {
  if (isEqual(curData, newData))
    return

  foreach (key, val in curData) {
    if (isEqual(val, newData[key]))
      continue

    local pair = {[key] = newData[key]}
    psn.send(
      psn.sessionManager.update(
        sessionId,
        pair
      ),
      function(response, err) {
        ::dagor.debug($"[PSSM] Player Sessions: Update info: {sessionId}: Pair: {::toString(pair, 4)}")

        if (err) {
          statsd.send_counter("sq.psn_player_sessions.update_session", 1,
            {status = "error", request = "update_session", error_code = err.code})
          ::dagor.debug($"[PSSM] Player Sessions: Update Info: {sessionId}: Error: {::toString(err, 4)}")
        }

        onFinishCb(response, err)
      }
    )
  }
}

local destroy = function(sessionId, onFinishCb = psn.noOpCb) {
  psn.send(
    psn.sessionManager.leave(sessionId),
    function(response, err) {
      ::dagor.debug($"[PSSM] Player Sessions: Destroy: {sessionId}")

      if (err) {
        statsd.send_counter("sq.psn_player_sessions.destroy_session", 1,
          {status = "error", request = "destroy_session", error_code = err.code})
        ::dagor.debug($"[PSSM] Player Sessions: Destroy: {sessionId}: Error receieved: {::toString(err, 4)}")
      }

      onFinishCb(response, err)
    }
  )
}

local joinAsPlayer = function(sessionId, sessionData, pushContextId, onFinishCb = psn.noOpCb) {
  psn.send(
    psn.sessionManager.joinAsPlayer(sessionId, sessionData),
    function(response, err) {
      ::dagor.debug($"[PSSM] Join: As Player: {sessionId}")

      if (err) {
        statsd.send_counter("sq.psn_player_sessions.join_as_player", 1,
          {status = "error", request = "join_as_player", error_code = err.code})
        ::dagor.debug($"[PSSM] Join: As Player: {sessionId}: Error: {::toString(err, 4)}")
        ::debugTableData(sessionData, {recursionLevel = 10})
      }

      onFinishCb(sessionId, pushContextId, response, err)
    }
  )
}

local joinAsSpectator = function(sessionId, sessionData, pushContextId, onFinishCb = psn.noOpCb) {
  psn.send(
    psn.sessionManager.joinAsSpectator(sessionId, sessionData),
    function(response, err) {
      ::dagor.debug($"[PSSM] Join: As Spectator: {sessionId}")

      if (err) {
        statsd.send_counter("sq.psn_player_sessions.join_as_spectator", 1,
          {status = "error", request = "join_as_spectator", error_code = err.code})
        ::dagor.debug($"[PSSM] Join: As Spectator: {sessionId}: Error: {::toString(err, 4)}")
        ::debugTableData(sessionData, {recursionLevel = 10})
      }

      onFinishCb(sessionId, pushContextId, response, err)
    }
  )
}

local invite = function(sessionId, accountId) {
  psn.send(
    psn.sessionManager.invite(sessionId, [accountId]),
    function(response, err) {
      ::dagor.debug($"[PSSM] Invite send: {sessionId} : {accountId}")

      if (err) {
        statsd.send_counter("sq.psn_player_sessions.invite", 1,
          {status = "error", request = "invite", error_code = err.code})
        ::dagor.debug($"[PSSM] Invite send: {sessionId}: {accountId}: Error: {::toString(err, 4)}")
      }
    }
  )
}

local list = function(sessionIds = [], onFinishCb = psn.noOpCb) {
  psn.send(
    psn.sessionManager.list(sessionIds),
    onFinishCb
  )
}

local changeLeadership = function(sessionId, accountId, platform, onFinishCb = psn.noOpCb) {
  psn.send(
    psn.sessionManager.changeLeader(sessionId, accountId, platform)
    function(response, err) {
      ::dagor.debug($"[PSSM] Change leadership: {sessionId} : {accountId} : {platform}")

      if (err) {
        statsd.send_counter("sq.psn_player_sessions.change_leadership", 1,
          {status = "error", request = "change_leadership", error_code = err.code})
        ::dagor.debug($"[PSSM] Change leadership: {sessionId}: {accountId}: {platform}: Error: {::toString(err, 4)}")
      }

      onFinishCb(response, err)
    }
  )
}

return {
  create
  updateInfo
  destroy
  joinAsPlayer
  joinAsSpectator
  invite
  list
  changeLeadership
}
