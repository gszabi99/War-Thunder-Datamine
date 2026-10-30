from "%sqstd/platform.nut" import isSony, isXbox
from "%scripts/login/logout.nut" import startLogout
from "%scripts/dagui_library.nut" import *
from "app" import is_dev_version, exitGame

if ((isSony || isXbox) && !is_dev_version())
  return startLogout

return exitGame