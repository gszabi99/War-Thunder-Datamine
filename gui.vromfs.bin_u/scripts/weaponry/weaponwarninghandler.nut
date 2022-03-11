local { saveProfile } = require("scripts/clientState/saveProfile.nut")

class ::gui_handlers.WeaponWarningHandler extends ::gui_handlers.SkipableMsgBox
{
  skipOption = ::USEROPT_SKIP_WEAPON_WARNING
  showCheckBoxBullets = true

  function initScreen()
  {
    base.initScreen()

    local bltCheckBoxObj = scene.findObject("slots-autoweapon")
    if (!::check_obj(bltCheckBoxObj))
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
