require ecs
require net
require DngHuman
require HumanPhys
require %game.player_events
require %game.events


[es(tag=server, track=possessedByPlr, REQUIRE_NOT=deadEntity)]
def bot_weapon_reset_when_remove_possessed(evt : Event;
                                           possessedByPlr : EntityId;
                                           human_weap__gunEids : EidList;
                                           human__controlledDrone : EntityId = INVALID_ENTITY_ID;
                                           var human_net_phys : HumanActor)
  if !possessedByPlr && !human__controlledDrone
    let meleeSlotId = int(HUWeaponSlots.EWS_MELEE)
    var newSlotId = meleeSlotId
    for slotId in fixed_array<int>(int(HUWeaponSlots.EWS_PRIMARY), int(HUWeaponSlots.EWS_SECONDARY),
                        int(HUWeaponSlots.EWS_TERTIARY))
      if has(human_weap__gunEids[slotId], "gun") 
        newSlotId = slotId
        break
    if newSlotId != meleeSlotId || human_weap__gunEids[meleeSlotId] != INVALID_ENTITY_ID
      human_net_phys.phys.producedCT |> set_chosen_weapon(HUWeaponSlots(newSlotId))


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
        let specialSlotId = int(HUWeaponSlots.EWS_SPECIAL)
        send_net_event(drone__owner, RequestMultipleGunsSlotSelectGun(gunEid = INVALID_ENTITY_ID, slot = specialSlotId))
        human_net_phys.phys.producedCT |> set_chosen_weapon(HUWeaponSlots.EWS_PRIMARY)
        human_weap__currentGunSlot = primarySlotId
