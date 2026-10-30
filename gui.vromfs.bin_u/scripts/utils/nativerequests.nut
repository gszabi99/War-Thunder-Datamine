from "eventbus" import eventbus_subscribe

function mkNativeResultReceiver(eventName) {
  let callbacks = {}
  eventbus_subscribe(eventName, function(evt) {
    let cb = callbacks.$rawdelete(evt.reqId)
    if (cb != null && !evt?.dropped)
      cb(evt?.result)
  })
  return function(reqId, cb) {
    if (reqId == 0)
      return false
    callbacks[reqId] <- cb
    return true
  }
}

return freeze({
  mkNativeResultReceiver
})
