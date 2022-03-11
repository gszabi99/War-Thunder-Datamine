module events shared
require ecs
require dm

[cpp_event(unicast)]
struct EventOnStartShooting
  weaponIdx: int

[cpp_event(unicast)]
struct EventOnMetaPartDamage
  metapartNo: int
  metapartHp: uint16

[cpp_event(unicast)]
struct EventRepairMetaPart
{}

[cpp_event(unicast)]
struct CmdStopBurn
{}

[cpp_event(unicast)]
struct CmdUpdateRelativeUnitHealth
{}

[cpp_event(unicast)]
struct CmdUnitFxStopAll
  immediately: bool

[cpp_event(unicast)]
struct CmdUnitFxHide
  hide: bool

[cpp_event(unicast)]
struct CmdCameraUpdate
  dt: float
  controlsDt: float

[cpp_event(unicast)]
struct CmdPostPhysUpdate
  tick: int
  dt: float
  isForReal: bool

[cpp_event(broadcast)]
struct EventOnKeyDown
  eventId : int
  dt: float

[cpp_event(broadcast)]
struct EventOnKeyState
  eventId : int
  isDown: bool
  dt: float
  timeMSec: int

[cpp_event(broadcast)]
struct EventOnKeyUp
  eventId : int
  dt: float

[cpp_event(unicast)]
struct EventOnStartBurn
  fireId: int
  fireParamsId: int
  nodeId: int
  offset: float3
  dmgPos: float3

[cpp_event(unicast)]
struct EventOnStopSingleBurn
  fireId: int
  initiatorId: uint
