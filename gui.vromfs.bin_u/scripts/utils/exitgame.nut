from "%scripts/dagui_natives.nut" import exit_game
from "%scripts/dagui_library.nut" import *
from "app" import is_dev_version

let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { startLogout } = require("%scripts/login/logout.nut")

if ((isPlatformSony || isPlatformXboxOne) && !is_dev_version())
  return startLogout

return exit_game