require ecs
require ecs.safe
require ecs.common
require strings
require %appGame.infantry.es.equipment_common
require %appGame.infantry.es.animchar.attach_common





def private is_local_wear_item(item_eid : EntityId)
  return has(item_eid, "clientLocalWearItem")

def private local_wear_template(base_template : string)
  return add_sub_template_name(base_template, "client_local_wear_item")

def private apply_client_wear_hides_flags(item_eid : EntityId;
                                          flags : Array;
                                          item_hides : bool;
                                          hide : int;
                                          human_equipment__clientSlots : Object)
  let itemIsLocal = is_local_wear_item(item_eid)
  for f in flags
    let flag = get_string(f, "")
    if flag == ""
      continue
    for kv in human_equipment__clientSlots
      let otherEid = (kv.value as Object)?.item ?? INVALID_ENTITY_ID
      if otherEid == INVALID_ENTITY_ID || otherEid == item_eid
        continue
      if !itemIsLocal && !is_local_wear_item(otherEid)
        continue 
      item_check_hides(item_eid, flag, item_hides, hide, otherEid)


def private apply_client_wear_hides(item_eid : EntityId;
                                    human_equipment__clientSlots : Object;
                                    hide : int)
  query(item_eid) <| $ [es] (hides : Array)
    apply_client_wear_hides_flags(item_eid, hides, true, hide, human_equipment__clientSlots)
  if hide > 0
    query(item_eid) <| $ [es] (hideFlags : Array)
      apply_client_wear_hides_flags(item_eid, hideFlags, false, hide, human_equipment__clientSlots)

def private reapply_client_wear_remap(human_equipment__clientSlots : Object)
  for kv in human_equipment__clientSlots
    let itemEid = (kv.value as Object)?.item ?? INVALID_ENTITY_ID
    query(itemEid) <| $ [es] (skeleton_attach__remapParentSlots : StringList;
                              var animchar_attach__attachedTo : EntityId&)
      skeleton_attach_with_remap_parent_impl(itemEid,
                                             skeleton_attach__remapParentSlots,
                                             human_equipment__clientSlots,
                                             animchar_attach__attachedTo)

def private register_client_wear_item(slot : string;
                                      item_eid : EntityId;
                                      var human_equipment__clientSlots : Object&;
                                      created_template = "")
  using() <| $(var slotObj : Object)
    slotObj |> set("item", item_eid)
    if created_template != "" 
      slotObj |> set("templ", created_template)
    human_equipment__clientSlots |> set(slot, slotObj)
  apply_client_wear_hides(item_eid, human_equipment__clientSlots, 1)
  reapply_client_wear_remap(human_equipment__clientSlots)
  apply_slots_scale_attaches(human_equipment__clientSlots)

def private unregister_client_wear_item(slot : string;
                                        item_eid : EntityId;
                                        soldier_eid : EntityId;
                                        var human_equipment__clientSlots : Object&)
  if !!item_eid
    apply_client_wear_hides(item_eid, human_equipment__clientSlots, -1)
  human_equipment__clientSlots |> erase(slot)
  reapply_client_wear_remap(human_equipment__clientSlots)
  apply_slots_scale_attaches(human_equipment__clientSlots)
  
  for kv in human_equipment__clientSlots
    let otherEid = (kv.value as Object)?.item ?? INVALID_ENTITY_ID
    query(otherEid) <| $ [es] (var animchar_attach__attachedTo : EntityId&)
      if animchar_attach__attachedTo == item_eid
        animchar_attach__attachedTo = soldier_eid

def private find_client_wear_slot(item_eid : EntityId; human_equipment__clientSlots : Object)
  for kv in human_equipment__clientSlots
    if ((kv.value as Object)?.item ?? INVALID_ENTITY_ID) == item_eid
      let out = clone_string(kv.key)
      return out
  return ""

def private register_replicated_wear_item(item_eid : EntityId;
                                          item__equipToSlots : Array;
                                          soldier_eid : EntityId;
                                          var human_equipment__clientSlots : Object&)
  if find_client_wear_slot(item_eid, human_equipment__clientSlots) != ""
    return
  for slotIt in item__equipToSlots
    let slot = get_string(slotIt, "")
    if slot == ""
      continue
    let curEid = (human_equipment__clientSlots[slot] ?as Object)?.item ?? INVALID_ENTITY_ID
    if curEid != INVALID_ENTITY_ID && doesEntityExist(curEid)
      if !is_local_wear_item(curEid)
        continue 
      
      unregister_client_wear_item(slot, curEid, soldier_eid, human_equipment__clientSlots)
      destroyEntity(curEid)
    register_client_wear_item(slot, item_eid, human_equipment__clientSlots)
    return

def private create_missing_local_wear(soldier_eid : EntityId;
                                      human_equipment__wearTemplates : Object;
                                      var human_equipment__clientSlots : Object&)
  let soldierEid = soldier_eid
  for kv in human_equipment__wearTemplates
    let templ = kv.value ?? ""
    if templ == ""
      continue
    let slotName = clone_string(kv.key)
    let curEid = (human_equipment__clientSlots[slotName] ?as Object)?.item ?? INVALID_ENTITY_ID
    if curEid != INVALID_ENTITY_ID && doesEntityExist(curEid)
      continue 
    let templName = local_wear_template(string(templ))
    let finalizeCreation <- @ <| (itemEid : EntityId)
      var registered = false
      query(soldierEid) <| $ [es] (human_equipment__wearTemplates aka owner_human_equipment__wearTemplates : Object;
                                   var human_equipment__clientSlots aka owner_human_equipment__clientSlots : Object&)
        let wantTemplate = owner_human_equipment__wearTemplates[slotName] ?? ""
        let wantLocalTemplate = wantTemplate != "" ? local_wear_template(string(wantTemplate)) : ""
        let occupiedEid = (owner_human_equipment__clientSlots[slotName] ?as Object)?.item ?? INVALID_ENTITY_ID
        if wantLocalTemplate == templName && (occupiedEid == INVALID_ENTITY_ID || !doesEntityExist(occupiedEid))
          register_client_wear_item(slotName, itemEid, owner_human_equipment__clientSlots, templName)
          registered = true
      if !registered 
        destroyEntity(itemEid)
    createEntity(templName, finalizeCreation) <| $(var init : ComponentsInitializer)
      set(init, "animchar_attach__attachedTo", soldierEid)
      set(init, "item__ownerEid", soldierEid)
      set(init, "item__lastOwner", soldierEid)

[es(tag=gameClient, on_appear, track=human_equipment__wearTemplates)]
def client_wear_equipment_update_es(evt : Event;
                                    eid : EntityId;
                                    human_equipment__wearTemplates : Object;
                                    var human_equipment__clientSlots : Object&)
  
  using() <| $(var staleSlots : Array)
    for kv in human_equipment__clientSlots
      let itemEid = (kv.value as Object)?.item ?? INVALID_ENTITY_ID
      if doesEntityExist(itemEid) && !is_local_wear_item(itemEid) 
        continue
      let wantTemplate = human_equipment__wearTemplates[string(kv.key)] ?? ""
      let wantLocalTemplate = wantTemplate != "" ? local_wear_template(string(wantTemplate)) : ""
      let createdTemplate = (kv.value as Object)?.templ ?? ""
      if !doesEntityExist(itemEid) || wantLocalTemplate != createdTemplate
        staleSlots |> push(clone_string(kv.key))
    for slotIt in staleSlots
      let slot = get_string(slotIt, "")
      let itemEid = (human_equipment__clientSlots[slot] ?as Object)?.item ?? INVALID_ENTITY_ID
      unregister_client_wear_item(slot, itemEid, eid, human_equipment__clientSlots)
      destroyEntity(itemEid)

  
  let soldierEid = eid
  query() <| $ [es(REQUIRE_NOT=clientLocalWearItem)] (eid aka wear_item_eid : EntityId;
                                                      item__ownerEid : EntityId;
                                                      item__equipToSlots : Array)
    if item__ownerEid == soldierEid
      register_replicated_wear_item(wear_item_eid, item__equipToSlots, soldierEid, human_equipment__clientSlots)

  create_missing_local_wear(eid, human_equipment__wearTemplates, human_equipment__clientSlots)


[es(tag=gameClient, on_appear, track=item__ownerEid, REQUIRE_NOT=clientLocalWearItem)]
def client_wear_replicated_item_es(evt : Event;
                                   eid : EntityId;
                                   item__ownerEid : EntityId;
                                   item__lastOwner : EntityId;
                                   item__equipToSlots : Array)
  let itemEid = eid
  if item__lastOwner != INVALID_ENTITY_ID && item__lastOwner != item__ownerEid
    query(item__lastOwner) <| $ [es] (human_equipment__wearTemplates : Object;
                                      var human_equipment__clientSlots : Object&)
      let slot = find_client_wear_slot(itemEid, human_equipment__clientSlots)
      if slot != ""
        unregister_client_wear_item(slot, itemEid, item__lastOwner, human_equipment__clientSlots)
        create_missing_local_wear(item__lastOwner, human_equipment__wearTemplates, human_equipment__clientSlots)
  if item__ownerEid == INVALID_ENTITY_ID
    return
  query(item__ownerEid) <| $ [es] (var human_equipment__clientSlots : Object&)
    register_replicated_wear_item(itemEid, item__equipToSlots, item__ownerEid, human_equipment__clientSlots)


[es(tag=gameClient, track=animchar_attach__attachedTo, REQUIRE_NOT=clientLocalWearItem)]
def client_wear_replicated_reattach_es(evt : Event;
                                       eid : EntityId;
                                       item__ownerEid : EntityId;
                                       skeleton_attach__remapParentSlots : StringList;
                                       var animchar_attach__attachedTo : EntityId&)
  let itemEid = eid
  query(item__ownerEid) <| $ [es] (human_equipment__clientSlots : Object)
    skeleton_attach_with_remap_parent_impl(itemEid,
                                           skeleton_attach__remapParentSlots,
                                           human_equipment__clientSlots,
                                           animchar_attach__attachedTo)

[es(tag=gameClient, REQUIRE=item__equipToSlots, REQUIRE_NOT=clientLocalWearItem, on_event=EventEntityDestroyed)]
def client_wear_replicated_item_destroyed_es(evt : Event;
                                             eid : EntityId;
                                             item__ownerEid : EntityId)
  let itemEid = eid
  query(item__ownerEid) <| $ [es] (human_equipment__wearTemplates : Object;
                                   var human_equipment__clientSlots : Object&)
    let slot = find_client_wear_slot(itemEid, human_equipment__clientSlots)
    if slot != ""
      unregister_client_wear_item(slot, itemEid, item__ownerEid, human_equipment__clientSlots)
      create_missing_local_wear(item__ownerEid, human_equipment__wearTemplates, human_equipment__clientSlots)

[es(tag=gameClient, on_disappear)]
def client_wear_equipment_cleanup_es(evt : Event;
                                     human_equipment__clientSlots : Object)
  for kv in human_equipment__clientSlots
    let itemEid = (kv.value as Object)?.item ?? INVALID_ENTITY_ID
    if !!itemEid && is_local_wear_item(itemEid) && doesEntityExist(itemEid)
      destroyEntity(itemEid)
