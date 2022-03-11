local { isPlatformSony } = require("scripts/clientState/platform.nut")
local { startLogout } = require("scripts/login/logout.nut")

if (isPlatformSony && !::is_dev_version)
  return startLogout

return ::exit_game