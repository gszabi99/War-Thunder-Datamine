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


def refill_drone_launches(soldierEid : EntityId)
  var refilled = false
  query(soldierEid) <| $ [es] (human_weap__gunEids : EidList)
    for gunEid in human_weap__gunEids
      query(gunEid) <| $ [es(REQUIRE=drone_launcher)] (drone_launcher__maxLaunches : int;
                                                       var drone_launcher__launchesRemaining : int&)
        drone_launcher__launchesRemaining = drone_launcher__maxLaunches
        refilled = true
      if refilled
        break
  return refilled


def calc_drone_ew_state(drone_pos : float3; drone_team : int) : tuple<zoneT : float; maxControlLoss : float>
  var zoneT = 0.0
  var maxControlLoss = 0.0
  query() <| $ [es(REQUIRE=fakeEwZone)] (transform aka zone_transform : float3x4;
                                         fake_ew_zone__areaSq : float2;
                                         fake_ew_zone__maxControlLoss : float;
                                         team aka zone_team : int)
    if zone_team == drone_team
      return
    let dSq = distance_sq(drone_pos, zone_transform[3])
    let t = cvt(dSq, fake_ew_zone__areaSq.y, fake_ew_zone__areaSq.x, 0.0, 1.0)
    if t > zoneT
      zoneT = t
      maxControlLoss = fake_ew_zone__maxControlLoss
  return (zoneT = zoneT, maxControlLoss = maxControlLoss)
