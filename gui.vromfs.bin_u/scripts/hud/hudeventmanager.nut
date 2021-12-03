::g_hud_event_manager <-
{
  subscribers = {}
  eventsStack = [] //for debug top event

  function init()
  {
    ::subscribe_hud_events(this, onHudEvent)
    reset()
  }

  function reset()
  {
    subscribers = {}
  }

  function subscribe(event_name, callback_fn, context = null)
  {
    local cb = Callback(callback_fn, context)
    if (::u.isArray(event_name))
      foreach (evName in event_name)
        pushCallback(evName, cb)
    else
      pushCallback(event_name, cb)
  }

  function pushCallback(event_name, callback_obj)
  {
    if (!(event_name in subscribers))
      subscribers[event_name] <- []

    subscribers[event_name].append(callback_obj)
  }

  function onHudEvent(event_name, event_data = {})
  {
    if (!(event_name in subscribers))
      return

    eventsStack.append(event_name)

    local eventSubscribers = subscribers[event_name]
    for (local i = eventSubscribers.len() - 1; i >= 0; i--)
      if (!eventSubscribers[i].isValid())
        eventSubscribers.remove(i)

    local data = handleData(event_data)
    for (local i = 0; i < eventSubscribers.len(); i++)
      eventSubscribers[i](data)

    eventsStack.pop()
  }

  function handleData(data)
  {
    if (::u.isDataBlock(data))
      return ::buildTableFromBlk(data)

    local res = {}
    foreach(paramName, param in data)
      res[paramName] <- param
    return res
  }

  function getCurHudEventName()
  {
    return eventsStack.len() ? eventsStack.top() : null
  }
}

::cross_call_api.onHudEvent <- @(event_name, event_data = {}) ::g_hud_event_manager.onHudEvent(event_name, event_data)
