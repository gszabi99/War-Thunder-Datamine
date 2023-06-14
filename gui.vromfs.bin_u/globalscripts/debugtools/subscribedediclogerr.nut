from "%globalScripts/logs.nut" import *
import "%globalScripts/ecs.nut" as ecs
let { register_command } = require("console")
let { EventDedicLogerr, mkCmdEnableDedicatedLogger } = require("dedicLogerrSqEvents.nut")

let subscriptions = []

let subscribeDedicLogerr = @(action) subscriptions.append(action)
let onLogerr = @(text) subscriptions.each(@(a) a(text))

let function unsubscribeDedicLogerr(action) {
  let idx = subscriptions.indexof(action)
  if (idx != null)
    subscriptions.remove(idx)
}

let enableDedicLogerr = @(isEnable = true)
  ecs.client_request_broadcast_net_sqevent(mkCmdEnableDedicatedLogger({ isEnable }))

ecs.register_es("dedic_logerr_listener_es",
  {
    [EventDedicLogerr] = @(evt, _eid, _comp) onLogerr(evt?.data.logstring ?? "")
  },
  {})

register_command(@() onLogerr("Some test dedicated logerr happen.\nIt even multiline logerr if you really want to see many lines\nAnd even more lines of the logerr."),
  "debug.dedicLogerrView")

return {
  enableDedicLogerr
  subscribeDedicLogerr
  unsubscribeDedicLogerr
}