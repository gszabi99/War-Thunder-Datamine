from "%scripts/dagui_natives.nut" import get_replay_status, get_replay_version, start_replay
from "%scripts/dagui_library.nut" import *
let { web_rpc } = require("%scripts/webRPC.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")


function replay_status(_params) {
  return {
    status = get_replay_status(),
    version = get_replay_version()
  }
}

function replay_start(params) {
  let status = get_replay_status()
  if (status != "ok")
    return replay_status(null)

  let startPosition = getTblValue("position", params) || 0
  let url = getTblValue("url", params)
  let timeline = !!getTblValue("timeline", params)

  if (!url) {
    script_net_assert_once("null replay url", "NULL replay url in rpc.replay_start params")
    return { status = "error: null url", version = -1 }
  }

  start_replay(startPosition, url, timeline)
  return { status = "processed", version = get_replay_version() }
}

web_rpc.register_handler("replay_status", replay_status)
web_rpc.register_handler("replay_start", replay_start)
