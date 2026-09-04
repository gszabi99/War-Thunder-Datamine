from "%sqStdLibs/helpers/net_errors.nut" import script_net_assert_once
from "%scripts/dagui_natives.nut" import get_replay_status, get_replay_version, start_replay
from "%scripts/dagui_library.nut" import *
from "%scripts/webRPC.nut" import webRpcRegister

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

  let startPosition = params?.position ?? 0
  let url = params?.url
  let timeline = !!params?.timeline

  if (!url) {
    script_net_assert_once("null replay url", "NULL replay url in rpc.replay_start params")
    return { status = "error: null url", version = -1 }
  }

  start_replay(startPosition, url, timeline)
  return { status = "processed", version = get_replay_version() }
}

webRpcRegister("replay_status", replay_status)
webRpcRegister("replay_start", replay_start)
