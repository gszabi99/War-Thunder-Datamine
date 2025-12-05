require ecs
require WTInput
require %game.input.input_events

require %appGame.wt_events
require %appGame.infantry.es.inventory_common
require net


[es(tag=input, after=human_input_es, REQUIRE=controlledHero)]
def human_inventory_input_action_triggered_es(evt : EventOnKeyDown;
                                              eid : EntityId;
                                              
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
    
    
  elif action == int(ShortcutEventId.ID_HUMAN_USE_MEDKIT) && heal__continuousInput
    send_net_event(eid, CmdMedkitUseRequest())
  
  
    
    
    
    
    
    

    
    
    
    
    
