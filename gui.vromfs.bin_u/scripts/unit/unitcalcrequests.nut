import "unitCalculcation" as unitCalc
from "%scripts/utils/nativeRequests.nut" import mkNativeResultReceiver

const RESULT_EVENT = "unitCalcResult"
let onResult = mkNativeResultReceiver(RESULT_EVENT)

return freeze({
  calculateModOrWeaponEffect = @(unitName, modOrWeaponName, isMod, cb)
    onResult(unitCalc.calculate_mod_or_weapon_effect(unitName, modOrWeaponName, isMod, RESULT_EVENT), cb)
  calculateModOrWeaponEffectWithLevel = @(unitName, modName, level, isMod, cb)
    onResult(unitCalc.calculate_mod_or_weapon_effect_with_level(unitName, modName, level, isMod, RESULT_EVENT), cb)
  calculateMinAndMaxParameters = @(unitName, cb)
    onResult(unitCalc.calculate_min_and_max_parameters(unitName, RESULT_EVENT), cb)
  calculateTankParameters = @(unitName, cb)
    onResult(unitCalc.calculate_tank_parameters_async(unitName, RESULT_EVENT), cb)
  calculateShipParameters = @(unitName, cb)
    onResult(unitCalc.calculate_ship_parameters_async(unitName, RESULT_EVENT), cb)
  buildBallisticTrajectoryRangeData = @(weaponBlkName, bulletName, targetRange, cb)
    onResult(unitCalc.buildBallisticTrajectoryRangeData(weaponBlkName, bulletName, targetRange, RESULT_EVENT), cb)
  buildBallisticTrajectoryAngleData = @(weaponBlkName, bulletName, startAngle, cb)
    onResult(unitCalc.buildBallisticTrajectoryAngleData(weaponBlkName, bulletName, startAngle, RESULT_EVENT), cb)
  buildMissileTrajectoryData = @(weaponBlkName, bulletName, carrierPos, targetPos, carrierVel, targetVel, cb)
    onResult(unitCalc.buildMissileTrajectoryData(weaponBlkName, bulletName,
      carrierPos, targetPos, carrierVel, targetVel, RESULT_EVENT), cb)
  buildArmorPenetrationData = @(weaponBlkName, bulletName, maxDist, cb)
    onResult(unitCalc.buildArmorPenetrationData(weaponBlkName, bulletName, maxDist, RESULT_EVENT), cb)
})
