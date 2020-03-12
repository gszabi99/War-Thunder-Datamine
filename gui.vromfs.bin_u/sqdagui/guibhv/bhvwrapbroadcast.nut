class gui_bhv.wrapBroadcast
{
  eventMask = ::EV_JOYSTICK | ::EV_PROCESS_SHORTCUTS

  function onShortcutLeft(obj, is_down)
  {
    if(is_down)
      obj.sendNotify("wrap_left")
    return ::RETCODE_HALT
  }

  function onShortcutRight(obj, is_down)
  {
    if(is_down)
      obj.sendNotify("wrap_right")
    return ::RETCODE_HALT
  }

  function onShortcutUp(obj, is_down)
  {
    if (is_down)
      obj.sendNotify("wrap_up")
    return ::RETCODE_HALT
  }

  function onShortcutDown(obj, is_down)
  {
    if (is_down)
      obj.sendNotify("wrap_down")
    return ::RETCODE_HALT
  }
}