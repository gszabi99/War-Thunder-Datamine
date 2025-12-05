module vehicle_sounds_net_events shared
require ecs

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdPlayVehicleDamageSound
  hash : uint
  relHp : float
  time : float

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdVehicleHornRequest
  enable : bool
  player : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdPlayProjectileHitSound
  localHitPos : float3
  localNormal : float3
  caliber : float
  bulletTypeId : int
  nodeId : int
  pierced : bool

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdPlayProjectileRicochetSound
  localHitPos : float3
  caliber : float
