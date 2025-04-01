module inventory_common shared
require app
require ecs
require ecs.common
require inventory
require math.base
require DagorMath
require DagorRandom
require DagorMathUtils
require DngHuman
require HumanPhys
require AnimV20
require CollRes
require Dacoll
require DagorSystem

require ecs.safe
require Weapon





require strings



[cpp_event(unicast)]
struct EventOnPlayerLooted
  itemType : string
  region : string

[event(unicast)]
struct EventOnLootPickup
  itemEid : ecs::EntityId


enum Usefulness
  NO = 0
  YES = 1
  UNKNOWN = 2


def is_useful_equip(item_eid : EntityId;
                    to_whom : EntityId)
  var res = Usefulness UNKNOWN
  query(to_whom) <| $ [es] (human_equipment__slots : Object const?)
    query(item_eid) <| $ [es] (item__equipToSlots : Array;
                               item__uniqueName aka new_item__uniqueName : string;
                               item__pickupScore aka new_item__pickupScore : float = -1.0)
      if length(item__equipToSlots) > 0
        res = Usefulness NO
        if item__pickupScore == 0.0
          return
        if human_equipment__slots == null
          return
        if !can_pickup_item(item_eid, to_whom)
          return
        for slot in item__equipToSlots
          let slotId = slot as string
          if slotId == null
            return
          let itf = (*human_equipment__slots)[*slotId |> string()]
          if itf == null
            continue
          let item = *itf as Object
          let equippedItem = (*item)["item"] ?? INVALID_ENTITY_ID
          if equippedItem == INVALID_ENTITY_ID
            res = Usefulness YES 
            return
          query(equippedItem) <| $ [es] (item__uniqueName aka equipped_item__uniqueName : string;
                                         item__pickupScore aka equipped_item__pickupScore : float = -1.0)
            if new_item__uniqueName == equipped_item__uniqueName
              return
            if new_item__pickupScore > equipped_item__pickupScore
              res = Usefulness YES
          if res == Usefulness YES
            return
  return res




































































































def has_same_weapon(to_whom : EntityId;
                    weap_id : int;
                    weap_slots : Array const?)
  if weap_id == INVALID_ITEM_ID || weap_slots == null || empty(*weap_slots)
    return false
  var res = false
  query(to_whom) <| $ [es] (human_weap__gunEids : EidList)
    for slot in *weap_slots
      let slotId = slot as string
      if slotId == null
        return
      let slotIdx = int(HUWeaponSlots(*slotId |> string()))
      if slotIdx >= 0 && weap_id == get_int(human_weap__gunEids[slotIdx], "item__id") ?? INVALID_ITEM_ID
        res = true
        return

  return res




















































































def get_item_use_time(item : EntityId; is_downed : bool; is_self_targeting : bool)
  var useTime = -1f
  var hasUseTime = false
  if is_self_targeting
    query(item) <| $ [es] (item__useTime : float; item__downedTimeMultiplier : float = 1f)
      useTime = item__useTime  * (is_downed ? item__downedTimeMultiplier : 1f)
      hasUseTime = true
  else
    query(item) <| $ [es] (item__useTimeToTarget : float; item__downedTimeMultiplier : float = 1f)
      useTime = item__useTimeToTarget * (is_downed ? item__downedTimeMultiplier : 1.f)
      hasUseTime = true
  if hasUseTime && useTime < 0f
    let compName = is_self_targeting ? "useTime" : "useTimeToTarget"
    logerr("item.{compName} < 0 {getEntityTemplateName(item)}")
  return useTime


def push_item_in_cont(owner_eid : EntityId; name : string | #)
  return createEntity(name) <| $(var init : ComponentsInitializer)
    set(init, "item__ownerEid", owner_eid)

def remove_item_from_cont(eid : EntityId; var itemContainer : EidList&) : bool
  let idx = find_index(itemContainer, eid)
  if idx == -1
    return false
  itemContainer |> erase(idx)
  return true

struct ItemPickupScore
  score : float
  useful : bool



































































def find_gunslot_to_change_weapon(eid : EntityId;
                                  item_eid : EntityId;
                                  var have_gun : bool&)
  var res = -1
  have_gun = false

  query(eid) <| $ [es] (human_weap__gunEids : EidList)
    query(item_eid) <| $ [es] (item__weapSlots : Array;
                               item__id : int)
      let weaponId = item__id
      for slot in item__weapSlots
        let slotName = slot ?? ""
        let slotIdx = HUWeaponSlots(slotName)
        let gunEid = human_weap__gunEids[int(slotIdx)]
        let totalAmmo = get_int(gunEid, "gun__totalAmmo") ?? 0 + get_int(gunEid, "gun__ammo") ?? 0
        if gunEid != INVALID_ENTITY_ID && has(gunEid, "disableItemDrop")
          continue
        let noAmmo = (totalAmmo <= 0 && slotIdx != HUWeaponSlots EWS_MELEE
                      && weaponId != get_int(human_weap__gunEids[int(slotIdx)], "item__id") ?? INVALID_ITEM_ID)
        if gunEid == INVALID_ENTITY_ID || noAmmo
          res = int(slotIdx)
          have_gun = (gunEid != INVALID_ENTITY_ID)
          if !have_gun
            break
  return res


def find_gunslot_to_change_weapon(eid : EntityId;
                                  item_eid : EntityId)
  var unused = false
  return find_gunslot_to_change_weapon(eid, item_eid, unused)






































































































































































































































































def is_unique_item_better(item_what : EntityId;
                          item_than : EntityId)
  return get_float(item_what, "item__pickupScore") ?? -1.0 > get_float(item_than, "item__pickupScore") ?? -1.0


def check_pickup_item_by_uniqueness(eid : EntityId;
                                    item_eid : EntityId;
                                    var out_worst_slot_name : string)
  if item_eid == INVALID_ENTITY_ID
    out_worst_slot_name = ""
    return true

  var worstSlotName = ""
  var res = true

  query(item_eid) <| $ [es] (item__equipToSlots : Array;
                             item__uniqueName : das_string const?)
    if item__uniqueName == null
      res = false
      return

    let isSlots = query(eid) <| $ [es] (human_equipment__slots : Object)
      for eqToSlot in item__equipToSlots
        let eqToSlotName = eqToSlot ?? ""
        let slot = human_equipment__slots |> get_child(eqToSlotName)
        if slot != null
          let slotObject = get_ecs_object(*slot)
          if slotObject != null
            let equippedItem = get_Eid(*slotObject, "item") ?? INVALID_ENTITY_ID
            let equippedItemUniqueName = get_ecs_string(equippedItem, "item__uniqueName")
            if equippedItemUniqueName != null && (*equippedItemUniqueName) |> string() == (*item__uniqueName) |> string()
              res = is_unique_item_better(item_eid, equippedItem)
              if res
                worstSlotName = eqToSlotName
              break
    if !isSlots
      res = false
      return

  out_worst_slot_name = worstSlotName
  return res


def check_pickup_item_by_uniqueness(eid : EntityId;
                                    item_eid : EntityId)
  var worstSlotName : string
  return check_pickup_item_by_uniqueness(eid, item_eid, worstSlotName)


def can_loot_container(eid : EntityId;
                       restriction_list : EidList const?)
  return restriction_list == null || *restriction_list |> find_index(eid) < 0


def can_pickup_items(eid : EntityId)
  var canPickupItems = false
  query(eid) <| $ [es] (human__canPickupItems : bool = true)
    canPickupItems = human__canPickupItems
  return canPickupItems


def can_pickup_item(item_eid : EntityId;
                    eid : EntityId)
  if !can_pickup_items(eid)
    return false

  return (can_pickup_item_by_volume(item_eid, eid) &&
          check_pickup_item_by_uniqueness(eid, item_eid) &&
          can_loot_container(eid, getRW_ecs_EidList(item_eid, "container__restrictLootingToEids")))









































































































































def notify_player_looted(eid : EntityId;
                         item_eid : EntityId)
  query(item_eid) <| $ [es] (item__lootType : string;
                             spawnedInRegion : string = "";
                             var item__alreadyLooted : bool&)
    if item__lootType != "" && !item__alreadyLooted
      query(eid) <| $ [es] (possessedByPlr : EntityId)
        sendEvent(possessedByPlr, [[EventOnPlayerLooted itemType=item__lootType, region=spawnedInRegion]])
        item__alreadyLooted = true
  sendEventImmediate(eid, [[EventOnLootPickup itemEid=item_eid]])




















































def remove_item_from_entity_container(item_eid : EntityId)
  query(item_eid) <| $ [es] (item__parentContainerEid : EntityId)
    query(item__parentContainerEid) <| $ [es] (var entitiesContainerContent : EidList)
      let idx = entitiesContainerContent |> find_index(item_eid)
      if idx >= 0
        entitiesContainerContent |> erase(idx)
    let newTemplateName = remove_sub_template_name(item_eid, "item_in_container")
    remote_recreate_entity_from(item_eid, newTemplateName)

def on_item_entity_looted(eid : EntityId;
                          item_eid : EntityId)
  notify_player_looted(eid, item_eid)

  query(item_eid) <| $ [es] (item__recreateOnGround : das_string const?;
                             item__recreateInInventory : das_string const?;
                             item__removeTemplatesInInventory : StringList const?;
                             var item__isOnGround : bool&;
                             var item__ownerEid : EntityId&;
                             var item__lastOwner : EntityId&)
    remove_item_from_entity_container(item_eid)
    let templateToRemove = item__recreateOnGround != null ? *item__recreateOnGround |> string() : ""
    let templateToAdd = item__recreateInInventory != null ? *item__recreateInInventory |> string() : ""
    var newTemplateName = getEntityTemplateName(item_eid)
    if templateToRemove != ""
      newTemplateName = remove_sub_template_name(newTemplateName, templateToRemove)
    if templateToAdd != ""
      newTemplateName = add_sub_template_name(newTemplateName, templateToAdd)
    if item__removeTemplatesInInventory != null
      for templ in *item__removeTemplatesInInventory
        newTemplateName = remove_sub_template_name(newTemplateName, templ |> string())
    item__isOnGround = false
    item__ownerEid = eid
    item__lastOwner = eid
    remote_recreate_entity_from(item_eid, newTemplateName)
  return true


def can_pickup_item_by_volume(item_eid : EntityId;
                              eid : EntityId;
                              volume : float)
  if eid == INVALID_ENTITY_ID
    return false

  let isOnGround = get_bool(item_eid, "item__isOnGround") ?? true
  if !isOnGround
    return false

  if volume == 0.0
    return true

  let totalVolume = get_float(eid, "human_inventory__currentVolume") ?? 0.0
  return totalVolume + volume <= get_float(eid, "human_inventory__capacity") ?? 0.0


def can_pickup_item_by_volume(item_eid : EntityId;
                              eid : EntityId)
  let volume = get_float(item_eid, "item__volume") ?? 0.0
  return can_pickup_item_by_volume(item_eid, eid, volume)



























































































