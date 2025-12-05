module grenade_thrower_common shared
require ecs
require %game.events
require net
require HumanPhys
require WeapHelpers
require inventory

def anim_attach(var slot_attach__slotId : int&;
                eid : EntityId;
                slot_id : int;
                attach_eid : EntityId)
  query(attach_eid) <| $ [es] (var animchar_attach__attachedTo : EntityId&)
    animchar_attach__attachedTo = eid
  slot_attach__slotId = slot_id


def anim_detach(var slot_attach__slotId : int&;
                attach_eid : EntityId)
  query(attach_eid) <| $ [es] (var animchar_attach__attachedTo : EntityId&)
    animchar_attach__attachedTo = INVALID_ENTITY_ID
  slot_attach__slotId = -1


def attach_projectile(owner_eid : EntityId;
                      gun_eid : EntityId;
                      projectile_entity : EntityId;
                      attach : bool;
                      have_ammo : bool)
  var result = false
  query(projectile_entity) <| $ [es] (gun_attach__mainSlotId : int;
                                      gun_attach__holsterSlotsIds : IntList const?;
                                      var slot_attach__slotId : int&;
                                      var gun__visible : bool&)
    if attach
      anim_attach(slot_attach__slotId, owner_eid, gun_attach__mainSlotId, projectile_entity)
    elif have_ammo && gun_attach__holsterSlotsIds != null && (*gun_attach__holsterSlotsIds)[int(HUWeaponSlots.EWS_GRENADE)] >= 0
      anim_attach(slot_attach__slotId, owner_eid, (*gun_attach__holsterSlotsIds)[int(HUWeaponSlots.EWS_GRENADE)], projectile_entity)
    else
      anim_detach(slot_attach__slotId, projectile_entity)

    gun__visible = attach && get_bool(owner_eid, "human_weap__throwMode") ?? false
    if attach && gun_eid != INVALID_ENTITY_ID
      set(gun_eid, "human_gun_attached", true)
    result = true
  return result


def obtain_grenade_thrower_projectile_entity(var grenade_thrower__projectileEntity : EntityId&)
  if !doesEntityExist(grenade_thrower__projectileEntity)
    return INVALID_ENTITY_ID
  setOptional(grenade_thrower__projectileEntity, "gun__visible", false)
  sendEvent(grenade_thrower__projectileEntity, CmdSlotDetach())
  let ent = grenade_thrower__projectileEntity
  grenade_thrower__projectileEntity = INVALID_ENTITY_ID
  return ent



























































































































def grenade_thrower_select_current_grenade(human_eid : EntityId;
                                           grenade_thrower_eid : EntityId)
  query(human_eid) <| $ [es] (itemContainer : EidList)
    query(grenade_thrower_eid) <| $ [es(REQUIRE=grenade_thrower)] (gun__ammoHolderIds : IntList&;
                                                                   gun__shell_prop_ids : PropsIdList&;
                                                                   grenade_thrower__currentGrenadeTypeIndex : int)
      grenade_thrower_select_grenade(human_eid, itemContainer, gun__ammoHolderIds, gun__shell_prop_ids, grenade_thrower__currentGrenadeTypeIndex)

def grenade_thrower_select_next_grenade(human_eid : EntityId;
                                        grenade_thrower_eid : EntityId)
  query(human_eid) <| $ [es] (itemContainer : EidList)
    query(grenade_thrower_eid) <| $ [es(REQUIRE=grenade_thrower)] (gun__ammoHolderIds : IntList&;
                                                                   gun__shell_prop_ids : PropsIdList&;
                                                                   grenade_thrower__grenadeTypesCount : int;
                                                                   grenade_thrower__currentGrenadeTypeIndex : int)
      let grenadeIndexToSelect = (grenade_thrower__currentGrenadeTypeIndex + 1) % grenade_thrower__grenadeTypesCount
      grenade_thrower_select_grenade(human_eid, itemContainer, gun__ammoHolderIds, gun__shell_prop_ids, grenadeIndexToSelect)

def grenade_thrower_select_grenade(human_eid : EntityId;
                                   itemContainer : EidList;
                                   gun__ammoHolderIds : IntList;
                                   gun__shell_prop_ids : PropsIdList;
                                   grenade_index_to_select : int)
  gather_ammo_for_gun(gun__ammoHolderIds, gun__shell_prop_ids, itemContainer) <| $(ammoItems)
    let ammoItemsCount = length(ammoItems)
    let wishItemIndex = grenade_index_to_select % ammoItemsCount
    let wishItemId = (ammoItemsCount == 0) ? INVALID_ITEM_ID : ammoItems[wishItemIndex]
    send_net_event(human_eid, HumanRequestSetWishAmmoItemType(slot_id = int(HUWeaponSlots.EWS_GRENADE), item_id = wishItemId))
