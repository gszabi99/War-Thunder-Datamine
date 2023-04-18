//set of functions to make life possible with very poor network messages and events native API
// better to implement it native code and even not at daNetGame but in some gameLib

#explicit-this
#no-root-fallback
let ecs = require("%sqstd/ecs.nut")
let {
  server_send_net_sqevent, server_broadcast_net_sqevent,
  client_request_unicast_net_sqevent, client_request_broadcast_net_sqevent
} = require("ecs.netevent")

let _get_msgSink = ecs.SqQuery("_get_msgSink", { comps_rq = ["msg_sink"] })
let function _get_msg_sink_eid() {
  return _get_msgSink.perform(@(eid, _comp) eid) ?? ecs.INVALID_ENTITY_ID
}

let client_msg_sink = @(evt) client_request_unicast_net_sqevent(_get_msg_sink_eid(), evt)
let server_msg_sink = @(evt, connids = null) server_send_net_sqevent(_get_msg_sink_eid(), evt, connids)

return ecs.__merge({
  client_msg_sink
  client_request_unicast_net_sqevent
  client_request_broadcast_net_sqevent

  server_msg_sink
  server_send_net_sqevent
  server_broadcast_net_sqevent
})
