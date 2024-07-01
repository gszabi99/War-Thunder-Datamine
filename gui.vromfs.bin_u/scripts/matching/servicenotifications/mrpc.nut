from "%scripts/dagui_library.nut" import *

let { matchingRpcSubscribe } = require("%scripts/matching/api.nut")

let notify_subscriptions = {}
let rpc_subscriptions = {}

matchingRpcSubscribe("mrpc.generic_notify",
  @(ev) notify_subscriptions?[ev?.from].each(@(handler) handler(ev)))

matchingRpcSubscribe("mrpc.generic_rpc", function(params, cb) {
  let handlers = rpc_subscriptions?[params?.from]
  if (handlers != null) {
    handlers.each(@(handler) handler(params, cb))
    return
  }

  cb({ error = "unknown service" })
})

function mnSubscribe(from, handler) {
  if (from not in notify_subscriptions)
    notify_subscriptions[from] <- []
  notify_subscriptions[from].append(handler)
}

function mnUnsubscribe(from, handler) {
  if (from not in notify_subscriptions)
    return
  let idx = notify_subscriptions[from].indexof(handler)
  if (idx != null)
    notify_subscriptions[from].remove(idx)
}

function mrSubscribe(from, handler) {
  if (from not in rpc_subscriptions)
    rpc_subscriptions[from] <- []
  rpc_subscriptions[from].append(handler)
}

function mrUnsubscribe(from, handler) {
  if (from not in rpc_subscriptions)
    return
  let idx = rpc_subscriptions[from].indexof(handler)
  if (idx != null)
    rpc_subscriptions[from].remove(idx)
}

return {
  mnSubscribe
  mnUnsubscribe
  mrSubscribe
  mrUnsubscribe
}
