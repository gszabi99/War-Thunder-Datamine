module drone_launcher_common shared
require ecs.enum_macro
require ecs


[export_enum]
enum DroneLauncherState
  DLS_OFFLINE 
  DLS_READY 
  DLS_LAUNCH 
  DLS_LAUNCHED 

variant MaybeDroneRespawnBase
  transform : float3x4
  nothing : void?


def get_respawn_base_for_drone(solider_team : int)
  var result = MaybeDroneRespawnBase(nothing = null)
  find_query() <| $ [es(REQUIRE=kamikazeRespawn)] (transform aka respawn__transform : float3x4;
                                                   team aka respawn__team : int;
                                                   active : bool)
    if active && solider_team == respawn__team
      result = MaybeDroneRespawnBase(transform = transform)
      return true
    return false
  return result
