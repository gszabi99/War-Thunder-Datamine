//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { startLogout } = require("%scripts/login/logout.nut")

if ((isPlatformSony || isPlatformXboxOne) && !::is_dev_version)
  return startLogout

return ::exit_game