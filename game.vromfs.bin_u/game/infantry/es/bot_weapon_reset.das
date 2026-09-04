require ecs
require DngHuman
require HumanPhys
require %game.player_events


[es(tag=server, track=possessedByPlr, REQUIRE_NOT=deadEntity)]
def bot_weapon_reset_when_remove_possessed(evt : Event;
                                           possessedByPlr : EntityId;
                                           human_weap__gunEids : EidList;
                                           human__controlledDrone : EntityId = INVALID_ENTITY_ID;
                                           isInVehicle : bool = false;
                                           var human_net_phys : HumanActor)
  if !possessedByPlr && !human__controlledDrone && !isInVehicle
    let meleeSlotId = int(HUWeaponSlots.EWS_MELEE)
    var newSlotId = meleeSlotId
    for slotId in fixed_array<int>(int(HUWeaponSlots.EWS_PRIMARY), int(HUWeaponSlots.EWS_SECONDARY),
                        int(HUWeaponSlots.EWS_TERTIARY))
      if has(human_weap__gunEids[slotId], "gun") 
        newSlotId = slotId
        break
    if newSlotId != meleeSlotId || human_weap__gunEids[meleeSlotId] != INVALID_ENTITY_ID
      human_net_phys.phys.producedCT |> set_chosen_weapon(HUWeaponSlots(newSlotId))


[es]
def human_stop_fire_on_switch_from(evt : EventPlayerChangeControlFrom;
                                   var human_net_phys : HumanActor)
  assume phys = human_net_phys.phys
  let isCrouch = (uint(phys.currentState.states) & uint(StateFlag.ST_CROUCH)) != 0u
  let isCrawl = (uint(phys.currentState.states) & uint(StateFlag.ST_CRAWL)) != 0u
  phys.producedCT |> human_control_state_set_neutral_ctrl()
  phys.producedCT |> human_control_state_set_walk_speed(0.f)
  phys.producedCT |> human_control_state_set_wish_shoot_dir(phys.currentState.gunDir)
  phys.producedCT |> human_control_state_set_wish_look_dir(phys.currentState.headDir)
  phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CROUCH, isCrouch)
  phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CRAWL, isCrawl)
  phys.producedCT |> set_chosen_weapon(phys.currentState.weapEquipState.nextSlot)
  phys.appliedCT |> human_control_state_set_neutral_ctrl()
  phys.appliedCT |> human_control_state_set_wish_shoot_dir(phys.currentState.gunDir)
  phys.appliedCT |> human_control_state_set_wish_look_dir(phys.currentState.headDir)
  phys.appliedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CROUCH, isCrouch)
  phys.appliedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CRAWL, isCrawl)
  human_control_state_clear_unaproved_ctrl(phys)


[es(tag=server)]
def bot_weapon_reset_when_switching_from_drone(evt : EventPlayerControlledUnitChanged)
  query(evt.fromEid) <| $ [es(REQUIRE_NOT=canBeWirelesslyMonitored)] (drone__owner : EntityId)
    if evt.toEid == drone__owner
      return
    query(drone__owner) <| $ [es] (beh_tree__enabled : bool;
                                   var human_weap__currentGunSlot : int&;
                                   var human_net_phys : HumanActor&)
      if beh_tree__enabled
        let primarySlotId = int(HUWeaponSlots.EWS_PRIMARY)
        human_net_phys.phys.producedCT |> set_chosen_weapon(HUWeaponSlots.EWS_PRIMARY)
        human_weap__currentGunSlot = primarySlotId
