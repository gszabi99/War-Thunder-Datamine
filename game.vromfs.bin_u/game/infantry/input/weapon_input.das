require ecs
require app
require net
require WTInput
require DngHuman
require %game.events
require %game.input.input_events
require %appGame.infantry.es.multiple_guns_slot_common
require %appGame.infantry.es.grenade_thrower_common
require %appGame.infantry.es.human_weap_common
require %appGame.infantry.input.human_context_command_point_common

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

def is_gun_slot_allowed_to_hold_gun_in_hatch(slot : int)
  return slot < int(HUWeaponSlots.EWS_MELEE) || slot == int(HUWeaponSlots.EWS_GRENADE)

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
                                 human_vehicle__isHoldingGunPassenger : bool = false;
                                 human_weap__grenadeThrower : EntityId;
                                 multiple_guns_slots__gunsEids : EidList;
                                 multiple_guns_slots__active : BoolList;
                                 multiple_guns_slots__wantedGunEid : EidList;
                                 multiple_guns_slots__lastVisibleGunIndex : IntList;
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
  
  let forbidSwitching = is_shortcut_down(ShortcutEventId.ID_HUMAN_CONTEXT_COMMAND) || is_voice_message_list_visible()
  
  
  if time - human_input__lastShootInput < 0.1
    return

  for i in range(0, human_input__weaponSlotCount)
    let weapon = human_weap__gunEids[i]
    if !!weapon && action == human_input__weapons[i] && (!human_vehicle__isHoldingGunPassenger || is_gun_slot_allowed_to_hold_gun_in_hatch(i)) && !forbidSwitching
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
      for i in range(int(HUWeaponSlots.EWS_SECONDARY), int(HUWeaponSlots.EWS_NUM))
        let slot = get_weapon_slot_at(cur_weap, forward, i)
        let weapon = human_weap__gunEids[int(slot)]
        if !!weapon
          if slot == (HUWeaponSlots.EWS_GRENADE)
            if slot != HUWeaponSlots(cur_weap)
              if can_switch_to_multiple_guns_slot(weapon, int(slot), multiple_guns_slots__gunsEids, multiple_guns_slots__active, multiple_guns_slots__lastVisibleGunIndex)
                if weapon == human_weap__grenadeThrower
                  grenade_thrower_select_current_grenade(human__eid, human_weap__grenadeThrower)
                  return
                set_weapon_slot(time, weapon, slot, ct, last_change_time)
              continue
          if has(weapon, "drone_launcher")
            sendEvent(weapon, EventTakeDroneLauncherOrDroneTacticalPhone(atTime = time, weaponSlot = int(slot)))
            return
          if slot == (HUWeaponSlots.EWS_SPECIAL) && can_switch_to_multiple_guns_slot(weapon, int(slot), multiple_guns_slots__gunsEids, multiple_guns_slots__active, multiple_guns_slots__lastVisibleGunIndex)
            return
          set_weapon_slot(time, weapon, slot, ct, last_change_time)
          return
  elif action == int(ShortcutEventId.ID_HUMAN_GRENADE_NEXT) && !forbidSwitching
    if bipod__enabled
      return
    let slot = HUWeaponSlots.EWS_GRENADE
    let weapon = human_weap__gunEids[int(slot)]
    if slot != HUWeaponSlots(cur_weap)
      if can_switch_to_multiple_guns_slot(weapon, int(slot), multiple_guns_slots__gunsEids, multiple_guns_slots__active, multiple_guns_slots__lastVisibleGunIndex)
        if weapon == human_weap__grenadeThrower
          grenade_thrower_select_current_grenade(eid, human_weap__grenadeThrower)
          return
        set_weapon_slot(time, weapon, slot, ct, last_change_time)
    else
      if weapon == human_weap__grenadeThrower
        query(human_weap__grenadeThrower) <| $ [es] (grenade_thrower__grenadeTypesCount : int;
                                                     var grenade_thrower__currentGrenadeTypeIndex : int&)
          if grenade_thrower__currentGrenadeTypeIndex == grenade_thrower__grenadeTypesCount - 1
            if try_request_multiple_guns_slot_equip_next_gun(eid, weapon, cur_weap, cur_weap, multiple_guns_slots__gunsEids, multiple_guns_slots__active, multiple_guns_slots__wantedGunEid, multiple_guns_slots__lastVisibleGunIndex)
              grenade_thrower__currentGrenadeTypeIndex = 0
            return
          grenade_thrower_select_next_grenade(eid, human_weap__grenadeThrower)
        return
      if can_multiple_guns_slot_equip_next_gun(weapon, cur_weap, cur_weap, multiple_guns_slots__gunsEids, multiple_guns_slots__active, multiple_guns_slots__wantedGunEid, multiple_guns_slots__lastVisibleGunIndex)
        let nextInventoryGun = get_multiple_guns_slot_next_visible_gun(cur_weap, multiple_guns_slots__gunsEids, multiple_guns_slots__active, multiple_guns_slots__lastVisibleGunIndex)
        if nextInventoryGun == human_weap__grenadeThrower
          grenade_thrower_select_current_grenade(eid, human_weap__grenadeThrower)
          return
        send_net_event(eid, RequestMultipleGunsSlotEquipNextGun(slot = cur_weap))
  elif action == int(ShortcutEventId.ID_HUMAN_SPECIAL_2)
    if bipod__enabled
      return
    let slot = HUWeaponSlots.EWS_SPECIAL
    let weapon = human_weap__gunEids[int(slot)]
    if slot != HUWeaponSlots(cur_weap)
      if can_switch_to_multiple_guns_slot(weapon, int(slot), multiple_guns_slots__gunsEids, multiple_guns_slots__active, multiple_guns_slots__lastVisibleGunIndex)
        set_weapon_slot(time, weapon, slot, ct, last_change_time)
    else
      try_request_multiple_guns_slot_equip_next_gun(eid, weapon, cur_weap, cur_weap, multiple_guns_slots__gunsEids, multiple_guns_slots__active, multiple_guns_slots__wantedGunEid, multiple_guns_slots__lastVisibleGunIndex)

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
