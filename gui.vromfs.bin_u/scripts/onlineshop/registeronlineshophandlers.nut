from "%sqstd/platform.nut" import is_gdk
from "%scripts/dagui_natives.nut" import epic_is_running

let { isPlatformSony } = require("%scripts/clientState/platform.nut")

if (isPlatformSony)
  require("%scripts/onlineShop/ps4Shop.nut")
else if (is_gdk)
  require("%scripts/onlineShop/xboxShop.nut")
else if (epic_is_running())
  require("%scripts/onlineShop/epicShop.nut")