from "%scripts/dagui_library.nut" import *
let { getFullUnitBlk, getEsUnitType } = require("%scripts/unit/unitParams.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")

let anyAirVehicle = [ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_HELICOPTER]
let anyWaterVehicle = [ES_UNIT_TYPE_BOAT, ES_UNIT_TYPE_SHIP]

let unitSupportPlaneCache = {}

function findSupportPlaneShip(unitName) {
  let unitBlk = getFullUnitBlk(unitName)
  let supportPlane = unitBlk?.supportPlane
  if (supportPlane == null) {
    unitSupportPlaneCache[unitName] <- null
    return unitSupportPlaneCache[unitName]
  }

  let supportPlaneClass = supportPlane.supportPlaneClass
  let planesCount = supportPlane.count

  local dmPart = null
  let aircrafts = unitBlk?.DamageParts.aircrafts
  if (aircrafts != null) {
    for (local i = 0; i < aircrafts.blockCount(); i++) {
      let blockName = aircrafts.getBlock(i).getBlockName()
      if (blockName.contains("aircraft_")) {
        dmPart = blockName
        break
      }
    }
  }
  unitSupportPlaneCache[unitName] <- {
    name = supportPlaneClass
    isHydroplane = true
    planesCount
    tooltipId = dmPart != null ? getTooltipType("UNIT_DM_TOOLTIP").getTooltipId(unitName, {
      unitId = unitName
      value = "aircraft"
      dmPart
    }) : ""
  }
}

function findSupportPlaneTank(unitName) {
  let unitBlk = getFullUnitBlk(unitName)
  let supportPlaneClass = unitBlk?.supportPlane.supportPlaneClass
  if (supportPlaneClass == null) {
    unitSupportPlaneCache[unitName] <- null
    return unitSupportPlaneCache[unitName]
  }

  unitSupportPlaneCache[unitName] <- {
    name = supportPlaneClass
    tooltipId = getTooltipType("MODIFICATION_DELAYED_TIER").getTooltipId(unitName, "tank_support_ucav" )
  }
}

function getSupportPlane(unitName, unitType) {
  if (unitName in unitSupportPlaneCache)
    return unitSupportPlaneCache[unitName]

  if (anyWaterVehicle.contains(unitType))
    findSupportPlaneShip(unitName)
  else
    findSupportPlaneTank(unitName)

  return unitSupportPlaneCache[unitName]
}

function hasSupportPlane(unitName) {
  let unitType = getEsUnitType(getAircraftByName(unitName))
  if (anyAirVehicle.contains(unitType))
    return false

  return getSupportPlane(unitName, unitType) != null
}

function getUnitSupportPlaneData(unitName) {
  let unitType = getEsUnitType(getAircraftByName(unitName))
  let supportPlaneData = getSupportPlane(unitName, unitType)
  if (supportPlaneData == null)
    return null

  let { name, planesCount = 1, tooltipId, isHydroplane = false } = supportPlaneData
  local itemName = isHydroplane ? $"{loc("armor_class/aircraft")} {loc($"{name}_shop")}"
    : $"{loc("mainmenu/type_drone")} {loc($"{name}_shop")}"

  return {
    itemName
    tooltipId
    planesCount
    isNotLink = tooltipId == ""
  }
}

return {
  hasSupportPlane
  getUnitSupportPlaneData
}
