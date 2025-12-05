module drone_common shared
require ecs.enum_macro
require ecs
require ecs.safe
require DagorMath

[export_enum]
enum DroneType
  Unknown
  Recon
  Kamikaze
  Bombing


def DroneType(v : int)
  if v == int(DroneType.Recon)
    return DroneType.Recon
  elif v == int(DroneType.Kamikaze)
    return DroneType.Kamikaze
  elif v == int(DroneType.Bombing)
    return DroneType.Bombing

  return DroneType.Unknown

def get_controlled_drone_from_owner(eid : EntityId)
  let gunEid = get_Eid(eid, "human_weap__currentGunEid") ?? INVALID_ENTITY_ID
  let droneLauncherEid = get_Eid(gunEid, "tactical_phone__droneLauncher") ?? INVALID_ENTITY_ID
  return get_Eid(droneLauncherEid, "drone_launcher__drone") ?? INVALID_ENTITY_ID
