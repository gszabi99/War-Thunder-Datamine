from "%globalScripts/unitTypeConsts.nut" import *
from "%scripts/weaponry/shellSelectOptions/shellSelectOptions.nut" import mkShellSelectOptions

let threatEsUnitTypes = [ ES_UNIT_TYPE_TANK, ES_UNIT_TYPE_SHIP, ES_UNIT_TYPE_BOAT, ES_UNIT_TYPE_HELICOPTER, ES_UNIT_TYPE_AIRCRAFT ]

const secondaryShellTypes = [
  { shellType = "rocket" }
  { shellType = "bullet", hasBulletParams = true }
  { shellType = "bomb", paramToCheck = "guidanceType", isNamedByWeapon = true }
]

return mkShellSelectOptions({
  getThreatEsUnitTypes = @(_targetUnit) threatEsUnitTypes
  getSecondaryShellTypes = @() secondaryShellTypes
  isReinitNeeded = @(opts) opts.UNIT.value == null
    || opts.UNIT.value != opts.targetUnit
    || (opts.BULLET.value?.bulletName != opts.targetAmmo
      && opts.BULLET.value?.bulletParams.bulletType != opts.targetAmmo)
})
