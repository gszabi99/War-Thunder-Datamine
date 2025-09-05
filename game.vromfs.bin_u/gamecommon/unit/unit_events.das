module unit_events shared
require ecs
require dm
require DagorDataBlock
require WTDamageModel
require Unit


[cpp_event(unicast)]
struct CmdInitComponent
  modelBlk : DataBlock? 
  data : UnitCreationData? 

[cpp_event(unicast)]
struct EventUnitInitModification
  modEid : EntityId
  modType : string
  blk : DataBlock? 

[cpp_event(unicast)]
struct EventUnitDelayedStatusChanged
  isDelayed : bool

[cpp_event(unicast)]
struct EventUnitSpawned
{}

[cpp_event(unicast)]
struct EventUnitBecameDead
{}

[cpp_event(unicast, with_scheme)]
struct EventUnitRespawn
  atTime : float

[cpp_event(unicast, with_scheme)]
struct EventUnitRepair
{}

[cpp_event(unicast)]
struct EventUnitDamage
  partId : PartId
  damage : float
  damageTypeId : int
  prevHpFixed : uint16
  hpFixed : uint16
  offender : OffenderData
  pos : float3
  effectProb : float
  effectProbFire : float
  effectProbExplFuel : float
  seed : int

[cpp_event(unicast)]
struct CmdApplyPartDamageEffect
  partId : PartId
  metapartId : int
  offender : OffenderData
  hpFixed : uint16
  prevHpFixed : uint16
  dmEffects : int
  pos : float3
  seed : int

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT, filter=target_entity_conn)]
struct EventEngineOverheatDamage
  start : bool

[cpp_event(unicast, with_scheme)]
struct CmdMoveCrewOut
  num_alive_members : int

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdWeaponRecalcReloadTime
  weaponId : int
