require ecs
require ecs.common
require app
require net
require WTInput
require DngHuman
require %game.events
require %game.input.input_events
require %appGame.infantry.es.grenade_thrower_common
require %appGame.infantry.es.human_weap_common
require %appGame.infantry.input.human_context_command_point_common
require %appGame.infantry.es.vehicle.vehicle_seats_common

require %appGame.wt_events
require DaWeapons


let weaponInputIndexToSlot = fixed_array(0, 7, 2, 3)

def get_weapon_slot_at(main_weapon : int;
                       forward : bool;
                       position : int;
                       limit : int = int(HUWeaponSlots.EWS_NUM))
  let offset = forward ? position : -position + limit
  let ret = main_weapon + offset
  return HUWeaponSlots(ret % limit)


[es(tag=input, on_appear)]
def human_weapon_input_init_es(evt : Event;
                               var human_input__weaponSlotCount : int&;
                               var human_input__weapons : IntList&)
  push(human_input__weapons, int(ShortcutEventId.ID_HUMAN_MAIN_WEAPON)) 
  push(human_input__weapons, int(ShortcutEventId.ID_HUMAN_PISTOL))      
  push(human_input__weapons, int(ShortcutEventId.ID_HUMAN_SPECIAL_1))   
  push(human_input__weapons, int(ShortcutEventId.ID_HUMAN_MELEE))       
  human_input__weaponSlotCount = length(human_input__weapons)


[es(tag=input, REQUIRE=controlledHero)]
def human_weapon_switch_input_es(evt : EventOnKeyDown;
                                 eid aka human__eid : EntityId;
                                 human_context_command__pointOrder : int;
                                 human_weap__gunEids : EidList;
                                 bipod__enabled : bool = false;
                                 human_input__lastShootInput : float;
                                 human_input__weapons : IntList;
                                 human_input__weaponSlotCount : int;
                                 isInVehicle : bool = false;
                                 human_vehicle__occupiedSeatEid : EntityId = INVALID_ENTITY_ID;
                                 human_weap__grenadeThrower : EntityId;
                                 human_weap__gunMods : Array;
                                 input__enabled : bool = true;
                                 var human_net_phys : HumanActor&;
                                 var human_input__lastWeaponChangeInput : float&)
  assume ct = human_net_phys.phys.producedCT
  if !input__enabled
    return
  let time = get_sync_time()
  let action = int(evt.eventId)
  let cur_weap = int(ct.chosenWeapon)
  assume last_change_time = human_input__lastWeaponChangeInput
  let forbidSwitching = is_shortcut_down(ShortcutEventId.ID_HUMAN_CONTEXT_COMMAND) || is_voice_messages_active()
  var isDriver = false
  var isPassenger = false
  if isInVehicle
    query(human_vehicle__occupiedSeatEid) <| $ [es] (seat__isDriver : bool; seat__isPassenger : bool)
      isDriver = seat__isDriver
      isPassenger = seat__isPassenger
  if isDriver 
    return
  
  
  if time - human_input__lastShootInput < 0.1
    return

  for i in range(0, human_input__weaponSlotCount)
    let weapon = human_weap__gunEids[i]
    if isPassenger && !is_gun_slot_allowed_to_hold_gun_in_hatch(i)
      continue
    if !!weapon && action == human_input__weapons[i] && !forbidSwitching
      if has(weapon, "drone_launcher")
        sendEvent(weapon, EventTakeDroneLauncherOrDroneTacticalPhone(atTime = time, weaponSlot = i))
        return
      if cur_weap != i
        set_weapon_slot(time, weapon, HUWeaponSlots(i), ct, last_change_time)
      else
        sendEvent(human__eid, CmdWeapModToggle(slotId = int(cur_weap)))
      return

  if action == int(ShortcutEventId.ID_HUMAN_NEXT_SLOT) || action == int(ShortcutEventId.ID_HUMAN_PREV_SLOT)
    let forward = action == int(ShortcutEventId.ID_HUMAN_NEXT_SLOT)
    if human_context_command__pointOrder == int(HumanPointOrderType.POINT_TAKE_POSITION)
      if human_point_order_rotate_to_next_or_prev_dir(human__eid, forward)
        human_point_order_obj_update(human__eid)
    else
      if bipod__enabled
        return
      
      
      var cycleFromSlot = cur_weap
      query(human_weap__gunEids[cur_weap]) <| $ [es] (tactical_phone__droneLauncher : EntityId)
        let launcherSlot = find_index(human_weap__gunEids, tactical_phone__droneLauncher)
        if launcherSlot >= 0
          cycleFromSlot = launcherSlot

      let curGunModEids = get_ecs_EidList(human_weap__gunMods[cur_weap])
      if curGunModEids != null
        var hasMod = false
        var curModActive = false
        for gunMod in *curGunModEids
          query(gunMod) <| $ [es] (weapon_mod__wantActiveState : bool)
            hasMod = true
            curModActive = weapon_mod__wantActiveState
        if hasMod && ((!curModActive && forward) || (curModActive && !forward))
          sendEvent(human__eid, CmdWeapModToggle(slotId = int(cur_weap)))
          return

      for i in range(int(HUWeaponSlots.EWS_SECONDARY), int(HUWeaponSlots.EWS_NUM))
        let slot = get_weapon_slot_at(cycleFromSlot, forward, i)
        if isPassenger && !is_gun_slot_allowed_to_hold_gun_in_hatch(int(slot))
          continue
        let weapon = human_weap__gunEids[int(slot)]
        if !!weapon && slot != (HUWeaponSlots EWS_GRENADE) && slot != (HUWeaponSlots EWS_SPECIAL)
          if has(weapon, "drone_launcher")
            sendEvent(weapon, EventTakeDroneLauncherOrDroneTacticalPhone(atTime = time, weaponSlot = int(slot)))
            return
          set_weapon_slot(time, weapon, slot, ct, last_change_time)
          if !forward
            sendEvent(human__eid, CmdWeapModActivate(slotId = int(slot), activate = true))
          return
  elif action == int(ShortcutEventId.ID_HUMAN_GRENADE_NEXT) && !forbidSwitching
    if bipod__enabled
      return
    let slot = HUWeaponSlots.EWS_GRENADE
    if isPassenger && !is_gun_slot_allowed_to_hold_gun_in_hatch(int(slot))
      return
    let weapon = human_weap__gunEids[int(slot)]
    if !weapon || weapon != human_weap__grenadeThrower
      return
    if slot != HUWeaponSlots(cur_weap)
      if grenade_thrower_select_current_grenade(eid, weapon)
        set_weapon_slot(time, weapon, slot, ct, last_change_time)
    else
      grenade_thrower_select_next_grenade(eid, weapon)


[es(tag=input, REQUIRE=controlledHero, on_appear, track=human_vehicle__occupiedSeatEid)]
def human_weapon_passenger_slot_correction_es(evt : Event;
                                              human_vehicle__occupiedSeatEid : EntityId;
                                              human_weap__gunEids : EidList;
                                              human_weap__grenadeThrower : EntityId;
                                              var human_net_phys : HumanActor&;
                                              var human_input__lastWeaponChangeInput : float&)
  var isPassenger = false
  query(human_vehicle__occupiedSeatEid) <| $ [es] (seat__isPassenger : bool)
    isPassenger = seat__isPassenger
  if !isPassenger
    return
  assume ct = human_net_phys.phys.producedCT
  if is_gun_slot_allowed_to_hold_gun_in_hatch(int(ct.chosenWeapon))
    return
  let time = get_sync_time()
  for i in range(0, int(HUWeaponSlots.EWS_NUM))
    if !is_gun_slot_allowed_to_hold_gun_in_hatch(i)
      continue
    let weapon = human_weap__gunEids[i]
    if !weapon || i == int(HUWeaponSlots.EWS_SPECIAL)
      continue
    if i == int(HUWeaponSlots.EWS_GRENADE) && weapon == human_weap__grenadeThrower
      var hasGrenades = false
      query(weapon) <| $ [es] (grenade_thrower__grenadeTypesCount : int)
        hasGrenades = grenade_thrower__grenadeTypesCount > 0
      if !hasGrenades
        continue
    set_weapon_slot(time, weapon, HUWeaponSlots(i), ct, human_input__lastWeaponChangeInput)
    return


[es(tag=gameClient)]
def human_weap_change_weapon_es(evt : CmdSelectWeaponSlot;
                                var human_net_phys : HumanActor;
                                var human_input__lastWeaponChangeInput : float&)
  set_chosen_weapon(human_net_phys.phys.producedCT, HUWeaponSlots(int(evt.slot)))
  human_input__lastWeaponChangeInput = get_sync_time()

[es(tag=input, REQUIRE=controlledHero)]
def human_weap_ammo_toggle_input_es(evt : EventOnKeyDown;
                                    human_net_phys : HumanActor;
                                    eid : EntityId)
  if evt.eventId == int(ShortcutEventId.ID_HUMAN_WEAP_AMMO_TOGGLE)
    sendEvent(eid, CmdToggleWishAmmoItemType(slot_id = int(human_net_phys.phys.producedCT.chosenWeapon)))

[es(tag=input, REQUIRE=controlledHero)]
def human_weap_switch_firing_mode_input_es(evt : EventOnKeyDown;
                                           eid : EntityId;
                                           human_weap__gunEids : EidList;
                                           human_weap__currentGunSlot : int)
  if evt.eventId == int(ShortcutEventId.ID_HUMAN_FIRING_MOD_NEXT)
    if is_shortcut_down(ShortcutEventId.ID_HUMAN_SHOOT)
      return

    if human_weap__currentGunSlot < 0
      return

    let weaponEid = human_weap__gunEids[human_weap__currentGunSlot]
    query(weaponEid) <| $ [es] (gun : Gun)
      let currentGunSlot = uint8(human_weap__currentGunSlot)
      let wishModeId = gun |> gun_getNextFiringModeIndex()
      send_net_event(eid, HumanWeapRequestSwitchFiringMode(slotId = currentGunSlot, modeId = wishModeId))
