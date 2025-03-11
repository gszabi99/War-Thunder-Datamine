module fire_system_events shared
require ecs
require dm
require DagorMath
require WTDamageModel
require DmFire


[cpp_event(unicast)]
struct EventOnStopBurn
  wasBurning : bool

[cpp_event(unicast)]
struct EventStartSingleBurn
  startBurnDesc : StartBurnDesc

[cpp_event(unicast, with_scheme)]
struct EventOnStartSingleBurn
  fireId : int
  fireParamsId : int
  fireFxId : int
  nodeId : int
  offset : float3
  dmgPos : float3

[cpp_event(unicast)]
struct EventOnStopSingleBurn
  fireId : int
  initiatorId : uint

[cpp_event(unicast, with_scheme)]
struct EventOnBurnDamageToPart
  fireId : int
  packedPartId : uint
  fireParamsId : int
  initiatorId : uint
  seed : int
  sph : float4
  atTime : float



[cpp_event(unicast)]
struct EventFireSystemStartBurnWithOffender
  partId : PartId
  fireParamsId : int
  fireFxId : int
  offender : OffenderData

[cpp_event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventFireSystemStartBurnWithOffenderInPos
  partId : PartId
  fireParamsId : int
  fireFxId : int
  offender : OffenderData
  pos : float3

[cpp_event(unicast)]
struct EventFireSystemStartBurning
  offender : OffenderData
  partId : PartId
  sph : float4

[cpp_event(unicast)]
struct EventFireSystemOnStartBurn
  offender : OffenderData


[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventFireSystemNetSync
  isBurning : bool
  data : IntList const?  
