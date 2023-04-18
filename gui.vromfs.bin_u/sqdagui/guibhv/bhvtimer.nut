#explicit-this
#no-root-fallback

::gui_bhv.Timer <- class {
  function onTimer(obj, dt) {
    let ud = obj.getUserData()
    if (type(ud) == "instance" || type(ud) == "table")
      ud[obj?.timer_handler_func ?? "onTimer"](obj, dt)
  }

  eventMask = EV_TIMER
}
