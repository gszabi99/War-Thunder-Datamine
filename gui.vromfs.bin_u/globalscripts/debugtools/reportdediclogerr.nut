#explicit-this
#no-root-fallback
from "%globalScripts/logs.nut" import *
import "%globalScripts/ecs.nut" as ecs
let logDL = log_with_prefix("[LOGERR] ")
let { mkEventDedicLogerr, CmdEnableDedicatedLogger } = require("dedicLogerrSqEvents.nut")
let { register_logerr_monitor, clear_logerr_interceptors } = require("dagor.debug")

const INVALID_CONNECTION_ID = -1
local hasPermission = @(_playerId) true

let peersThatWantToReceiveQuery = ecs.SqQuery(
  "peersThatWantToReceiveLogerrsQuery",
  {
    comps_ro = [
      ["connId", ecs.TYPE_INT],
      ["player_id", ecs.TYPE_INT],
      ["receiveLogerr", ecs.TYPE_BOOL]
    ],
    comps_rq = ["m_player"]
  },
  $"and(ne(connId, {INVALID_CONNECTION_ID}), receiveLogerr)")

let getConnidForLogReceiver = @(_eid, comp)
  hasPermission(comp.player_id) ? comp.connId : INVALID_CONNECTION_ID

let function sendErrorToClient(_tag, logstring, _timestamp) {
  let connids = (ecs.query_map(peersThatWantToReceiveQuery, getConnidForLogReceiver) ?? [])
    .filter(@(connId) connId != INVALID_CONNECTION_ID)
  logDL($"send '{logstring}' to {connids.len()} players")
  if (connids.len() != 0)
    ecs.server_broadcast_net_sqevent(mkEventDedicLogerr(({ logstring })), connids)
}

clear_logerr_interceptors()
logDL("register_logerr_monitor")
register_logerr_monitor([""], sendErrorToClient)

ecs.register_es("enable_send_logerr_msg_es", {
    [CmdEnableDedicatedLogger] = function(evt, _eid, comp) {
      if (evt.data?.fromconnid != comp.connId)
        return
      let { isEnable = false } = evt.data
      logDL($"Setting logerr sending to '{isEnable}', for connId:{comp.connId}, player_id:{comp.player_id}")
      comp["receiveLogerr"] = isEnable
    }
  },
  {
    comps_ro = [
      ["connId", ecs.TYPE_INT],
      ["player_id", ecs.TYPE_INT],
    ]
    comps_rq = ["m_player"]
    comps_rw = [["receiveLogerr", ecs.TYPE_BOOL]]
  },
  { tags = "server" }
)

let function init(hasPermissionToReceiveLogerrs) {
  hasPermission = hasPermissionToReceiveLogerrs
}

return init