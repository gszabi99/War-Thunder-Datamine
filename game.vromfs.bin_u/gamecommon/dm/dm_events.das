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
  packedProjPropsId : uint
  pos : float3
  dir : float3
  norm : float3
  distance : float
  piercingShift : float
  collNodeId : int

[cpp_event(unicast, with_scheme)]
struct EventSplashHitEntity
  offender : EntityId
  packedProjPropsId : uint
  splashDamage : float
  shatterDamage : float
  pos : float3
  dir : float3

[cpp_event(unicast, with_scheme)]
struct EventMeleeHitEntity
  offender : EntityId
  packedProjPropsId : uint
  collNodeId : int
  pos : float3
  dir : float3
  damage : float
  isBackstab : bool

[cpp_event(unicast, with_scheme)]
struct EventShatterHitEntity
  offender : EntityId
  packedProjPropsId : uint
  damage : float
  pos : float3
  dir : float3
  collNodeId : int

[cpp_event(unicast)]
struct CmdRestoreHpPart
  hp : float

[event(unicast)]
struct CmdKill
  offender : EntityId
  damageType : uint16
  packedGunPropsId : uint
  shellId : int

[event(unicast)]
struct CmdKillVehicle
  offender : EntityId
