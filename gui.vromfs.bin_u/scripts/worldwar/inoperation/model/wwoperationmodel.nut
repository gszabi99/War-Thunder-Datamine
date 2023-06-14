//checked for plus_string
from "%scripts/dagui_library.nut" import *


let airfieldTypes = require("%scripts/worldWar/inOperation/model/airfieldTypes.nut")
let { Point2 } = require("dagor.math")

::WwOperationModel <- class {
  armies = null
  unitClassFlyoutRange = null

  maxUniqueUnitsOnFlyout = 0

  constructor() {
    this.armies = ::WwOperationArmies()
    this.maxUniqueUnitsOnFlyout = ::g_world_war.getWWConfigurableValue("maxUniqueUnitsOnFlyout", 0)
  }

  function update() {
    this.armies.statusUpdate()
  }

  function getGroupAirArmiesLimit(airfieldTypeName) {
    foreach (fName, fType in airfieldTypes)
      if (airfieldTypeName == fName)
        return ::g_world_war.getWWConfigurableValue(fType.configurableValue, 0)
    return 0
  }

  function getUnitsFlyoutRange() {
    if (!this.unitClassFlyoutRange)
      this.unitClassFlyoutRange = {
        [WW_UNIT_CLASS.COMBINED] = {
          [WW_UNIT_CLASS.FIGHTER] = Point2(
            ::g_world_war.getWWConfigurableValue("airfieldCreateCombinedArmyFightersMin", 0),
            ::g_world_war.getWWConfigurableValue("airfieldCreateCombinedArmyFightersMax", 0)
          ),
          [WW_UNIT_CLASS.BOMBER] = Point2(
            ::g_world_war.getWWConfigurableValue("airfieldCreateCombinedArmyAttackersMin", 0),
            ::g_world_war.getWWConfigurableValue("airfieldCreateCombinedArmyAttackersMax", 0)
          )
        },
        [WW_UNIT_CLASS.FIGHTER] = {
          [WW_UNIT_CLASS.FIGHTER] = Point2(
            ::g_world_war.getWWConfigurableValue("airfieldCreateFightersArmyMin", 0),
            ::g_world_war.getWWConfigurableValue("airfieldCreateFightersArmyMax", 0)
          )
        },
        [WW_UNIT_CLASS.BOMBER] = {
          [WW_UNIT_CLASS.BOMBER] = Point2(0, 0)
        },
        [WW_UNIT_CLASS.HELICOPTER] = {
          [WW_UNIT_CLASS.HELICOPTER] = Point2(
            ::g_world_war.getWWConfigurableValue("helipadCreateArmyUnitCountMin", 0),
            ::g_world_war.getWWConfigurableValue("helipadCreateArmyUnitCountMax", 0)
          )
        }
      }

    return this.unitClassFlyoutRange
  }

  function getQuantityToFlyOut(bit, mask, range = null) {
    if (!range)
      range = this.getUnitsFlyoutRange()

    if (!(bit & mask) || !(mask in range))
      return Point2(0, 0)
    return range[mask][bit]
  }
}