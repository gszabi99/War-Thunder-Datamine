/**
 * This is Actionbar's Wheelmenu configs for gamepad controls (also known as "KillStreaks" menu).
 * Each action used here must have isForWheelMenu() func defined in hudActionBarType.nut, which should return true.
 * Wheelmenu can display up to 8 actions at a time, so actions list is devided to pages, with up to 8 actions per page.
 * New actions should be added either by replacing null values in existing pages, or by adding new pages.
 * To add a new page, add 8 nulls to the end of array, and then replace some nulls with your new actions.
 * Each page buttons order is (cardinal directions): NW, W, SW, NE, E, SE, S, N.
 */

let { EII_SMOKE_GRENADE, EII_SMOKE_SCREEN, EII_ARTILLERY_TARGET, EII_SPECIAL_UNIT,
  EII_MEDICALKIT, EII_TERRAFORM, EII_WINCH, EII_WINCH_ATTACH, EII_WINCH_DETACH,
  EII_EXTINGUISHER, EII_TOOLKIT, EII_REPAIR_BREACHES, EII_SPEED_BOOSTER,
  EII_SUBMARINE_SONAR, EII_TORPEDO_SENSOR,
  EII_AUTO_TURRET, EII_SUPPORT_PLANE, EII_SUPPORT_PLANE_2, EII_STEALTH, EII_LOCK
} = ::require_native("hudActionBarConst")

const ITEMS_PER_PAGE = 8

/******************************* CONFIGS START ********************************/

let cfgMenuTank = [
  // Page #1
    EII_SMOKE_GRENADE,
    EII_SMOKE_SCREEN,
    EII_ARTILLERY_TARGET,
    { type = EII_SPECIAL_UNIT, killStreakTag = "fighter" },
    { type = EII_SPECIAL_UNIT, killStreakTag = "attacker" },
    { type = EII_SPECIAL_UNIT, killStreakTag = "bomber" },
    EII_MEDICALKIT,
    [ EII_WINCH, EII_WINCH_ATTACH, EII_WINCH_DETACH ],
  // Page #2
    EII_TERRAFORM,
    null,
    null,
    EII_AUTO_TURRET,    // Event
    EII_SUPPORT_PLANE,  // Event
    EII_SUPPORT_PLANE_2,
    EII_STEALTH,        // Event
    EII_LOCK,           // Event
    null,
]

let cfgMenuShip = [
  // Page #1
    EII_SMOKE_GRENADE,
    EII_SMOKE_SCREEN,
    EII_ARTILLERY_TARGET,
    EII_EXTINGUISHER,
    EII_TOOLKIT,
    EII_REPAIR_BREACHES,
    [ EII_WINCH, EII_WINCH_ATTACH, EII_WINCH_DETACH ],
    EII_SPEED_BOOSTER,  // Event
  // Page #2
    EII_SUPPORT_PLANE,
    EII_SUPPORT_PLANE_2,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
]

let cfgMenuSubmarine = [
  // Page #1
    null,
    EII_SMOKE_SCREEN,
    null,
    EII_SUBMARINE_SONAR,
    EII_TORPEDO_SENSOR,
    EII_REPAIR_BREACHES,
    null,
    null,
]

let cfgMenuAircraft = [
  // Page #1
    EII_SUPPORT_PLANE,
    EII_SUPPORT_PLANE_2,
    EII_SMOKE_SCREEN,
    null,
    null,
    null,
    null,
    null,
    null,
]

/******************************** CONFIGS END *********************************/

let function getCfgByUnit(unit) {
  return unit?.isTank()       ? cfgMenuTank
       : unit?.isShipOrBoat() ? cfgMenuShip
       : unit?.isAir()        ? cfgMenuAircraft
       : unit?.isSubmarine()  ? cfgMenuSubmarine
       : []
}

let function isActionMatch(cfgItem, action) {
  switch (type(cfgItem)) {
    case "array":
      foreach (c in cfgItem)
        if (isActionMatch(c, action))
          return true
      return false
    case "integer":
      return cfgItem == action?.type
    case "table":
      foreach (k, v in cfgItem)
        if (v != action?[k])
          return false
      return true
  }
  return false
}

let function arrangeStreakWheelActions(unit, actions) {
  let res = getCfgByUnit(unit).map(@(c) c != null ? actions.findvalue(@(a) isActionMatch(c, a)) : null)
  local filledLen = res.reduce(@(lastIdx, a, idx) lastIdx = a != null ? idx : lastIdx, -1) + 1
  let pagesCount = (filledLen + ITEMS_PER_PAGE - 1) / ITEMS_PER_PAGE
  res.resize(pagesCount * ITEMS_PER_PAGE, null)
  foreach (a in actions)
    if (res.indexof(a) == null)
      ::script_net_assert_once("action not mapped", $"Actionbar action type {a?.type} not mapped in wheelmenu")
  return res
}

return {
  arrangeStreakWheelActions
}
