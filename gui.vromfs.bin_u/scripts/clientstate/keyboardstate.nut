from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

::notify_keyboard_layout_changed <- function notify_keyboard_layout_changed(layout)
{
  ::broadcastEvent("KeyboardLayoutChanged", {layout = layout})
}

::notify_keyboard_locks_changed <- function notify_keyboard_locks_changed(locks)
{
  ::broadcastEvent("KeyboardLocksChanged", {locks = locks})
}
