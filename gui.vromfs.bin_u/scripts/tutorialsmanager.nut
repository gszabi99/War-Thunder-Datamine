from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { WEAPON_TAG,
        isUnitHaveAnyWeaponsTags } = require("%scripts/weaponry/weaponryInfo.nut")
let { tryOpenNextTutorialHandler } = require("%scripts/tutorials/nextTutorialHandler.nut")

::g_tutorials_manager <- {
  actions = []

  function canAct()
  {
    if (!::isInMenu())
      return false
    if (::isHandlerInScene(::gui_handlers.ShopCheckResearch))
      return false
    return true
  }

  function processActions()
  {
    if (!actions.len() || !canAct())
      return

    while(actions.len())
      if (actions.remove(0)())
        break
  }

  function onEventModalWndDestroy(params)
  {
    processActions()
  }

  function onEventSignOut(p)
  {
    actions.clear()
  }

  function onEventCrewTakeUnit(params)
  {
    let unit = getTblValue("unit", params)
    actions.append((@(unit) function() { return checkTutorialOnSetUnit(unit) })(unit).bindenv(this))
    processActions()
  }

  function checkTutorialOnSetUnit(unit)
  {
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
