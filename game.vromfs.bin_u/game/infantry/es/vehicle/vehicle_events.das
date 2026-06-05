module vehicle_events shared
require ecs
require DagorMath

[event(unicast)]
struct CmdAcquireVehicleSeat
  requester : ecs::EntityId
  seat_no : int

[event(unicast)]
struct CmdVehiclePlaceSeat
  eid : EntityId
  seat : int

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct RequestVehicleSeat
  requester : EntityId
  seat_no : int

[event(unicast)]
struct CmdKickFromVehicle
  eid : EntityId

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct RequestKickFromVehicle
  requester : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdHumanForceTeleport
  tm : float3x4

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestKickOtherPlayersFromVehicle {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestLockVehicle
  lock : bool

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventEnterVehicle
  incomer : EntityId
  vehicle : EntityId
  seat_no : int
  enter : bool

[event(unicast)]
struct EventOnSeatOwnersChanged {}

[event(unicast)]
struct CmdHumanSeatBake
  dt : float

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct RequestVehicleChangeSeat
  eid : EntityId
  seat : int

[event(unicast)]
struct CmdVehicleChangeSeat
  eid : EntityId
  seat : int

[event(unicast)]
struct CmdVehiclePlaceDriverSeat
  eid : EntityId

[event(unicast)]
struct CmdVehiclePlaceNextSeat
  eid : EntityId

[event(unicast)]
struct CmdVehicleSwapSeats
  seatNo1 : int
  seatNo2 : int

[event(unicast)]
struct EventSeatsChanged
  seat1 : EntityId
  seat2 : EntityId
