local platform = require("scripts/clientState/platform.nut")

if (platform.isPlatformPS4)
  return {
    title = "#controls/help/dualshock4"
    blk = "gui/help/controllerDualshock.blk"
    btnBackLocId = "controls/help/dualshock4_btn_share"
  }

return {
  title = "#controls/help/xboxone"
  blk = "gui/help/controllerXboxOne.blk"
  btnBackLocId = "xinp/Select"
}