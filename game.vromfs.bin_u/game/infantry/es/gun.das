require ecs
require ecs.safe
require DaWeapons
require PhysMat
require %game.events


[es(on_appear)]
def gun_init_proj_ray_mat_es(evt : Event;
                             gun__projectileRayMat : string;
                             var gun__projectileRayMatId : int&)
  gun__projectileRayMatId = get_material_id(gun__projectileRayMat)


[es(on_appear)]
def gun_time_between_shots_on_appear(evt : Event;
                                     gun : Gun;
                                     gun__firingParamsTimeBetweenShotsMults : FloatList;
                                     var gun__originalTimeBetweenShots : float&;
                                     var gun__customMinTimeBetweenShots : float&)
  gun__originalTimeBetweenShots = gun.gunProps.timeBetweenShots

  var minShotFreqMult = 1.0
  for i in range(0, MAX_FIRING_MODES)
    if gun_checkFiringModeIndex(gun, i)
      minShotFreqMult = min(minShotFreqMult, gun_getFiringMode(gun, i).shotFreqMultiplier)

  var minTimeBetweenShotsMult = 1.0
  for mult in gun__firingParamsTimeBetweenShotsMults
    minTimeBetweenShotsMult = min(minTimeBetweenShotsMult, mult)

  gun__customMinTimeBetweenShots = gun.gunProps.timeBetweenShots * minShotFreqMult * minTimeBetweenShotsMult


[es]
def gun_update_time_between_shots(evt : EventShot;
                                  gun__originalTimeBetweenShots : float;
                                  gun__firingParamsTimeBetweenShotsMults : FloatList;
                                  var gun : Gun)
  let burstCounter = int(gun.curState.burstCounter)
  let mult = gun__firingParamsTimeBetweenShotsMults?[burstCounter] ?? 1.0
  gun.gunProps.timeBetweenShots = gun__originalTimeBetweenShots * mult
