require ecs
require %appGame.wt_events
require %appGame.wt_events
require %appGame.infantry.es.inventory_common
require %appGame.infantry.es.human_weap_common


def get_gunMod_eid_by_slot(slot : int; slotName : string; gunMods : Array)
  var resultEid = INVALID_ENTITY_ID
  let modList = get_ecs_EidList(gunMods[slot])
  if modList == null
    return INVALID_ENTITY_ID
  for modEid in *modList
    query(modEid) <| $ [es] (gunAttachable__slotName : string)
      if gunAttachable__slotName == slotName
        resultEid = modEid
    if resultEid != INVALID_ENTITY_ID
      break
  return resultEid


def switch_weap_mod(eid : EntityId; itemEid : EntityId; curGunEid : EntityId; curSlot : int; slotName : string; gunMods : Array)
  if is_item_useful(eid, itemEid)
    return false
  if !is_gunmod_allowed(curGunEid, itemEid)
    return false
  if get_gunMod_eid_by_slot(curSlot, slotName, gunMods) == INVALID_ENTITY_ID
    return false
  return true


[es(tag=server)]
def pickup_gun_mod_es(evt : CmdInventoryPickupGunMod;
                      eid : EntityId;
                      human_weap__currentGunSlot : int;
                      human_weap__gunMods : Array;
                      human_weap__currentGunEid : EntityId)
  let itemEid = evt.item
  if human_weap__currentGunSlot < 0
    pickup_item(eid, itemEid)
    return
  let curSlot = human_weap__currentGunSlot
  let curGunEid = human_weap__currentGunEid
  query(itemEid) <| $ [es] (gunAttachable__slotName : string)
    if switch_weap_mod(eid, itemEid, curGunEid, curSlot, gunAttachable__slotName, human_weap__gunMods)
      let toGround = !can_pickup_item_by_volume(itemEid, eid)
      remove_item_from_weap_impl(eid, curSlot, gunAttachable__slotName, toGround)
      pickup_and_install_item_on_weap_impl(eid, itemEid, curSlot, gunAttachable__slotName)
      return

    pickup_item(eid, itemEid)
