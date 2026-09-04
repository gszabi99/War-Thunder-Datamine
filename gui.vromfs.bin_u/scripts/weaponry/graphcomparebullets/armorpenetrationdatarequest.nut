from "unitCalculcation" import buildArmorPenetrationData
from "%globalScripts/unitTypeConsts.nut" import *

const DEFAULT_MAX_DISTANCE = 2000.0
let maxDistanceByEsUnitType = {
  [ES_UNIT_TYPE_SHIP] = 15000.0,
  [ES_UNIT_TYPE_BOAT] = 15000.0,
}

let getMaxDistance = @(esUnitType) maxDistanceByEsUnitType?[esUnitType] ?? DEFAULT_MAX_DISTANCE

function requestArmorPenetrationData(bullet, _settings, handlerCb) {
  let { weaponBlkName, bulletName, esUnitType } = bullet
  let cb = @(penetrationData) handlerCb({ weaponBlkName, bulletName, penetrationData })
  buildArmorPenetrationData(weaponBlkName, bulletName, getMaxDistance(esUnitType), cb)
}

return {
  requestArmorPenetrationData
}
