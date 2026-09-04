require ecs
require ecs.common
require math.base
require inventory
require app
require AppTime
require DngHuman
require DagorMath
require PropsManager
require WeapHelpers

require %appGame.wt_events
require %appGame.infantry.es.human_weap_common


def cleanup_dropped_gun(gun_eid : EntityId; var item_container : EidList)
  query(gun_eid) <| $ [es] (gun__ammoHolderIds : IntList const?;
                            gun__shell_prop_ids : PropsIdList const?;
                            gun__ammoHolderEid : EntityId = INVALID_ENTITY_ID)
    if !!gun__ammoHolderEid
      destroyEntity(gun__ammoHolderEid)
    let matchAmmo = gun__ammoHolderIds != null && gun__shell_prop_ids != null
    var idx = length(item_container) - 1
    while idx >= 0
      let itemEid = item_container[idx]
      if itemEid == gun_eid
        erase(item_container, idx)
      elif matchAmmo
        var isAmmo = false
        query(itemEid) <| $ [es] (ammo_holder__id : int = INVALID_ITEM_ID;
                                  shell_props : PropsId const? = null)
          isAmmo = ((ammo_holder__id != INVALID_ITEM_ID && is_ammo_for_gun(ammo_holder__id, *gun__ammoHolderIds)) ||
                    (shell_props != null && is_shell_for_gun(*shell_props, *gun__shell_prop_ids)))
        if isAmmo
          erase(item_container, idx)
          destroyEntity(itemEid)
      idx--




[es(tag=server, REQUIRE=(human_inventory, human_weap))]
def human_drop_special_weap_request_es(evt : HumanDropSpecialWeapRequest;
                                       eid : EntityId;
                                       isAlive : bool = true;
                                       isDowned : bool = false;
                                       isInVehicle : bool = false;
                                       human__controlledDrone : EntityId = INVALID_ENTITY_ID;
                                       human_weap__currentGunSlot : int = -1;
                                       human_weap__gunEids : EidList;
                                       var itemContainer : EidList&)
  
  if evt.slotId != int(HUWeaponSlots.EWS_TERTIARY)
    return
  if !isAlive || isDowned || isInVehicle || !!human__controlledDrone
    return
  if evt.slotId >= length(human_weap__gunEids)
    return

  let gunEid = human_weap__gunEids[evt.slotId]
  if !gunEid || has(gunEid, "emptyGunHolder")
    return
  
  if human_weap__currentGunSlot != evt.slotId
    return

  let isDroneLauncher = has(gunEid, "drone_launcher")

  cleanup_dropped_gun(gunEid, itemContainer)
  var nullCustomProps : Object? = null
  
  human_weap_set_item_to_slot(eid, "", "", evt.slotId, nullCustomProps)

  if !isDroneLauncher
    return

  
  let specialSlot = int(HUWeaponSlots.EWS_SPECIAL)
  if specialSlot < length(human_weap__gunEids) && has(human_weap__gunEids[specialSlot], "tactical_phone")
    human_weap_set_item_to_slot(eid, "", "", specialSlot, nullCustomProps)
