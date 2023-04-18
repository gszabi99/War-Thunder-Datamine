//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { startLogout } = require("%scripts/login/logout.nut")

if (isPlatformSony && !::is_dev_version)
  return startLogout

return ::exit_game