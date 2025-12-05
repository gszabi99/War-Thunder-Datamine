require ecs
require DaWeapons

[es(track=gun__firingModeIndex)]
def gun_update_time_between_shots_es(evt : Event;
                                     gun : Gun;
                                     gun__firingModeIndex : int;
                                     gun__firingModes : Array;
                                     var gun__timeBetweenShots : float&)
  let gunModesSize = length(gun__firingModes)
  if gunModesSize == 0 || gun__firingModeIndex >= gunModesSize
    return

  let modeObj = get_ecs_object(gun__firingModes[gun__firingModeIndex])
  if modeObj == null
    return

  assume gunProps = gun.gunProps
  gun__timeBetweenShots = gunProps.timeBetweenShots * (get_float(*modeObj, "shotFreqMult") ?? 1.0)