from "guiOptions" import set_gui_option
from "%scripts/dagui_natives.nut" import get_auto_refill
from "%scripts/dagui_library.nut" import *

let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { SkipableMsgBox } = require("%scripts/wndLib/skipableMsgBox.nut")
let { saveProfile } = require("%scripts/clientState/saveProfile.nut")
let { USEROPT_SKIP_WEAPON_WARNING } = require("%scripts/options/optionsExtNames.nut")

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

return { WeaponWarningHandler }
