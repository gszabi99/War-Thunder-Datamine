from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")
let { subscribeHudEvents, register_hud_callbacks } = require("hudMessages")
let { convertBlk } = require("%sqstd/datablock.nut")

let g_hud_event_manager = {
  subscribers = {}
  eventsStack = [] 

  function init() {
    subscribeHudEvents(this, this.onHudEvent)
    
    register_hud_callbacks({
      function isHintWillBeShown(event_name) {
        return ::g_hud_hints_manager.isHintShowAllowed(event_name, null, {needCheckCountOnly = true})
      }
    })
    this.reset()
  }

  function reset() {
    this.subscribers = {}
  }

  function subscribe(event_name, callback_fn, context = null) {
    let cb = Callback(callback_fn, context)
    if (u.isArray(event_name))
      foreach (evName in event_name)
        this.pushCallback(evName, cb)
    else
      this.pushCallback(event_name, cb)
  }

  function pushCallback(event_name, callback_obj) {
    if (!(event_name in this.subscribers))
      this.subscribers[event_name] <- []

    this.subscribers[event_name].append(callback_obj)
  }

  function onHudEvent(event_name, event_data = {}) {
    if (!(event_name in this.subscribers))
      return

    this.eventsStack.append(event_name)

    let eventSubscribers = this.subscribers[event_name]
    for (local i = eventSubscribers.len() - 1; i >= 0; i--)
      if (!eventSubscribers[i].isValid())
        eventSubscribers.remove(i)

    let data = this.handleData(event_data)
    for (local i = 0; i < eventSubscribers.len(); i++)
      eventSubscribers[i](data)

    this.eventsStack.pop()
  }

  function handleData(data) {
    if (u.isDataBlock(data))
      return convertBlk(data)

    let res = {}
    foreach (paramName, param in data)
      res[paramName] <- param
    return res
  }

  function getCurHudEventName() {
    return this.eventsStack.len() ? this.eventsStack.top() : null
  }
}

return {
  g_hud_event_manager
}