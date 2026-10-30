import "DataBlock" as DataBlock
from "%scripts/unit/unitParams.nut" import getFullUnitBlk
from "%scripts/weaponry/dmgModel.nut" import getShipDamageControl
from "%sqstd/math.nut" import round_by_value
from "%scripts/dagui_library.nut" import *

let shipDamageControlDataCache = {}

function gatherShipDamageControlData(unitName) {
  if (unitName in shipDamageControlDataCache)
    return shipDamageControlDataCache[unitName]

  let unitShipDamageControl = getFullUnitBlk(unitName)?.shipDamageControl
  let shipDamageControl = getShipDamageControl()
  let damageControlSets = unitShipDamageControl?.sets ?? shipDamageControl?.sets
  let weights = unitShipDamageControl?.shipboardDamageControlWeight ?? shipDamageControl?.shipboardDamageControlWeight
  let damageControlCoeff = (unitShipDamageControl?.shipDamageControlEnabled ?? false) ? (unitShipDamageControl?.shipDamageControlCoeff ?? 0.0) : 0.0
  let sets = DataBlock()
  if (damageControlSets != null)
    sets.setFrom(damageControlSets)

  shipDamageControlDataCache[unitName] <- {
    sets
    weights = weights != null ?
      [weights.x, weights.y - damageControlCoeff, weights.z - damageControlCoeff].map(@(v) round_by_value(v, 0.01))
      : null
    hasShipDamageControl = damageControlSets != null && weights != null
  }

  return shipDamageControlDataCache[unitName]
}

return freeze({
  gatherShipDamageControlData
  hasShipDamageControl = @(unitName) gatherShipDamageControlData(unitName).hasShipDamageControl
})