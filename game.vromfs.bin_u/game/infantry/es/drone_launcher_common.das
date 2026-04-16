module drone_launcher_common shared
require ecs.enum_macro
require ecs
require app


[export_enum]
enum DroneLauncherState
  DLS_OFFLINE 
  DLS_READY 
  DLS_LAUNCH 
  DLS_LAUNCHED 

variant MaybeDroneRespawnBase
  transform : float3x4
  nothing : void?


let DRONE_SPAWN_SPREAD_DIST = 15.0
let DRONE_SPAWN_MAX_RESOLVE_ITERATIONS = 6

struct DroneRespawnBaseInfo
  eid : EntityId
  transform : float3x4
  lastSpawnTime : float


def validate_drone_spawn_pos(var wish_pos : float3&; drone_positions : array<float3>) : bool
  for _i in range(0, DRONE_SPAWN_MAX_RESOLVE_ITERATIONS)
    var is_clear = true
    for pos in drone_positions
      var dist = wish_pos - pos
      dist.y = 0.0
      let len = length(dist)
      if len < DRONE_SPAWN_SPREAD_DIST
        if len > 0.0
          dist *= 1.0 / len
        else
          dist = float3(0.0, 1.0, 0.0)
        wish_pos += dist * ((DRONE_SPAWN_SPREAD_DIST - len) + 1.0)
        is_clear = false
    if is_clear
      return true
  return false


def get_respawn_base_for_drone(soldier_team : int; fast_check : bool = false)
  var bases : array<DroneRespawnBaseInfo>
  query() <| $ [es(REQUIRE=kamikazeRespawn)] (eid : EntityId;
                                              transform : float3x4;
                                              team : int;
                                              active : bool;
                                              lastSpawnTime : float)
    if active && soldier_team == team
      bases |> emplace(DroneRespawnBaseInfo(eid = eid, transform = transform, lastSpawnTime = lastSpawnTime))

  if empty(bases)
    return MaybeDroneRespawnBase(nothing = null)

  if fast_check
    return MaybeDroneRespawnBase(transform = bases[0].transform)

  bases |> sort() <| $(a, b : DroneRespawnBaseInfo)
    return a.lastSpawnTime < b.lastSpawnTime

  var drone_positions : array<float3>
  query() <| $ [es(REQUIRE=isDrone)] (transform : float3x4; isAlive : bool)
    if isAlive
      push(drone_positions, transform[3])

  for base in bases
    var wish_pos = base.transform[3]
    if validate_drone_spawn_pos(wish_pos, drone_positions)
      var result = base.transform
      result[3] = wish_pos
      query(base.eid) <| $ [es] (var lastSpawnTime : float&)
        lastSpawnTime = get_sync_time()
      return MaybeDroneRespawnBase(transform = result)

  return MaybeDroneRespawnBase(nothing = null)
