import "%sonyLib/webApi.nut" as psn
import "statsd" as statsd
from "%sqStdLibs/helpers/u.nut" import isEqual
from "dagor.debug" import debug_dump_stack
from "%scripts/dagui_library.nut" import *

let create = @(data, onFinishCb) psn.send(
  psn.gameSessionManager.create(data),
  function(response, err) {
    log($"[PSGSM] Game Sessions: Create: Response: {toString(response, 4)}")

    if (err) {
      statsd.send_counter("sq.psn_game_sessions.create", 1,
        { status = "error", request = "create_session", error_code = err.code })
      log($"[PSGSM] Game Sessions: Create: Error: {toString(err, 4)}")
      debugTableData(data, { recursionLevel = 10 })
    }

    onFinishCb(response, err)
  }
)

let updateInfo = function(sessionId, curData, newData, onFinishCb) {
  if (isEqual(curData, newData))
    return

  foreach (key, val in (curData ?? newData)) {
    if (curData != null && isEqual(val, newData[key]))
      continue

    let pair = { [key] = newData[key] }
    psn.send(
      psn.gameSessionManager.update(
        sessionId,
        pair
      ),
      function(response, err) {
        log($"[PSGSM] Game Sessions: Update info: {sessionId}: Pair: {toString(pair, 4)}")

        if (err) {
          statsd.send_counter("sq.psn_game_sessions.update_session", 1,
            { status = "error", request = "update_session", error_code = err.code })
          log($"[PSGSM] Game Sessions: Update Info: {sessionId}: Error: {toString(err, 4)}")
        }

        onFinishCb(response, err)
      }
    )
  }
}

let destroy = function(sessionId, onFinishCb = psn.noOpCb) {
  psn.send(
    psn.gameSessionManager.leave(sessionId),
    function(response, err) {
      log($"[PSGSM] Game Sessions: Destroy: {sessionId}")

      if (err) {
        statsd.send_counter("sq.psn_game_sessions.destroy_session", 1,
          { status = "error", request = "destroy_session", error_code = err.code })
        log($"[PSGSM] Game Sessions: Destroy: {sessionId}: Error receieved: {toString(err, 4)}")
      }

      onFinishCb(response, err)
    }
  )
}

let joinAsPlayer = function(sessionId, sessionData, pushContextId, onFinishCb = psn.noOpCb) {
  psn.send(
    psn.gameSessionManager.joinAsPlayer(sessionId, sessionData),
    function(response, err) {
      log($"[PSGSM] Join: As Player: {sessionId}")
      debug_dump_stack()
      if (err) {
        statsd.send_counter("sq.psn_game_sessions.join_as_player", 1,
          { status = "error", request = "join_as_player", error_code = err.code })
        log($"[PSGSM] Join: As Player: {sessionId}: Error: {toString(err, 4)}")
        debugTableData(sessionData, { recursionLevel = 10 })
      }

      onFinishCb(sessionId, pushContextId, response, err)
    }
  )
}

let joinAsSpectator = function(sessionId, sessionData, pushContextId, onFinishCb = psn.noOpCb) {
  psn.send(
    psn.gameSessionManager.joinAsSpectator(sessionId, sessionData),
    function(response, err) {
      log($"[PSGSM] Join: As Spectator: {sessionId}")
      debug_dump_stack()
      if (err) {
        statsd.send_counter("sq.psn_game_sessions.join_as_spectator", 1,
          { status = "error", request = "join_as_spectator", error_code = err.code })
        log($"[PSGSM] Join: As Spectator: {sessionId}: Error: {toString(err, 4)}")
        debugTableData(sessionData, { recursionLevel = 10 })
      }

      onFinishCb(sessionId, pushContextId, response, err)
    }
  )
}

return {
  create
  updateInfo
  destroy
  joinAsPlayer
  joinAsSpectator
}