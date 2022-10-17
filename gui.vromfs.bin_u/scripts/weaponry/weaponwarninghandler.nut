from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { saveProfile } = require("%scripts/clientState/saveProfile.nut")

::gui_handlers.WeaponWarningHandler <- class extends ::gui_handlers.SkipableMsgBox
{
  skipOption = ::USEROPT_SKIP_WEAPON_WARNING
  showCheckBoxBullets = true

  function initScreen()
  {
    base.initScreen()

    let bltCheckBoxObj = scene.findObject("slots-autoweapon")
    if (!checkObj(bltCheckBoxObj))
      return

    bltCheckBoxObj.show(showCheckBoxBullets)
    if (showCheckBoxBullets)
      bltCheckBoxObj.setValue(::get_auto_refill(1))
  }

  function skipFunc(value)
  {
    ::set_gui_option(skipOption, value)
    saveProfile()
  }
}
