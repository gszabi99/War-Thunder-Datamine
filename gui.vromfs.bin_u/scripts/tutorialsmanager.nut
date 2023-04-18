//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { WEAPON_TAG,
        isUnitHaveAnyWeaponsTags } = require("%scripts/weaponry/weaponryInfo.nut")
let { tryOpenNextTutorialHandler } = require("%scripts/tutorials/nextTutorialHandler.nut")

::g_tutorials_manager <- {
  actions = []

  function canAct() {
    if (!::isInMenu())
      return false
    if (::isHandlerInScene(::gui_handlers.ShopCheckResearch))
      return false
    return true
  }

  function processActions() {
    if (!this.actions.len() || !this.canAct())
      return

    while (this.actions.len())
      if (this.actions.remove(0)())
        break
  }

  function onEventModalWndDestroy(_params) {
    this.processActions()
  }

  function onEventSignOut(_p) {
    this.actions.clear()
  }

  function onEventCrewTakeUnit(params) {
    let unit = getTblValue("unit", params)
    this.actions.append((@(unit) function() { return this.checkTutorialOnSetUnit(unit) })(unit).bindenv(this))
    this.processActions()
  }

  function checkTutorialOnSetUnit(unit) {
    if (!unit)
      return false

    if (unit.isTank())
      return tryOpenNextTutorialHandler("lightTank")
    else if (unit.isBoat())
      return tryOpenNextTutorialHandler("boat")
    else if (unit.isShip())
      return tryOpenNextTutorialHandler("ship")
    else if (tryOpenNextTutorialHandler("fighter"))
      return true

    if (::check_aircraft_tags(unit.tags, ["bomberview"]))
      return tryOpenNextTutorialHandler("bomber")
    else if (isUnitHaveAnyWeaponsTags(unit, [WEAPON_TAG.BOMB, WEAPON_TAG.ROCKET]))
      return tryOpenNextTutorialHandler("assaulter")

    return false
  }
}

::subscribe_handler(::g_tutorials_manager, ::g_listener_priority.DEFAULT_HANDLER)
