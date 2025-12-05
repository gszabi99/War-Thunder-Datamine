module equipment_common shared
require ecs
require strings
require ecs.safe
require ecs.common
require DagorSystem


def is_item_for_slot(item_eid : EntityId;
                     slot_name : string) : bool
  var res = false
  query(item_eid) <| $ [es] (item__equipToSlots : Array)
    for slot in item__equipToSlots
      if get_string(slot, "") == slot_name
        res = true
        return
  return res

def item_change_hide_counter(hidden_eid : EntityId; hide : int)
  let ok = query(hidden_eid) <| $ [es] (var hide_counter : int&;
                                        var slot_attach__visible : bool&)
    hide_counter += hide
    slot_attach__visible = (hide_counter == 0)

  if !ok
    let missingComps = build_string() <| $(str)
      str |> write(has(hidden_eid, "hide_counter") ? "" : "'hide_counter'")
      str |> write(" ")
      str |> write(has(hidden_eid, "slot_attach__visible") ? "" : "'slot_attach.visible'")
    logerr("Item <{getEntityTemplateName(hidden_eid)}> with eid {hidden_eid} should be hidden but doesn't have {missingComps} components")

def get_part_data_node_id(parts : Object;
                          part_name : string) : int
  var part = get_ecs_object(parts, part_name)
  if part == null
    return -1

  return (*part).collNodeId ?? -1


def swap_equipment(eq_eid : EntityId;
                   from_slot_name : string;
                   to_slot_name : string;
                   var human_equipment__slots : Object&)
  if from_slot_name == to_slot_name
    return false
  if eq_eid != INVALID_ENTITY_ID && (!doesEntityExist(eq_eid) || !is_item_for_slot(eq_eid, to_slot_name))
    return false

  var itFrom = getRW_ecs_object(human_equipment__slots, from_slot_name)
  var itTo = getRW_ecs_object(human_equipment__slots, to_slot_name)

  if itFrom == null
    logerr("Cannot find slot '{from_slot_name}' in equipment")
    return false
  if itTo == null
    logerr("Cannot find slot '{to_slot_name}' in equipment")
    return false

  let itemInTo = (*itTo).item ?? INVALID_ENTITY_ID
  if itemInTo != INVALID_ENTITY_ID && !is_item_for_slot(itemInTo, from_slot_name)
    return false

  using() <| $(var tmp : Object)
    var fromPtr = (*itFrom).value |> getRW_ecs_object()
    var toPtr = (*itTo).value |> getRW_ecs_object()
    if fromPtr != null && toPtr != null
      tmp |> move(*fromPtr)
      *fromPtr |> move(*toPtr)
      *toPtr |> move(tmp)
  return true


def try_rotate_to_linked_slot(slot_name : string;
                              var human_equipment__slots : Object&) : bool
  let slot = get_ecs_object(human_equipment__slots, slot_name)
  if slot == null
    logerr("Cannot find slot '{slot_name}' in equipment")
    return false

  let itemEid = (*slot).item ?? INVALID_ENTITY_ID
  let rotate = (*slot).linkedSlot ?? ""

  if itemEid == INVALID_ENTITY_ID || empty(rotate)
    return false

  let rotateTo = get_ecs_object(human_equipment__slots, rotate)
  if rotateTo == null
    return false

  let rotateToItem = (*rotateTo).item ?? INVALID_ENTITY_ID
  if rotateToItem == INVALID_ENTITY_ID
    return false

  let rotateToSlot := rotate 
  swap_equipment(itemEid, slot_name, rotateToSlot, human_equipment__slots)
  return true


def check_equpment_allowed(human_eid : EntityId;
                           new_perk_name : string) : bool
  var allowed = true
  find_query() <| $ [es] (game_effect__attachedTo : EntityId;
                          disableArtifacts : Array)
    if game_effect__attachedTo != human_eid
      return false
    for name in disableArtifacts
      if get_string(name, "") == new_perk_name
        allowed = false
        return true
    return true

  return allowed


def check_equpment_allowed_by_id(human_eid : EntityId;
                                 equip_eid : EntityId) : bool
  var allowed = true
  query(equip_eid) <| $ [es] (item__perkName : string)
    allowed = allowed && check_equpment_allowed(human_eid, item__perkName)
  return allowed


def item_check_hides_impl(hidden_eid : EntityId;
                          item_flag : string;
                          hide : int;
                          slot_item_flags : Array) : void
  var haveFlagMatches = false
  for slotItemFlag in slot_item_flags
    let slotItemFlagStr = get_string(slotItemFlag, "")
    if item_flag == slotItemFlagStr
      haveFlagMatches = true
      break

  if !haveFlagMatches
    return

  item_change_hide_counter(hidden_eid, hide)


def item_check_hides(item_eid : EntityId;
                     item_flag : string;
                     item_hides : bool;
                     hide : int;
                     slot_item_eid : EntityId) : void
  if item_hides
    query(slot_item_eid) <| $ [es] (hideFlags : Array)
      item_check_hides_impl(slot_item_eid, item_flag, hide, hideFlags)
  else
    query(slot_item_eid) <| $ [es] (hides : Array)
      item_check_hides_impl(item_eid, item_flag, hide, hides)


def human_inventory_item_check_hides(item_eid : EntityId;
                                     item_flag : string;
                                     item_hides : bool;
                                     human_equipment__slots : Object;
                                     hide : int) : void
  for slotItem in human_equipment__slots
    let slotItemObj = slotItem.value |> get_ecs_object()
    if slotItemObj != null
      let entities = (*slotItemObj).entities |> get_ecs_array()
      if entities != null
        for entity in *entities
          let slotItemEid = entity ?? INVALID_ENTITY_ID
          item_check_hides(item_eid, item_flag, item_hides, hide, slotItemEid)

      let slotItemEid = (*slotItemObj).item ?? INVALID_ENTITY_ID
      if slotItemEid != INVALID_ENTITY_ID
        item_check_hides(item_eid, item_flag, item_hides, hide, slotItemEid)



def human_inventory_item_check_hides(item_eid : EntityId;
                                     human_equipment__slots : Object;
                                     hide : int) : void
  query(item_eid) <| $ [es] (hides : Array)
    for hideFlag in hides
      human_inventory_item_check_hides(item_eid, get_string(hideFlag, ""), true, human_equipment__slots, hide)

  if hide > 0
    query(item_eid) <| $ [es] (hideFlags : Array)
      for hideFlag in hideFlags
        human_inventory_item_check_hides(item_eid, get_string(hideFlag, ""), false, human_equipment__slots, hide)
  else
    query(item_eid) <| $ [es] (var slot_attach__visible : bool&)
      slot_attach__visible = true


def attach_vis_entity(animchar_slot : string;
                      to_eid : EntityId;
                      slot_name : string;
                      template_name : string;
                      item_remap : Object) : void
  using() <| $(var init : ComponentsInitializer)
    if !empty(animchar_slot) 
      init |> set("slot_attach__slotName", animchar_slot)
    init |> set("animchar_attach__attachedTo", to_eid)

    var templName := template_name
    if item_remap[template_name] != null
      templName = item_remap[template_name] ?? ""

    init |> set("attach_vis_entity_cb__toEid", to_eid)
    init |> set("attach_vis_entity_cb__toSlotName", slot_name)
    createEntity(add_sub_template_name(templName, "attach_vis_entity_cb"), init)


def check_and_request_enable_flag(prev_item_eid : EntityId;
                                  new_item_eid : EntityId;
                                  slot_name : string;
                                  slots : Object;
                                  eid : EntityId) : void
  query(prev_item_eid) <| $ [es] (item_mods__enableFlag aka flagToRemove_item_mods__enableFlag : string;
                                  item_mods__eidComp : das_string const?)
    
    var shouldRemove = true
    for slot in slots
      if slot.key == slot_name
        continue
      let slotObj = get_ecs_object(slot.value)
      let item = slotObj?.item ?? INVALID_ENTITY_ID
      query(item) <| $ [es] (item_mods__enableFlag : string)
        if item_mods__enableFlag == flagToRemove_item_mods__enableFlag
          shouldRemove = false
      if !shouldRemove
        break

    if shouldRemove
      var flag = getRW_bool(eid, flagToRemove_item_mods__enableFlag, ecs_hash(flagToRemove_item_mods__enableFlag))
      if flag != null
        *flag = false
      if item_mods__eidComp != null
        var eidComp = getRW_Eid(eid, string(*item_mods__eidComp), ecs_hash(string(*item_mods__eidComp)))
        if eidComp != null
          *eidComp = INVALID_ENTITY_ID

  query(new_item_eid) <| $ [es] (item_mods__enableFlag aka flagToAdd_item_mods__enableFlag : string;
                                 item_mods__eidComp : das_string const?)
    let activate = check_equpment_allowed_by_id(eid, new_item_eid)
    var flag = getRW_bool(eid, flagToAdd_item_mods__enableFlag, ecs_hash(flagToAdd_item_mods__enableFlag))
    if flag != null
      *flag = activate
    if item_mods__eidComp != null
      var eidComp = getRW_Eid(eid, string(*item_mods__eidComp), ecs_hash(string(*item_mods__eidComp)))
      if eidComp != null
        *eidComp = new_item_eid
