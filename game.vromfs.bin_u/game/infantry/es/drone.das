require ecs
require app
require net
require math.base
require math.easing
require Unit
require Plane
require FlightModelWrap
require DagorMath

require %appGame.wt_events
require %game.events
require %game.dm.dm_events
require %game.player_events
require %game.unit.unit_events
require %game.unit.aircraft_events
require %appGame.infantry.es.loc_squad_common
require %appGame.infantry.es.hitpoints_common
require %appGame.infantry.es.drone_common


[es(on_appear, REQUIRE=drone_type__recon)]
def drone_type_recon_init(evt : Event;
                          var drone__type : int&)
  drone__type = int(DroneType.Recon)


[es(on_appear, REQUIRE=drone_type__bombing)]
def drone_type_bombing_init(evt : Event;
                            var drone__type : int&)
  drone__type = int(DroneType.Bombing)


[es(on_appear, REQUIRE=drone_type__kamikaze)]
def drone_type_kamikaze_init(evt : Event;
                             var drone__type : int&)
  drone__type = int(DroneType.Kamikaze)


[es(track=drone__soundEnabled, on_appear)]
def drone_enable_sound(evt : Event;
                       drone__soundEnabled : bool;
                       var sound_control__allowSound : bool&)
  sound_control__allowSound = drone__soundEnabled


[es(tag=server, REQUIRE=isDrone)]
def drone_destroy_on_unit_collision_es(evt : EventUnitToUnitCollision; eid : EntityId)
  if !evt.isFriction
    sendEventImmediate(eid, CmdDestroyDrone())


[es(tag=server, REQUIRE=isDrone)]
def drone_destroy_on_crash_es(evt : EventAicraftCrash; eid : EntityId)
  sendEventImmediate(eid, CmdDestroyDrone())


[es(tag=render, no_order)]
def drone_areas_quality_distance(info : ParallelUpdateFrameDelayed;
                                 drone__owner : EntityId;
                                 transform aka drone_transform : float3x4;
                                 drone__coverageArea : float2;
                                 drone__outOfAreaBorder : bool;
                                 drone__nearOfAreaBorder : bool;
                                 var drone_connectionQuality : int&)
  query(drone__owner) <| $ [es] (transform aka owner_transform : float3x4)
    let coverageArea = drone__coverageArea.y
    let partOfCoverage = coverageArea / 3.0
    let dronePos = drone_transform[3]
    let ownerPos = owner_transform[3]
    let distance = length(dronePos - ownerPos)
    let overridedQuality = drone__outOfAreaBorder ? 1 : (drone__nearOfAreaBorder ? 2 : 3)
    drone_connectionQuality = min(min(3, 3 - int(distance / partOfCoverage)), overridedQuality)


def private drone_weak_signal_hint(drone_eid : EntityId; show : bool)
  query(drone_eid) <| $ [es] (var drone__isWeakSignalHintActive : bool&)
    drone__isWeakSignalHintActive = show
    let eventText = show ? "drone/weak_signal:show" : "drone/weak_signal:hide"
    send_net_event(drone_eid, CmdHeroLogEvent(event = "drone_weak_signal", text = eventText))


[es(tag=server, no_order, REQUIRE=isDrone)]
def drone_camera_check_distance(info : ParallelUpdateFrameDelayed;
                                eid : EntityId;
                                transform aka drone_transform : float3x4;
                                drone__owner : EntityId;
                                drone__coverageArea : float2;
                                drone__isWeakSignalHintActive : bool)
  query(drone__owner) <| $ [es] (transform aka owner_transform : float3x4)
    let distSquare = distance_sq(owner_transform[3], drone_transform[3])
    if distSquare > square(drone__coverageArea.y)
      sendEvent(eid, CmdDestroyDrone())
      send_net_event(eid, CmdHeroLogEvent(event = "drone_lost_signal", text = "drone/lost_signal"))
      if drone__isWeakSignalHintActive
        drone_weak_signal_hint(eid, false)
    elif distSquare > square(drone__coverageArea.x)
      if !drone__isWeakSignalHintActive
        drone_weak_signal_hint(eid, true)
    else
      if drone__isWeakSignalHintActive
        drone_weak_signal_hint(eid, false)


[es(tag=server)]
def drone_destroy_request(evt : CmdRequestDestroyDrone;
                          eid aka human__eid : EntityId)
  query(evt.droneEid) <| $ [es] (drone__owner : EntityId; isAlive : bool)
    if human__eid != drone__owner
      return
    if !isAlive
      return
    sendEventImmediate(evt.droneEid, CmdDestroyDrone())


[es]
def drone_on_became_dead(evt : EventUnitBecameDead; var isAlive : bool&)
  isAlive = false


[es(on_appear, REQUIRE=(isDrone, deadEntity))]
def drone_setup_destroy_dead_delay(evt : Event; var entity_destroyer__destroyAtTime : float&; drone__destroyDeadDelay : float)
  entity_destroyer__destroyAtTime = get_sync_time() + drone__destroyDeadDelay

[es(tag=server)]
def kick_out_of_drone_if_damaged(evt : EventOnEntityHit; drone__owner : EntityId; eid aka drone_eid : EntityId)
  if evt.damageType == int(DamageType.DM_BLEEDING)
    return
  if drone__owner == evt.victim
    sendEvent(drone_eid, CmdDroneReleaseControls())

[es(REQUIRE=isDrone)]
def drone_change_possessing_plr_from(evt : EventPlayerChangeControlFrom; var plane_net_phys : PlaneActor&)
  plane_net_phys.phys |> flight_model_setPlayerMode(false)

[es(REQUIRE=isDrone)]
def drone_change_possessing_plr_to(evt : EventPlayerChangeControlTo; var plane_net_phys : PlaneActor&)
  plane_net_phys.phys |> flight_model_setPlayerMode(true)


[es(tag=server)]
def switch_ai_drone_owner_beh_node_on_hit(evt : EventOnHitEntity;
                                          var beh_tree__wantRoleDroner : bool&)
  beh_tree__wantRoleDroner = false


[es(tag=server, track=human_weap__currentGunEid)]
def switch_ai_drone_owner_beh_node_on_changed_weapon(evt : Event;
                                                     eid : EntityId;
                                                     human_weap__currentGunEid : EntityId;
                                                     var beh_tree__wantRoleDroner : bool&)
  if beh_tree__wantRoleDroner
    if !has(human_weap__currentGunEid, "tactical_phone")
      beh_tree__wantRoleDroner = false
  elif get_controlled_drone_from_owner(eid) != INVALID_ENTITY_ID
    beh_tree__wantRoleDroner = true


[es(tag=server)]
def switch_ai_drone_owner_beh_node_on_lost_control(evt : EventPlayerUnitControlLost;
                                                   drone__owner : EntityId)
  query(drone__owner) <| $ [es] (var beh_tree__wantRoleDroner : bool&)
    beh_tree__wantRoleDroner = false


[es(tag=server, no_order)]
def check_drone_owner_far_from_leader(info : ParallelUpdateFrameDelayed;
                                      transform aka droner_transform : float3x4;
                                      squad_member__squad : EntityId;
                                      var beh_tree__wantRoleDroner : bool&)
  if !beh_tree__wantRoleDroner
    return
  query(squad_member__squad) <| $ [es] (squad__leader : EntityId;
                                        squad__maxOrderDistance : float)
    query(squad__leader) <| $ [es] (transform aka leader_transform : float3x4)
      if distance_sq(droner_transform[3], leader_transform[3]) > square(squad__maxOrderDistance)
        beh_tree__wantRoleDroner = false


[es(tag=server, no_order, REQUIRE=(isDrone, canBeWirelesslyMonitored))]
def update_drone_monitoring(info : ParallelUpdateFrameDelayed;
                            drone__owner : EntityId;
                            var unit__ref : UnitRef&)
  query(drone__owner) <| $ [es] (human_weap__currentGunEid : EntityId)
    var fmw = as_fmw(unit__ref.unit)
    return if fmw == null
    (*fmw).isWirelesslyMonitored = has(human_weap__currentGunEid, "tactical_phone")
