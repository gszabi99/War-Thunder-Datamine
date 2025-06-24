from "%scripts/dagui_library.nut" import *
from "app" import is_dev_version, exitGame

let { isPlatformSony, isPlatformXbox } = require("%scripts/clientState/platform.nut")
let { startLogout } = require("%scripts/login/logout.nut")

if ((isPlatformSony || isPlatformXbox) && !is_dev_version())
  return startLogout

return exitGame