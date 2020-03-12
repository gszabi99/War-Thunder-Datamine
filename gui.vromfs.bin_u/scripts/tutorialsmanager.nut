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
    local unit = ::getTblValue("unit", params)
    actions.append((@(unit) function() { return checkTutorialOnSetUnit(unit) })(unit).bindenv(this))
    processActions()
  }

  function checkTutorialOnSetUnit(unit)
  {
    if (!unit)
      return false

    if (::isTank(unit))
      return ::gui_start_checkTutorial("lightTank")
    else if (::isShip(unit))
      return ::gui_start_checkTutorial("boat")
    else if (::gui_start_checkTutorial("fighter"))
      return true

    if (::check_aircraft_tags(unit.tags, ["bomberview"]))
      return ::gui_start_checkTutorial("bomber")
    else if (::isAirHaveAnyWeaponsTags(unit, ["bomb", "rocket"]))
      return ::gui_start_checkTutorial("assaulter")

    return false
  }
}

::subscribe_handler(::g_tutorials_manager, ::g_listener_priority.DEFAULT_HANDLER)
