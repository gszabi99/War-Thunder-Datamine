require ecs
require %game.player_events

[es(tag=server)]
def drone_handle_switch_request_server(evt : CmdRequestSwitchControlledUnit; eid : EntityId)
  query(evt.toEid) <| $ [es(REQUIRE=isDrone)] (ownedByPlr : EntityId; isAlive : bool)
    if ownedByPlr != eid 
      return
    if !isAlive 
      return
    sendEventImmediate(eid, CmdPlayerSetControlledUnit(toEid = evt.toEid))


[es(tag=server, REQUIRE=isDrone)]
def drone_switch_on_control_lost(evt : EventPlayerUnitControlLost; possessedByPlr : EntityId; var ownedByPlr : EntityId&; drone__owner : EntityId)
  sendEventImmediate(possessedByPlr, CmdRequestSwitchControlledUnit(toEid = drone__owner))
  ownedByPlr = INVALID_ENTITY_ID


[es(tag=gameClient, REQUIRE=(isDrone, controlledHero), on_appear)]
def drone_acquire_controls_client(evt : Event; drone__launcherEid : EntityId)
  query(drone__launcherEid) <| $ [es] (var drone_launcher__droneControlsAcquired : bool&)
    drone_launcher__droneControlsAcquired = true


[es(tag=gameClient, REQUIRE=(isDrone, controlledHero), on_disappear)]
def drone_release_controls_client(evt : Event; drone__launcherEid : EntityId)
  query(drone__launcherEid) <| $ [es] (var drone_launcher__droneControlsAcquired : bool&)
    drone_launcher__droneControlsAcquired = false













[es(on_event=CmdDroneAcquireControls, REQUIRE=isDrone)]
def drone_acquire_controls(evt : Event;
                           eid : EntityId;
                           ownedByPlr : EntityId)
  sendEvent(ownedByPlr, CmdRequestSwitchControlledUnit(toEid = eid))

[es(tag=server, on_appear, REQUIRE=isDrone)]
def drone_acquire_controls_on_drone_creation_es(evt : Event;
                                                eid : EntityId;
                                                ownedByPlr : EntityId)
  sendEvent(ownedByPlr, CmdRequestSwitchControlledUnit(toEid = eid))

[es(on_event=CmdDroneReleaseControls, REQUIRE=isDrone)]
def drone_release_controls(evt : Event;
                           ownedByPlr : EntityId;
                           drone__owner : EntityId;
                           possessedByPlr : EntityId)
  if possessedByPlr == INVALID_ENTITY_ID
    return
  sendEvent(ownedByPlr, CmdRequestSwitchControlledUnit(toEid = drone__owner))


[es(tag=server)]
def set_controlled_drone_when_switching(evt : EventPlayerControlledUnitChanged)
  
  query(evt.toEid) <| $ [es] (var human__controlledDrone : EntityId&)
    human__controlledDrone = INVALID_ENTITY_ID
  
  query(evt.toEid) <| $ [es(REQUIRE=isDrone)] (drone__owner : EntityId)
    query(drone__owner) <| $ [es] (var human__controlledDrone : EntityId&)
      human__controlledDrone = evt.toEid
