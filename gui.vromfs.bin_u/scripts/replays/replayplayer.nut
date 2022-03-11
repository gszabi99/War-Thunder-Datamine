::replay_status <- function replay_status(params)
{
  return {
    status = ::get_replay_status(),
    version = ::get_replay_version()
  }
}

::replay_start <- function replay_start(params)
{
  local status = ::get_replay_status()
  if (status != "ok")
    return replay_status(null)

  local startPosition = ::getTblValue("position", params) || 0
  local url = ::getTblValue("url", params)
  local timeline = !!::getTblValue("timeline", params)

  if (!url)
  {
    ::script_net_assert_once("null replay url", "NULL replay url in rpc.replay_start params")
    return { status = "error: null url", version = -1 }
  }

  ::start_replay(startPosition, url, timeline)
  return {status = "processed", version = ::get_replay_version()}
}

web_rpc.register_handler("replay_status", replay_status)
web_rpc.register_handler("replay_start", replay_start)
