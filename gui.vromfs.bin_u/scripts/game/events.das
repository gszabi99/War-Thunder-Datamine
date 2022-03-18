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

[cpp_event(broadcast)]
struct EventOnPlayerConnected
  userId : uint64

[cpp_event(broadcast)]
struct EventOnPlayerDisconnected
  userId : uint64

[cpp_event(broadcast)]
struct EventOnSessionEnd
  winnerTeam : int

[cpp_event(broadcast)]
struct EventOnPlayerSpawn
  userId : uint64
  unitId: int

[cpp_event(unicast, with_scheme, routing=ROUTING_SERVER_TO_CLIENT, filter=target_entity_conn)]
struct EventFinishAssist
{}

[cpp_event(unicast, with_scheme, routing=ROUTING_SERVER_TO_CLIENT, filter=target_entity_conn)]
struct EventTeamKill
{}

[cpp_event(unicast, with_scheme)]
struct EventGunShot
  noise: float

[cpp_event(unicast)]
struct CmdDisableMove
  uid: int
  name: string

[cpp_event(broadcast, with_scheme)]
struct EventOnSupportUnitSpawn
{}

[cpp_event(broadcast, with_scheme)]
struct EventFlightStart
{}
