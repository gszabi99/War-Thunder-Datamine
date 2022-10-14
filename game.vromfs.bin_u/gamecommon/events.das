module events shared
require ecs
require dm
require %game.unit_events
require %game.dm_events
require %game.repair_system_events
require %game.extinguish_system_events
require %game.ship_events

[cpp_event(unicast)]
struct EventOnStartShooting
  weaponIdx : int

[cpp_event(unicast)]
struct EventOnMetaPartDamage
  damage : uint16

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
  immediately : bool

[cpp_event(unicast)]
struct CmdUnitFxHide
  hide : bool

[cpp_event(unicast)]
struct CmdCameraUpdate
  dt : float
  controlsDt : float

[cpp_event(unicast)]
struct CmdPostPhysUpdate
  tick : int
  dt : float
  isForReal : bool

[cpp_event(broadcast)]
struct EventOnKeyDown
  eventId : int
  dt : float

[cpp_event(broadcast)]
struct EventOnKeyState
  eventId : int
  isDown : bool
  dt : float
  timeMSec : int

[cpp_event(broadcast)]
struct EventOnKeyUp
  eventId : int
  dt : float

[cpp_event(unicast)]
struct EventOnStartBurn
  fireId : int
  fireParamsId : int
  nodeId : int
  offset : float3
  dmgPos : float3

[cpp_event(unicast)]
struct EventOnStopSingleBurn
  fireId : int
  initiatorId : uint

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
  unitId : int

[cpp_event(unicast, with_scheme, routing=ROUTING_SERVER_TO_CLIENT, filter=target_entity_conn)]
struct EventFinishAssist
{}

[cpp_event(unicast, with_scheme, routing=ROUTING_SERVER_TO_CLIENT, filter=target_entity_conn)]
struct EventTeamKill
{}

[cpp_event(unicast, with_scheme)]
struct EventGunShot
  noise : float

[cpp_event(unicast)]
struct CmdDisableMove
  uid : int
  name : string

[cpp_event(broadcast, with_scheme)]
struct EventOnSupportUnitSpawn
{}

[cpp_event(broadcast, with_scheme)]
struct EventFlightStart
{}

[cpp_event(unicast, with_scheme, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventSandUnitDead
{}

[cpp_event(broadcast)]
struct EventOnPlayerModSpend
  userId : uint64
  modName : string
  count : int

[event(broadcast)]
struct MatchingRoomExtraParams
  routeEvaluationChance : float
  ddosSimulationChance : float
  ddosSimulationAddRtt : int

[cpp_event(broadcast, with_scheme)]
struct ChangeServerRoute
  currentIsUnresponsive : bool

[cpp_event(broadcast)]
struct EventOnConnectedToServer {}

[cpp_event(unicast)]
struct CmdForceMusic
  name : das_string

[cpp_event(broadcast)]
struct CmdLockHangarMusic
{}