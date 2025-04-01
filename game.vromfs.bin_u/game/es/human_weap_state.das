require ecs
require ecs.common
require app
require %game.events
require %appGame.es.human_weap_common

require inventory
require net
require DagorSystem
require DngHuman
require DngWeapon
require %game.events
require HumanPhys
require WeapHelpers
require Weapon
require DagorSystem

def set_wish_ammo_item_type(gun_eid : ecs::EntityId; item_id : int)
  var changed = false
  query(gun_eid) <| $ [es(REQUIRE=gun)] (var gun__wishAmmoItemType : int&)
    changed = gun__wishAmmoItemType != item_id
    gun__wishAmmoItemType = item_id
  return changed


def set_ammo_type(slot_id : int;
                  item_id : int;
                  human_weap__gunEids : EidList;
                  owner_eid : EntityId)
  if slot_id < 0 || slot_id >= length(human_weap__gunEids)
    return

  if set_wish_ammo_item_type(human_weap__gunEids[slot_id], item_id)
    request_unload_ammo(owner_eid, slot_id)
    sendEvent(owner_eid, [[CmdRequestReload atTime=get_sync_time(), gunEid=human_weap__gunEids[slot_id], isQuick = false]])



[es(tag=server, REQUIRE=grenade_thrower, no_order)]
def update_switch_grenade_es(evt : UpdateStageInfoAct;
                             eid : EntityId;
                             gun__owner : EntityId;
                             var grenade_thrower__wishProjectileId : int&)
  if grenade_thrower__wishProjectileId == 0
    return

  query(gun__owner) <| $ [es] (human_net_phys : HumanActor; human_weap__gunEids : EidList)
    if human_net_phys.phys.currentState.weapEquipState.curState == HUWeaponEquipState EES_EQUIPING
      set_ammo_type(int(HUWeaponSlots EWS_GRENADE), grenade_thrower__wishProjectileId, human_weap__gunEids, gun__owner)
      take_grenade_in_hand(gun__owner, eid)
      grenade_thrower__wishProjectileId = 0

def try_take_grenade_in_hand(eid aka owner_eid : ecs::EntityId;
                             grenade_thrower_eid : EntityId;
                             wish_item_id : int;
                             human_weap__fastThrowExclusive : bool;
                             human_weap__throwMode : bool;
                             var human_net_phys : HumanActor;
                             is_grenade_thrower_current_weapon : bool)
  let isGrenade = has(grenade_thrower_eid, "grenade_thrower")
  if !isGrenade || human_weap__fastThrowExclusive || human_weap__throwMode
    return false

  let wishAmmoItemType = get_int(grenade_thrower_eid, "gun__wishAmmoItemType") ?? INVALID_ITEM_ID
  let retakeGrenade = !is_grenade_thrower_current_weapon || (wishAmmoItemType != wish_item_id)

  if is_grenade_thrower_current_weapon && retakeGrenade
    query(grenade_thrower_eid) <| $ [es(REQUIRE=grenade_thrower)] (var grenade_thrower__wishProjectileId : int?)
      if grenade_thrower__wishProjectileId != null
        *grenade_thrower__wishProjectileId = wish_item_id
      human_net_phys.phys.currentState.weapEquipState.progress = 0f
      human_net_phys.phys.currentState.weapEquipState.curState = HUWeaponEquipState EES_HOLSTERING
    return false

  if retakeGrenade
    set_wish_ammo_item_type(grenade_thrower_eid, wish_item_id)
    if !take_grenade_in_hand(eid, grenade_thrower_eid)
      return false

  return true














































[es]
def human_weap_wish_ammo_es(evt : CmdSetWishAmmoItemType;
                            eid aka owner_eid : ecs::EntityId;
                            human_weap__grenadeThrower : EntityId;
                            human_weap__currentGunEid : EntityId;
                            human_weap__gunEids : ecs::EidList;
                            human_weap__fastThrowExclusive : bool;
                            human_weap__throwMode : bool;
                            var human_net_phys : HumanActor)
  let slotId = evt.slot_id
  let itemId = evt.item_id

  if !is_server()
    send_net_event(eid, [[HumanRequestSetWishAmmoItemType slot_id=slotId, item_id=itemId]])
    return 

  if !try_take_grenade_in_hand(eid, human_weap__grenadeThrower, itemId,
                            human_weap__fastThrowExclusive,
                            human_weap__throwMode,
                            human_net_phys,
                            human_weap__currentGunEid == human_weap__grenadeThrower)
    set_ammo_type(slotId, itemId, human_weap__gunEids, owner_eid)

[es]
def human_weap_toggle_wish_ammo_es(evt : CmdToggleWishAmmoItemType;
                                   eid : ecs::EntityId;
                                   itemContainer : ecs::EidList;
                                   human_weap__gunEids : ecs::EidList;
                                   human_net_phys : HumanActor)
  let slotId = evt.slot_id
  if slotId < 0 || (slotId >= length(human_weap__gunEids)) || (human_weap__gunEids[slotId] == INVALID_ENTITY_ID)
    return

  let gunEid = human_weap__gunEids[slotId]
  query(gunEid) <| $ [es(REQUIRE=gun)] (gun__ammoHolderIds : IntList&;
                                        gun__shell_prop_ids : PropsIdList&;
                                        gun__wishAmmoItemType : int = INVALID_ITEM_ID)
    gather_ammo_for_gun(gun__ammoHolderIds, gun__shell_prop_ids, itemContainer) <| $(ammoItems)
      let ammoItemsCount = length(ammoItems)
      let isGrenadeSlotCurrent = human_net_phys.phys.currentState.weapEquipState.effectiveCurSlot == HUWeaponSlots EWS_GRENADE
      var curSlot = ammoItems |> find_index(gun__wishAmmoItemType)
      if curSlot < 0
        curSlot = 0 
      let wishSlot = isGrenadeSlotCurrent ? curSlot + 1 : curSlot
      let wishItemId = (ammoItemsCount == 0) ? INVALID_ITEM_ID : ammoItems[(wishSlot) % ammoItemsCount]
      sendEvent(eid, [[CmdSetWishAmmoItemType slot_id=slotId, item_id=wishItemId]])

[es(on_appear, track=(human_weap__grenadeThrower, itemContainer), REQUIRE=itemContainer, tag=server)]
def init_grenade_thrower_ammo_on_init(evt : Event;
                                      eid : EntityId;
                                      human_weap__grenadeThrower : ecs::EntityId)
  query(human_weap__grenadeThrower) <| $ [es(REQUIRE=gun)] (grenade_thrower__projectileEntity : EntityId)
    if !grenade_thrower__projectileEntity
      reload_projectile(eid, human_weap__grenadeThrower)

[es]
def human_weap_req_wish_ammo_es(evt : HumanRequestSetWishAmmoItemType;
                                eid aka owner_eid : ecs::EntityId;
                                human_weap__grenadeThrower : EntityId;
                                human_weap__currentGunEid : EntityId;
                                human_weap__gunEids : ecs::EidList;
                                human_weap__fastThrowExclusive : bool;
                                human_weap__throwMode : bool;
                                var human_net_phys : HumanActor)
  let slotId = evt.slot_id
  let itemId = evt.item_id
  if !try_take_grenade_in_hand(eid, human_weap__grenadeThrower, itemId,
                               human_weap__fastThrowExclusive,
                               human_weap__throwMode,
                               human_net_phys,
                               human_weap__currentGunEid == human_weap__grenadeThrower)
    set_ammo_type(slotId, itemId, human_weap__gunEids, owner_eid)


def review_weap_gun_wish_ammo_item_type(itemContainer : ecs::EidList;
                                        human_weap__gunEids : ecs::EidList)
  for gunEid in human_weap__gunEids
    if gunEid == INVALID_ENTITY_ID
      continue

    query(gunEid) <| $ [es(REQUIRE=gun)] (gun__ammoHolderIds : IntList&;
                                          gun__shell_prop_ids : PropsIdList&;
                                          gun__wishAmmoItemType : int = INVALID_ITEM_ID)
      gather_ammo_for_gun(gun__ammoHolderIds, gun__shell_prop_ids, itemContainer) <| $(ammoItems)
        let ammoItemsCount = length(ammoItems)
        let slotIdx = ammoItems |> find_index(gun__wishAmmoItemType)
        if slotIdx == -1
          var wishAmmoId = -1
          var hasWishedAmmo = false
          for ammoHolderId in gun__ammoHolderIds
            for itemEid in itemContainer
              query(itemEid) <| $ [es] (ammo_holder__id : int; item__id : int)
                if ammo_holder__id == ammoHolderId
                  wishAmmoId = item__id
                  hasWishedAmmo = true
              if hasWishedAmmo
                break
            if hasWishedAmmo
              break

          if !hasWishedAmmo
            wishAmmoId = ammoItemsCount == 0 ? INVALID_ITEM_ID : ammoItems[0]

          set_wish_ammo_item_type(gunEid, wishAmmoId)


[es(tag=server, after=gun_init_es, track=(itemContainer, human_weap__gunEids))]
def human_weap_gun_wish_ammo_item_type_es(evt : Event;
                                          itemContainer : ecs::EidList;
                                          human_weap__gunEids : ecs::EidList)
  review_weap_gun_wish_ammo_item_type(itemContainer, human_weap__gunEids)


[es(tag=server, on_appear, REQUIRE=(gun, item__needUpdateWishAmmo))]
def late_set_weap_gun_wish_ammo_es(evt : Event;
                                   gun__wishAmmoItemType : int;
                                   gun__owner : ecs::EntityId)
  if gun__owner != INVALID_ENTITY_ID && gun__wishAmmoItemType == 0
    query(gun__owner) <| $ [es(REQUIRE=human)] (itemContainer : ecs::EidList;
                                                human_weap__gunEids : ecs::EidList)
      review_weap_gun_wish_ammo_item_type(itemContainer, human_weap__gunEids)


[es(tag=server, on_appear, after=(shell_item_es, items_es), REQUIRE=(shell__gun_props_id, item__needUpdateWishAmmo))]
def late_set_ammo_as_wish_ammo_es(evt : Event;
                                  item__ownerEid : ecs::EntityId)
  if item__ownerEid != INVALID_ENTITY_ID
    query(item__ownerEid) <| $ [es(REQUIRE=human)] (itemContainer : ecs::EidList;
                                                    human_weap__gunEids : ecs::EidList)
      review_weap_gun_wish_ammo_item_type(itemContainer, human_weap__gunEids)



















[es(track=human_weap__lockedWeaponSlot)]
def human_lock_weap_slot_es(evt : Event;
                            eid : ecs::EntityId;
                            human_weap__gunEids : ecs::EidList;
                            human_weap__lockedWeaponSlot : int;
                            var human_net_phys : HumanActor)
  human_net_phys.phys.canSwitchWeapon = (human_weap__lockedWeaponSlot < 0 ||
                                        int(human_weap__lockedWeaponSlot) >= int(HUWeaponSlots EWS_NUM))
  if !human_net_phys.phys.canSwitchWeapon
    forcibly_lock_weap_slot(eid, human_weap__lockedWeaponSlot, human_weap__gunEids, human_net_phys)
