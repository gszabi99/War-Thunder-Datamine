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
struct CmdApplyPartDamageEffect
  partId : int
  metapartId : int
  offender : OffenderData
  hpFixed : uint16
  prevHpFixed : uint16
  dmEffects : int
  pos : float3
  seed : int