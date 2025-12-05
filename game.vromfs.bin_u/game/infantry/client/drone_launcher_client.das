require ecs
require ecs.common
require app

require %appGame.wt_events
require %game.events
require %appGame.infantry.es.human_weap_common
require %appGame.infantry.es.tactical_phone_common
require %appGame.infantry.es.drone_launcher_common
require DngHuman
require net
require DagorDataBlock
require hud


def check_respawn_base_for_launching_drone(human_eid : EntityId)
  var respawnExists = false
  query(human_eid) <| $ [es] (team : int)
    respawnExists = get_respawn_base_for_drone(team) is transform
  return respawnExists


def check_for_drone_info_message_cooldown(time : float;
                                          drone_launcher__nextInfoMessageCooldown : float;
                                          var drone_launcher__nextInfoMessageAtTime : float&)
  if time > drone_launcher__nextInfoMessageAtTime
    drone_launcher__nextInfoMessageAtTime = time + drone_launcher__nextInfoMessageCooldown
    return true
  return false


def send_log_missing_respawn_for_launching_drone(human_eid : EntityId;
                                                 time : float;
                                                 drone_launcher__nextInfoMessageCooldown : float;
                                                 var drone_launcher__nextInfoMessageAtTime : float&)
  if !check_for_drone_info_message_cooldown(time, drone_launcher__nextInfoMessageCooldown, drone_launcher__nextInfoMessageAtTime)
    return
  let text = "drone/respawn_is_missing"
  send_net_event(human_eid, CmdHeroLogEvent(event = "drone_launcher_log", text = text))


def send_log_cooldown_for_launching_drone(time : float;
                                          drone_launcher__nextUseAtTime : float;
                                          drone_launcher__nextInfoMessageCooldown : float;
                                          var drone_launcher__nextInfoMessageAtTime : float&)
  if !check_for_drone_info_message_cooldown(time, drone_launcher__nextInfoMessageCooldown, drone_launcher__nextInfoMessageAtTime)
    return
  let text = "hint:drone/cooldown_for_launch"
  let cooldown = int(max(drone_launcher__nextUseAtTime - time, 1.0f))
  
  using() <| $(var eventData : DataBlock)
    set(eventData, "seconds", cooldown)
    hud_notify_script(text, eventData)


def send_log_bleeding_for_launching_drone(human_eid : EntityId;
                                          time : float;
                                          drone_launcher__nextInfoMessageCooldown : float;
                                          var drone_launcher__nextInfoMessageAtTime : float&)
  if !check_for_drone_info_message_cooldown(time, drone_launcher__nextInfoMessageCooldown, drone_launcher__nextInfoMessageAtTime)
    return

  let text = "drone/bleeding_warning"
  send_net_event(human_eid, CmdHeroLogEvent(event = "drone_launcher_log", text = text))

def private check_if_owner_has_bleeding(owner_eid : EntityId)
  var hasBleeding = false
  query(owner_eid) <| $ [es] (hitpoints__totalDotAmount : float)
    hasBleeding = hitpoints__totalDotAmount > 0.0
  return hasBleeding


def take_drone_launcher(human_eid : EntityId;
                        drone_launcher__eid : EntityId;
                        time : float;
                        var weapon_slot : int = -1)
  query(human_eid) <| $ [es] (human_weap__gunEids : EidList;
                              var human_net_phys : HumanActor&;
                              var human_input__lastWeaponChangeInput : float&)
    if weapon_slot == -1
      weapon_slot = find_index(human_weap__gunEids, drone_launcher__eid)
    assume ct = human_net_phys.phys.producedCT
    assume last_change_time = human_input__lastWeaponChangeInput
    set_weapon_slot(time, drone_launcher__eid, HUWeaponSlots(weapon_slot), ct, last_change_time)


def take_drone_launcher_or_drone_tactical_phone(human_eid : EntityId;
                                                drone_launcher__eid : EntityId;
                                                drone_launcher__drone : EntityId;
                                                drone_launcher__tacticalPhone : EntityId;
                                                time : float;
                                                drone_launcher__instantLaunchFromPhone : bool;
                                                drone_launcher__droneControlsAcquired : bool;
                                                drone_launcher__nextInfoMessageCooldown : float;
                                                var drone_launcher__nextInfoMessageAtTime : float&;
                                                weapon_slot : int = -1)
  if drone_launcher__droneControlsAcquired
    sendEvent(drone_launcher__drone, CmdDroneReleaseControls())
    return

  if check_if_owner_has_bleeding(human_eid)
    send_log_bleeding_for_launching_drone(human_eid, time, drone_launcher__nextInfoMessageCooldown, drone_launcher__nextInfoMessageAtTime)
    return

  let droneExists = drone_launcher__drone != INVALID_ENTITY_ID

  if drone_launcher__instantLaunchFromPhone
    sendEvent(drone_launcher__tacticalPhone, EventRequestTakeTactialPhone(ownerEid = human_eid, mode = int(TacticalPhoneMode.TPM_DRONE)))
    return

  if droneExists
    sendEvent(drone_launcher__tacticalPhone, EventRequestTakeTactialPhone(ownerEid = human_eid, mode = int(TacticalPhoneMode.TPM_DRONE)))
  else
    take_drone_launcher(human_eid, drone_launcher__eid, time, weapon_slot)


[es(tag=gameClient, track=drone_launcher__droneControlsAcquired)]
def on_drone_launcher_control_changed(evt : Event;
                                      drone_launcher__tacticalPhone : EntityId;
                                      drone_launcher__droneControlsAcquired : bool)
  query(drone_launcher__tacticalPhone) <| $ [es] (var tactical_phone__canSwitchModes : bool&)
    tactical_phone__canSwitchModes = !drone_launcher__droneControlsAcquired


[es(tag=gameClient, REQUIRE=isDrone, on_disappear)]
def reset_drone_launcher_on_drone_destroy_client(evt : Event;
                                                 drone__launcherEid : EntityId)
  query(drone__launcherEid) <| $ [es] (var drone_launcher__droneControlsAcquired : bool&)
    drone_launcher__droneControlsAcquired = false


[es(tag=gameClient, REQUIRE=watchedPlayerItem)]
def drone_launch_or_acquire_controls_from_phone(evt : CmdDroneLaunchOrAcquireControlsFromPhone;
                                                eid aka drone_launcher__eid : EntityId;
                                                gun__owner : EntityId;
                                                drone_launcher__drone : EntityId;
                                                drone_launcher__instantLaunchFromPhone : bool;
                                                drone_launcher__nextUseAtTime : float;
                                                drone_launcher__nextInfoMessageCooldown : float;
                                                var drone_launcher__nextInfoMessageAtTime : float&;
                                                var drone_launcher__state : int&)
  let time = get_sync_time()
  if check_if_owner_has_bleeding(gun__owner)
    send_log_bleeding_for_launching_drone(gun__owner, time, drone_launcher__nextInfoMessageCooldown, drone_launcher__nextInfoMessageAtTime)
    return

  if drone_launcher__drone != INVALID_ENTITY_ID
    sendEvent(drone_launcher__drone, CmdDroneAcquireControls())
    return

  if time < drone_launcher__nextUseAtTime
    send_log_cooldown_for_launching_drone(time, drone_launcher__nextUseAtTime, drone_launcher__nextInfoMessageCooldown, drone_launcher__nextInfoMessageAtTime)
    return

  if !drone_launcher__instantLaunchFromPhone
    take_drone_launcher(gun__owner, drone_launcher__eid, time)
    return

  if !check_respawn_base_for_launching_drone(gun__owner)
    send_log_missing_respawn_for_launching_drone(gun__owner, time, drone_launcher__nextInfoMessageCooldown, drone_launcher__nextInfoMessageAtTime)
    return

  drone_launcher__state = int(DroneLauncherState.DLS_LAUNCHED)
  send_net_event(gun__owner, RequestDroneLauncherInstantLaunch(droneLauncherEid = drone_launcher__eid))


[es(tag=gameClient, REQUIRE=watchedPlayerItem)]
def drone_launcher_on_fail_launch_response(evt : ResponseDroneLauncherFailLaunch;
                                           eid : EntityId;
                                           gun__owner : EntityId;
                                           drone_launcher__drone : EntityId;
                                           drone_launcher__tacticalPhone : EntityId;
                                           drone_launcher__instantLaunchFromPhone : bool;
                                           drone_launcher__droneControlsAcquired : bool;
                                           drone_launcher__nextInfoMessageCooldown : float;
                                           var drone_launcher__nextInfoMessageAtTime : float&;
                                           var drone_launcher__state : int&;
                                           var drone_launcher_anim__launchInProgress : bool&;
                                           var animchar_render__enabled : bool&)
  drone_launcher__state = int(DroneLauncherState.DLS_READY)
  animchar_render__enabled = true
  drone_launcher_anim__launchInProgress = false
  take_drone_launcher_or_drone_tactical_phone(gun__owner, eid, drone_launcher__drone, drone_launcher__tacticalPhone, get_sync_time(), drone_launcher__instantLaunchFromPhone, drone_launcher__droneControlsAcquired, drone_launcher__nextInfoMessageCooldown, drone_launcher__nextInfoMessageAtTime)


[es(tag=gameClient)]
def drone_launcher_phys_es(evt : CmdWeapPhysUpdate;
                           eid : EntityId;
                           drone_launcher_anim__launchTime : float;
                           drone_launcher__nextInfoMessageCooldown : float;
                           var drone_launcher__nextInfoMessageAtTime : float&;
                           var drone_launcher__state : int&;
                           var drone_launcher__launchButtonPressed : bool&;
                           var drone_launcher_anim__launchStart : float&;
                           var drone_launcher_anim__launchEnd : float&;
                           var drone_launcher_anim__launchInProgress : bool&;
                           var drone_launcher_anim__replaceAnimationWithEntity : bool&)
  let isForReal = evt.isForReal
  if !isForReal
    return
  let ownerEid = evt.owner
  let atTime = evt.atTime
  if drone_launcher__state == int(DroneLauncherState.DLS_READY)
    if evt.gctrl.shoot != drone_launcher__launchButtonPressed
      drone_launcher__launchButtonPressed = evt.gctrl.shoot
      if !drone_launcher__launchButtonPressed
        return

      if check_if_owner_has_bleeding(ownerEid)
        send_log_bleeding_for_launching_drone(ownerEid, get_sync_time(), drone_launcher__nextInfoMessageCooldown, drone_launcher__nextInfoMessageAtTime)
        return

      drone_launcher__state = int(DroneLauncherState.DLS_LAUNCH)
      drone_launcher_anim__launchStart = atTime
      drone_launcher_anim__launchEnd = atTime + drone_launcher_anim__launchTime
      drone_launcher_anim__launchInProgress = true
      drone_launcher_anim__replaceAnimationWithEntity = false
      send_net_event(ownerEid, RequestDroneLauncherStartLaunch(droneLauncherEid = eid, atTime = drone_launcher_anim__launchStart))

      query(ownerEid) <| $ [es] (human_weap__currentGunSlot : int;
                                 var human_weap__lockedWeaponSlot : int&)
        human_weap__lockedWeaponSlot = human_weap__currentGunSlot


[es(tag=gameClient, REQUIRE=watchedPlayerItem, track=drone_launcher_anim__launchInProgress)]
def drone_launcher_enable_weapon_switching_on_anim_end(evt : Event;
                                                       gun__owner : EntityId;
                                                       drone_launcher_anim__launchInProgress : bool)
  if drone_launcher_anim__launchInProgress
    return
  query(gun__owner) <| $ [es] (human_weap__currentGunSlot : int;
                               var human_weap__lockedWeaponSlot : int&)
    if human_weap__lockedWeaponSlot == human_weap__currentGunSlot
      human_weap__lockedWeaponSlot = -1


[es(tag=gameClient, REQUIRE=watchedPlayerItem)]
def take_drone_launcher_or_drone_tactical_phone_es(evt : EventTakeDroneLauncherOrDroneTacticalPhone;
                                                   eid : EntityId;
                                                   gun__owner : EntityId;
                                                   drone_launcher__drone : EntityId;
                                                   drone_launcher__tacticalPhone : EntityId;
                                                   drone_launcher__instantLaunchFromPhone : bool;
                                                   drone_launcher__droneControlsAcquired : bool;
                                                   drone_launcher__nextInfoMessageCooldown : float;
                                                   var drone_launcher__nextInfoMessageAtTime : float&)
  take_drone_launcher_or_drone_tactical_phone(gun__owner, eid, drone_launcher__drone, drone_launcher__tacticalPhone, evt.atTime, drone_launcher__instantLaunchFromPhone, drone_launcher__droneControlsAcquired, drone_launcher__nextInfoMessageCooldown, drone_launcher__nextInfoMessageAtTime, evt.weaponSlot)

[es(tag=gameClient, on_appear, REQUIRE=isQuadrocopterHints)]
def hud_appear_controls_on_drone_creation_es(evt : Event;
                                             ownedByPlr : EntityId)
  if ownedByPlr == get_local_player_eid()
    using() <| $(var eventData : DataBlock)
      hud_notify_script("hint:drone_switch_control_mode", eventData)

