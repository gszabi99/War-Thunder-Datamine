local mkWrap = @(notifyId) function(obj, is_down) {
  if(is_down)
    obj.sendNotify(notifyId)
  return ::RETCODE_HALT
}

class gui_bhv.wrapBroadcast
{
  eventMask = ::EV_JOYSTICK | ::EV_PROCESS_SHORTCUTS

  onShortcutLeft  = mkWrap("wrap_left")
  onShortcutRight = mkWrap("wrap_right")
  onShortcutUp    = mkWrap("wrap_up")
  onShortcutDown  = mkWrap("wrap_down")
}