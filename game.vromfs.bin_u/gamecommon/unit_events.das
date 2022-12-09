module unit_events shared
require ecs
require DagorDataBlock

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
