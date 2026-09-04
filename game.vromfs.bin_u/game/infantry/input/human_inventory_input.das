require ecs
require WTInput
require DngHuman
require AppTime
require %game.input.input_events

require %appGame.wt_events
require %appGame.infantry.es.inventory_common
require net


[es(tag=input, after=human_input_es, REQUIRE=controlledHero)]
def human_inventory_input_action_triggered_es(evt : EventOnKeyDown;
                                              eid : EntityId;
                                              human_ladder__attached : bool;
                                              
                                              human_inventory__selectedItem : EntityId;
                                              
                                              
                                              
                                              heal__continuousInput : bool = true

)
  let action = int(evt.eventId)
  let selectedItem = human_inventory__selectedItem
  let isForcedPickup = (action == int(ShortcutEventId.ID_HUMAN_INVENTORY_FORCED_PICKUP)) 

  if isForcedPickup || (action == int(ShortcutEventId.ID_HUMAN_INVENTORY_PICKUP))
    if !doesEntityExist(selectedItem) || has(selectedItem, "disableItemDrop")
      return

    let isForcedOrFastPickup = isForcedPickup || is_fast_pickup_item(eid, selectedItem)
    if isForcedOrFastPickup || is_item_useful(eid, selectedItem)
      
      
      
      
      
      
      let usefulOnly = !isForcedOrFastPickup
      sendEvent(eid, CmdInventoryPickup(itemEid = selectedItem, usefulOnly = usefulOnly))
    
    
  elif action == int(ShortcutEventId.ID_HUMAN_USE_MEDKIT) && heal__continuousInput && !human_ladder__attached
    send_net_event(eid, CmdMedkitUseRequest())
  
  
    
    
    
    
    
    

    
    
    
    
    


[es(tag=input, after=human_input_es, REQUIRE=controlledHero)]
def drop_special_weapon_input_es(evt : EventOnKeyDown;
                                 eid : EntityId;
                                 input__enabled : bool = true;
                                 isAlive : bool = true;
                                 isDowned : bool = false;
                                 isInVehicle : bool = false;
                                 human__controlledDrone : EntityId = INVALID_ENTITY_ID;
                                 human_mining_wall__isPlantingAvailable : bool = false;
                                 human_mining_wall__isReassemblingAvailable : bool = false;
                                 human_weap__currentGunSlot : int = -1;
                                 human_weap__gunEids : EidList)
  if evt.eventId != int(ShortcutEventId.ID_HUMAN_DROP_SPECIAL_WEAPON)
    return
  if !input__enabled || !isAlive || isDowned || isInVehicle || !!human__controlledDrone
    return
  if human_mining_wall__isPlantingAvailable || human_mining_wall__isReassemblingAvailable
    return

  let slotId = int(HUWeaponSlots.EWS_TERTIARY)
  if slotId >= length(human_weap__gunEids)
    return
  let gunEid = human_weap__gunEids[slotId]
  if !gunEid || has(gunEid, "emptyGunHolder")
    return
  
  if human_weap__currentGunSlot != slotId
    return

  send_net_event(eid, HumanDropSpecialWeapRequest(slotId = slotId))
  
  query(gunEid) <| $ [es] (var gun__discardRequestedAtTime : float&)
    gun__discardRequestedAtTime = get_sync_time()
