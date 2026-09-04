require ecs
require ecs.common
require net
require DagorSystem
require %appGame.infantry.es.tactical_phone_common

require %appGame.wt_events
require %game.events

def is_controllable_hero_phone(phone_gun__owner : EntityId)
  return has(phone_gun__owner, "hero") && !has(phone_gun__owner, "isReplayObserved")

def tactical_phone_choose_mode_client(chosen_mode : int;
                                      hero__eid : EntityId;
                                      tactical_phone__eid : EntityId;
                                      var tactical_phone__mode : int&;
                                      var tactical_phone__previousMode : int&;
                                      var tactical_phone__isMapOpenedFromPhone : bool&)
  if tactical_phone__mode == chosen_mode
    return
  tactical_phone__previousMode = tactical_phone__mode
  tactical_phone__mode = chosen_mode
  tactical_phone__isMapOpenedFromPhone = tactical_phone__previousMode != int(TacticalPhoneMode.TPM_NONE) && tactical_phone__mode == int(TacticalPhoneMode.TPM_MAP)
  send_net_event(hero__eid, EventSetTactialPhoneMode(tacticalPhoneEid = tactical_phone__eid, mode = tactical_phone__mode))

[es(tag=gameClient, track=tactical_phone__mode, REQUIRE=tactical_phone__mode)]
def tactical_phone_on_mode_changed(evt : Event;
                                   gun__owner : EntityId;
                                   tactical_phone__droneLauncher : EntityId;
                                   tactical_phone__previousMode : int)
  if !is_controllable_hero_phone(gun__owner)
    return
  if tactical_phone__previousMode == int(TacticalPhoneMode.TPM_DRONE)
    query(tactical_phone__droneLauncher) <| $ [es] (drone_launcher__drone : EntityId;
                                                    drone_launcher__droneControlsAcquired : bool)
      if drone_launcher__droneControlsAcquired
        sendEvent(drone_launcher__drone, CmdDroneReleaseControls())

[es(tag=gameClient, REQUIRE=watchedByPlr, track=human_weap__currentGunEid, on_appear, on_disappear)]
def update_tactical_phone_state_on_equip(evt : Event;
                                         human_weap__currentGunEid : EntityId;
                                         var hero__isDrawAboveGeometry : bool&)
  var isCurrentGunPhone = false
  query(human_weap__currentGunEid) <| $ [es] (var tactical_phone__uiEnabled : bool&)
    tactical_phone__uiEnabled = true
    isCurrentGunPhone = true

  
  hero__isDrawAboveGeometry = !isCurrentGunPhone

def has_drone_launcher_weapon(human_weap__weapTemplates : Object)
  for kv in human_weap__weapTemplates
    let templName = get_ecs_string(kv.value)
    if templName == null || *templName == ""
      continue
    let templ = getTemplateByName(string(*templName))
    if templ != null && templateHasComponent(*templ, "drone_launcher", ecs_hash("drone_launcher"))
      return true
  return false


[es(tag=server, on_appear, on_event=CmdReinitWeapons, after=unit_init_completed_es, before=(human_weap_created_server_es, human_weap_reinit_guns_es), REQUIRE=inventory_created)]
def tactical_phone_add_to_weap_templates(evt : Event;
                                         eid : EntityId;
                                         var human_weap__weapTemplates : Object)
  if !has_drone_launcher_weapon(human_weap__weapTemplates)
    return
  let specialTempl = human_weap__weapTemplates |> get_ecs_string("special")
  if specialTempl == null || *specialTempl == ""
    set(human_weap__weapTemplates, "special", "tactical_phone_gun")
  elif *specialTempl != "tactical_phone_gun"
    logerr("soldier {eid} ({getEntityTemplateName(eid)}) has a drone launcher but the special weapon slot is taken by '{*specialTempl}', the tactical phone will not be created and drones will be uncontrollable")

[es(tag=server, track=gun__owner, on_appear)]
def tactical_phone_on_owner_changed(evt : Event;
                                    eid aka tactical_phone__eid : EntityId;
                                    gun__owner aka tactical_phone_gun__owner : EntityId;
                                    var tactical_phone__droneLauncher : EntityId&)
  query(tactical_phone__droneLauncher) <| $ [es] (var drone_launcher__tacticalPhone : EntityId&)
    drone_launcher__tacticalPhone = INVALID_ENTITY_ID
  find_query() <| $ [es] (eid aka drone_launcher__eid : EntityId;
                          gun__owner aka drone_launcher_gun__owner : EntityId;
                          var drone_launcher__tacticalPhone : EntityId&)
    if tactical_phone_gun__owner != drone_launcher_gun__owner
      return false
    tactical_phone__droneLauncher = drone_launcher__eid
    drone_launcher__tacticalPhone = tactical_phone__eid
    return true

[es(on_appear)]
def tactical_phone_appear(evt : Event;
                          var tactical_phone__mode : int&)
  tactical_phone__mode = int(TacticalPhoneMode.TPM_NONE)

[es(tag=gameClient, REQUIRE=(watchedPlayerItem, tactical_phone), on_appear)]
def tactical_phone_appear_client(evt : Event;
                                 eid aka tactical_phone__eid : EntityId)
  find_query() <| $ [es] (var video_feeder__tacticalPhone : EntityId&)
    video_feeder__tacticalPhone = tactical_phone__eid
    return true

[es(tag=server)]
def tactical_phone_set_mode(evt : EventSetTactialPhoneMode;
                            human_weap__gunEids : EidList)
  if human_weap__gunEids |> find_index(evt.tacticalPhoneEid) < 0
    return
  query(evt.tacticalPhoneEid) <| $ [es] (var tactical_phone__mode : int&)
    tactical_phone__mode = evt.mode

[es(tag=gameClient)]
def tactical_phone_on_try_switch_mode(evt : EventRequestSwitchTactialPhoneMode;
                                      eid : EntityId;
                                      gun__owner : EntityId;
                                      tactical_phone__canSwitchModes : bool;
                                      var tactical_phone__mode : int&;
                                      var tactical_phone__previousMode : int&;
                                      var tactical_phone__isMapOpenedFromPhone : bool&)
  if !tactical_phone__canSwitchModes || !is_controllable_hero_phone(gun__owner)
    return
  tactical_phone_choose_mode_client(evt.mode, evt.ownerEid, eid, tactical_phone__mode, tactical_phone__previousMode, tactical_phone__isMapOpenedFromPhone)

[es(tag=gameClient)]
def tactical_phone_on_take(evt : EventRequestTakeTactialPhone;
                           eid aka tactical_phone__eid : EntityId;
                           gun__owner : EntityId;
                           var tactical_phone__mode : int&;
                           var tactical_phone__previousMode : int&;
                           var tactical_phone__isMapOpenedFromPhone : bool&)
  if !is_controllable_hero_phone(gun__owner)
    return
  tactical_phone_choose_mode_client(evt.mode, evt.ownerEid, tactical_phone__eid, tactical_phone__mode, tactical_phone__previousMode, tactical_phone__isMapOpenedFromPhone)
  query(evt.ownerEid) <| $ [es] (human_weap__currentGunEid : EntityId)
    if human_weap__currentGunEid != tactical_phone__eid
      take_tactical_phone(tactical_phone__eid, evt.ownerEid)

[es]
def tactical_phone_phys_es(evt : CmdWeapPhysUpdate;
                           tactical_phone__droneLauncher : EntityId;
                           tactical_phone__mode : int;
                           var tactical_phone__droneUseButtonPressed : bool&)
  if !evt.isForReal
    return
  if tactical_phone__mode == int(TacticalPhoneMode.TPM_DRONE)
    if tactical_phone__droneUseButtonPressed != evt.gctrl.shoot
      tactical_phone__droneUseButtonPressed = evt.gctrl.shoot
      if !tactical_phone__droneUseButtonPressed
        return

      query(tactical_phone__droneLauncher) <| $ [es] (eid aka drone_launcher__eid : EntityId)
        sendEvent(drone_launcher__eid, CmdDroneLaunchOrAcquireControlsFromPhone())
