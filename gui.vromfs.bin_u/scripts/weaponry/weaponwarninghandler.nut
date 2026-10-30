from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/wndLib/skipableMsgBox.nut" import SkipableMsgBox
from "%scripts/clientState/saveProfile.nut" import saveProfile
from "%scripts/options/optionsExtNames.nut" import USEROPT_SKIP_WEAPON_WARNING
from "guiOptions" import set_gui_option
from "%scripts/dagui_natives.nut" import get_auto_refill
from "%scripts/dagui_library.nut" import *

let WeaponWarningHandler = class (SkipableMsgBox) {
  skipOption = USEROPT_SKIP_WEAPON_WARNING
  showCheckBoxBullets = true

  function initScreen() {
    base.initScreen()

    let bltCheckBoxObj = this.scene.findObject("slots-autoweapon")
    if (!checkObj(bltCheckBoxObj))
      return

    bltCheckBoxObj.show(this.showCheckBoxBullets)
    if (this.showCheckBoxBullets)
      bltCheckBoxObj.setValue(get_auto_refill(1))
  }

  function skipFunc(value) {
    set_gui_option(this.skipOption, value)
    saveProfile()
  }
}
register_gui_handler("WeaponWarningHandler", WeaponWarningHandler)

return freeze({ WeaponWarningHandler })
