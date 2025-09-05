module player_events shared
require ecs


[cpp_event(unicast)]
struct CmdPlayerSetControlledUnit
  toEid : EntityId

[cpp_event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdRequestSwitchControlledUnit
  toEid : EntityId

[cpp_event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdRequestUnitCrewLeaveVehicle
{}

[cpp_event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdRequestUnitCrewEnterVehicle
  vehicleEid : EntityId

[cpp_event(broadcast, with_scheme, cpp_gen=false)]
struct EventPlayerOwnedUnitChanged
  playerId : int
  playerEid : EntityId
  toEid : EntityId
  fromEid : EntityId

[cpp_event(broadcast, with_scheme, cpp_gen=false)]
struct EventPlayerControlledUnitChanged
  playerId : int
  playerEid : EntityId
  toEid : EntityId
  fromEid : EntityId

[cpp_event(unicast)]
struct EventPlayerChangeControlFrom
  playerId : int
  playerEid : EntityId
  isOwned : bool
  fromOwned : bool

[cpp_event(unicast)]
struct EventPlayerChangeControlTo
  playerId : int
  playerEid : EntityId
  isOwned : bool
  toOwned : bool

[cpp_event(unicast)]
struct EventPlayerUnitControlLost
  playerId : int
