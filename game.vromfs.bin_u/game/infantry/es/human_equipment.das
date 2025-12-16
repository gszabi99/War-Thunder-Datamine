require ecs
require app
require ecs.safe
require inventory
require ecs.common
require DagorSystem
require CollRes

require %appGame.wt_events
require %appGame.infantry.es.equipment_common
require %appGame.infantry.es.inventory_common


[event(unicast)]
struct EventOnEquipmentUnequiped 
  equipmentEid : EntityId


[es(tag=server, on_appear, REQUIRE=deadEntity)]
def destroy_weapons_on_human_die(evt : Event;
                                 human_weap__gunEids : EidList)
  for weapEid in human_weap__gunEids
    if !!weapEid
      query() <| $ [es(REQUIRE=weaponMod)] (eid : EntityId;
                                            animchar_attach__attachedTo : EntityId)
        if weapEid == animchar_attach__attachedTo
          destroyEntity(eid)
      destroyEntity(weapEid)


[es(on_appear)]
def attach_vis_entity_cb_handler(evt : Event;
                                 eid : EntityId;
                                 attach_vis_entity_cb__toEid : EntityId;
                                 attach_vis_entity_cb__toSlotName : string)
  let found = query(attach_vis_entity_cb__toEid) <| $ [es] (var human_equipment__slots : Object&)
    human_inventory_item_check_hides(eid, human_equipment__slots, +1)
    var itemObj = human_equipment__slots[attach_vis_entity_cb__toSlotName] |> getRW_ecs_object()
    if itemObj != null
      using() <| $(var newEntities : Array)
        var entities = (*itemObj).entities |> getRW_ecs_array()
        if entities != null
          newEntities |> move(*entities)
        newEntities |> push(eid)
        *itemObj |> set("entities", newEntities)

  if !found
    destroyEntity(eid)


def equip_item_direct_impl(item_eid : EntityId;
                           slot_name : string;
                           allow_reorder_slots : bool;
                           drop_prev_item : bool;
                           eid : EntityId;
                           human_equipment__itemRemap : Object;
                           isAlive : bool;
                           possessedByPlr : EntityId;
                           collres : CollisionResource const?;
                           dm_parts__parts : Object const?;
                           entity_mods__bagsVolumeMult : float const?;
                           var human_equipment__slots : Object&;
                           var human_inventory__capacity : float&;
                           var human_inventory__currentVolume : float&;
                           var dm_parts__partsArmor : FloatList?;
                           var dm_parts__armorItemEids : EidList?) : void
  if item_eid != INVALID_ENTITY_ID
    if !doesEntityExist(item_eid) 
      return
    if !is_item_for_slot(item_eid, slot_name)
      logerr("Item <{getEntityTemplateName(item_eid)}> is not equippable for slot '{slot_name}'")
      return

    var hasOwner = false
    query(item_eid) <| $ [es] (item__ownerEid : EntityId)
      hasOwner = (item__ownerEid != INVALID_ENTITY_ID)
    if hasOwner
      return

    if allow_reorder_slots
      try_rotate_to_linked_slot(slot_name, human_equipment__slots)

  var itemObj = getRW_ecs_object(human_equipment__slots, slot_name)
  if itemObj == null
    logerr("Cannot find slot '{slot_name}' in equipment for {eid} <{getEntityTemplateName(eid)}>")
    return

  
  var prevItem = (*itemObj).item ?? INVALID_ENTITY_ID
  if prevItem != INVALID_ENTITY_ID && !doesEntityExist(prevItem)
    prevItem = INVALID_ENTITY_ID
  if (isAlive && has(prevItem, "item__unequipOnlyOnDeath")) || has(prevItem, "item__nonDroppable")
    
    
    return

  if prevItem == item_eid
    return

  query(prevItem) <| $ [es] (item__armorAmount : float;
                             var item__armoredPartsIds : IntList&;
                             var segmented_armor__armoredPartsIds : Array?)
    if item__armorAmount > 0.f && dm_parts__parts != null && dm_parts__partsArmor != null
      for partId in item__armoredPartsIds
        (*dm_parts__partsArmor)[partId] = 0.0f
    clear(item__armoredPartsIds)
    if dm_parts__armorItemEids != null
      let idx = find_index(*dm_parts__armorItemEids, prevItem)
      if idx >= 0
        erase(*dm_parts__armorItemEids, idx)
    if segmented_armor__armoredPartsIds != null
      clear(*segmented_armor__armoredPartsIds)

  var prevInventoryExtention = 0.f
  var newInventoryExtention = 0.f
  query(prevItem) <| $ [es] (item__inventoryExtension aka prev_item__inventoryExtension : float)
    prevInventoryExtention = prev_item__inventoryExtension
  query(item_eid) <| $ [es] (item__inventoryExtension aka new_item__inventoryExtension : float)
    newInventoryExtention = new_item__inventoryExtension
  if entity_mods__bagsVolumeMult != null
    
    prevInventoryExtention = float(roundi(prevInventoryExtention * (*entity_mods__bagsVolumeMult) * 10.f)) / 10.f
    newInventoryExtention = float(roundi(newInventoryExtention * (*entity_mods__bagsVolumeMult) * 10.f)) / 10.f

  if prevInventoryExtention > 0.f
    let resultingCapacity = human_inventory__capacity - prevInventoryExtention + newInventoryExtention
    if resultingCapacity < human_inventory__currentVolume
      return
    human_inventory__capacity = human_inventory__capacity - prevInventoryExtention

  
  
  
  

  
  if prevItem != INVALID_ENTITY_ID
    if possessedByPlr != INVALID_ENTITY_ID
      sendEvent(possessedByPlr, EventOnEquipmentUnequiped(equipmentEid = prevItem))
    if drop_prev_item
      unequip_entity_item(eid, prevItem)

  var entities = (*itemObj).entities |> getRW_ecs_array()
  if entities != null
    for entity in *entities
      let remEid = entity ?? INVALID_ENTITY_ID
      human_inventory_item_check_hides(remEid, human_equipment__slots, -1)
      destroyEntity(remEid)

    if empty(*entities) && prevItem != INVALID_ENTITY_ID
      human_inventory_item_check_hides(prevItem, human_equipment__slots, -1)
    clear(*entities)

  var newSoundTag = ""
  query(item_eid) <| $ [es] (var item__armoredPartsIds : IntList&;
                             var segmented_armor__armoredPartsIds : Array?;
                             @shared_comp segmented_armor__armoredParts : Array const?;
                             item__armoredParts : Array const?;
                             item__soundTag : string = "";
                             item__armorAmount : float = 0.f)
    newSoundTag = item__soundTag
    clear(item__armoredPartsIds)

    
    if dm_parts__armorItemEids != null
      push(*dm_parts__armorItemEids, item_eid)
    if dm_parts__parts != null
      let collNodeCount = collres_get_nodesCount(*collres)
      if item__armoredParts != null
        for part in *item__armoredParts
          let partId = get_part_data_node_id(*dm_parts__parts, get_string(part, ""))
          if partId >= 0 && partId < collNodeCount
            push(item__armoredPartsIds, partId)
            if dm_parts__partsArmor != null
              (*dm_parts__partsArmor)[partId] = item__armorAmount
      if segmented_armor__armoredParts != null && segmented_armor__armoredPartsIds != null
        var uniquePartsIds : table<int, int>
        clear(item__armoredPartsIds)
        for segment in *segmented_armor__armoredParts
          let parts = get_ecs_StringList(segment)
          if parts == null
            push_to_array(*segmented_armor__armoredPartsIds) <| $ [unused_argument(emptyList)] (var emptyList : IntList&) {}
            logerr("Error parsing segmented_armor__armoredParts for {item_eid} ({getEntityTemplateName(eid)}): all entries should be list<t>")
          else
            push_to_array(*segmented_armor__armoredPartsIds) <| $(var partsIds : IntList&)
              for part in *parts
                let partId = get_part_data_node_id(*dm_parts__parts, string(part))
                if partId >= 0 && partId < collNodeCount
                  push(partsIds, partId)
                  insert(uniquePartsIds, partId, 0)
        for uniquePartId in keys(uniquePartsIds)
          push(item__armoredPartsIds, uniquePartId)
          (*dm_parts__partsArmor)[uniquePartId] = item__armorAmount

  query(item_eid) <| $ [es] (item__equipSlots : Object const?)
    if item__equipSlots != null
      for slot in *item__equipSlots
        attach_vis_entity(get_string(slot.value, ""), eid, slot_name, slot.key, human_equipment__itemRemap)
    else
      human_inventory_item_check_hides(item_eid, human_equipment__slots, +1)

  *itemObj |> set("soundTag", newSoundTag)

  query(item_eid) <| $ [es] (var item__ownerEid : EntityId&;
                             var animchar_attach__attachedTo : EntityId?;
                             item__recreateOnGround : string = "item_in_world";
                             item__recreateInEquipment : string = "base_vis_item")
                            
    item__ownerEid = eid
    
    
    let origTemplateName = getEntityTemplateName(item_eid)
    var newTemplateName = origTemplateName
    if !empty(item__recreateOnGround)
      newTemplateName = remove_sub_template_name(newTemplateName, item__recreateOnGround)
    if !empty(item__recreateInEquipment)
      newTemplateName = add_sub_template_name(newTemplateName, item__recreateInEquipment)

    if !empty(newTemplateName) && newTemplateName != origTemplateName
      remote_recreate_entity_from(item_eid, newTemplateName) <| $(init)
        init |> set("animchar_attach__attachedTo", eid)
    elif animchar_attach__attachedTo != null
      *animchar_attach__attachedTo = eid
    else
      logerr("failed to recreate <{getEntityTemplateName(item_eid)}>-<{item__recreateOnGround}> entity {eid}")

    
    
    

  check_and_request_enable_flag(prevItem, item_eid, slot_name, human_equipment__slots, eid)
  if newInventoryExtention > 0.f
    human_inventory__capacity = human_inventory__capacity + newInventoryExtention
  *itemObj |> set("item", item_eid)


[es(tag=server)]
def equip_item_direct(evt : CmdEquipItemDirect;
                      eid : EntityId;
                      human_equipment__itemRemap : Object;
                      collres : CollisionResource const?;
                      dm_parts__parts : Object const?;
                      entity_mods__bagsVolumeMult : float const?;
                      var human_equipment__slots : Object&;
                      var human_inventory__capacity : float&;
                      var human_inventory__currentVolume : float&;
                      var dm_parts__partsArmor : FloatList?;
                      var dm_parts__armorItemEids : EidList?;
                      isAlive : bool = true;
                      possessedByPlr : EntityId = INVALID_ENTITY_ID)
  equip_item_direct_impl(evt.itemEid, evt.slot, evt.allowReorderSlots, evt.dropPrevItem, eid,
                         human_equipment__itemRemap, isAlive, possessedByPlr, collres, dm_parts__parts, entity_mods__bagsVolumeMult,
                         human_equipment__slots, human_inventory__capacity, human_inventory__currentVolume,
                         dm_parts__partsArmor, dm_parts__armorItemEids)


[es(tag=server)]
def equip_item(evt : CmdEquipItem;
               eid : EntityId;
               human_equipment__itemRemap : Object;
               collres : CollisionResource const?;
               dm_parts__parts : Object const?;
               entity_mods__bagsVolumeMult : float const?;
               var human_equipment__slots : Object&;
               var human_inventory__capacity : float&;
               var human_inventory__currentVolume : float&;
               var dm_parts__partsArmor : FloatList?;
               var dm_parts__armorItemEids : EidList?;
               isAlive : bool = true;
               possessedByPlr : EntityId = INVALID_ENTITY_ID)
  if !check_pickup_item_by_uniqueness(eid, evt.itemEid)
    return
  equip_item_direct_impl(evt.itemEid, evt.slotName, false, true, eid,
                         human_equipment__itemRemap, isAlive, possessedByPlr, collres, dm_parts__parts, entity_mods__bagsVolumeMult,
                         human_equipment__slots, human_inventory__capacity, human_inventory__currentVolume,
                         dm_parts__partsArmor, dm_parts__armorItemEids)
