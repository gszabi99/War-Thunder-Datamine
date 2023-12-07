from "%scripts/dagui_library.nut" import *

local disable_autorelogin_once = false

return {
  set_disable_autorelogin_once = @(v) disable_autorelogin_once=v
  get_disable_autorelogin_once = @() disable_autorelogin_once
}
