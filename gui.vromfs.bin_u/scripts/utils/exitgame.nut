let { isPlatformSony } = require("scripts/clientState/platform.nut")
let { startLogout } = require("scripts/login/logout.nut")

if (isPlatformSony && !::is_dev_version)
  return startLogout

return ::exit_game