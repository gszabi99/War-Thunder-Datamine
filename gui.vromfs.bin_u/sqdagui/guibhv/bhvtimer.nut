class gui_bhv.Timer
{
  function onTimer(obj, dt)
  {
    local ud = obj.getUserData()
    if (type(ud) == "instance" || type(ud) == "table")
      ud[obj?.timer_handler_func ?? "onTimer"](obj, dt)
  }

  eventMask = ::EV_TIMER
}
