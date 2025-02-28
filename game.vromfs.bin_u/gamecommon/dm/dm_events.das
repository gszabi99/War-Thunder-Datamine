module dm_events shared
require ecs
require DagorMath

[cpp_event(unicast, with_scheme, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventDamagePartRestored
  packedPartId : uint
  hp : float

[cpp_event(unicast, with_scheme)]
struct EventOnHitEntity
  impactRes : int
  offender : EntityId
  bullet : EntityId
  pos : float3
  dir : float3
  norm : float3
  damage : float
  collNodeId : int
