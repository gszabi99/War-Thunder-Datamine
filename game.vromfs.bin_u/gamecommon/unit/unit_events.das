module unit_events shared
require ecs
require dm
require DagorDataBlock
require WTDamageModel


[cpp_event(unicast)]
struct CmdInitComponent
  modelBlk : DataBlock? // not null

[cpp_event(unicast)]
struct EventUnitInitModification
  modEid : EntityId
  modType : string
  blk : DataBlock? // not null

[cpp_event(unicast, with_scheme)]
struct EventUnitRespawn
  atTime : float

[cpp_event(unicast, with_scheme)]
struct EventUnitRepair
{}

[cpp_event(unicast)]
struct EventUnitDoPartDamageOffender
  partId : PartId
  offender : OffenderData
  damage : float
  damageTypeId : int
  chanceMult : float
  chanceMultFire : float
  chanceMultExplFuel : float
  pos : float3
  dir : float3
  allowedDmEffects : int
  damageEvent : DamageToPartEvent?
  seed : int

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
