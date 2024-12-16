from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *

let airfieldTypes = require("%scripts/worldWar/inOperation/model/airfieldTypes.nut")
let { Point2 } = require("dagor.math")
let { WwOperationArmies } = require("wwOperationArmies.nut")
let { getWWConfigurableValue } = require("%scripts/worldWar/worldWarStates.nut")

let WwOperationModel = class {
  armies = null
  unitClassFlyoutRange = null

  maxUniqueUnitsOnFlyout = 0

  constructor() {
    this.armies = WwOperationArmies()
    this.maxUniqueUnitsOnFlyout = getWWConfigurableValue("maxUniqueUnitsOnFlyout", 0)
  }

  function update() {
    this.armies.statusUpdate()
    this.unitClassFlyoutRange = null
    this.maxUniqueUnitsOnFlyout = getWWConfigurableValue("maxUniqueUnitsOnFlyout", 0)
  }

  function getGroupAirArmiesLimit(airfieldTypeName) {
    foreach (fName, fType in airfieldTypes)
      if (airfieldTypeName == fName)
        return getWWConfigurableValue(fType.configurableValue, 0)
    return 0
  }

  function getUnitsFlyoutRange() {
    if (!this.unitClassFlyoutRange)
      this.unitClassFlyoutRange = {
        [WW_UNIT_CLASS.COMBINED] = {
          [WW_UNIT_CLASS.FIGHTER] = Point2(
            getWWConfigurableValue("airfieldCreateCombinedArmyFightersMin", 0),
            getWWConfigurableValue("airfieldCreateCombinedArmyFightersMax", 0)
          ),
          [WW_UNIT_CLASS.BOMBER] = Point2(
            getWWConfigurableValue("airfieldCreateCombinedArmyAttackersMin", 0),
            getWWConfigurableValue("airfieldCreateCombinedArmyAttackersMax", 0)
          )
        },
        [WW_UNIT_CLASS.FIGHTER] = {
          [WW_UNIT_CLASS.FIGHTER] = Point2(
            getWWConfigurableValue("airfieldCreateFightersArmyMin", 0),
            getWWConfigurableValue("airfieldCreateFightersArmyMax", 0)
          )
        },
        [WW_UNIT_CLASS.BOMBER] = {
          [WW_UNIT_CLASS.BOMBER] = Point2(0, 0)
        },
        [WW_UNIT_CLASS.HELICOPTER] = {
          [WW_UNIT_CLASS.HELICOPTER] = Point2(
            getWWConfigurableValue("helipadCreateArmyUnitCountMin", 0),
            getWWConfigurableValue("helipadCreateArmyUnitCountMax", 0)
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

return { WwOperationModel }