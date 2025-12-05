module inventory_common shared
require app
require ecs
require ecs.common
require inventory
require DagorMath
require DagorMathUtils
require HumanPhys
require AnimV20
require CollRes
require DagorSystem
require net
require ecs.safe

require %appGame.wt_events
require %appGame.infantry.es.inventory_drop_common
require %appGame.infantry.es.human_weap_common

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

struct MagazinesCount
  current : int
  partial : int


def get_magazines_count(ammo_in_gun : int;
                        max_ammo_in_magazine : int;
                        item_container : EidList;
                        is_suitable_ammo_cb : block<(itemTemplate : string) : bool>)
  var magazines = MagazinesCount(
    current = (ammo_in_gun <= 0 ? 0 : 1),
    partial = 0
  )


  for itemEid in item_container
    query(itemEid) <| $ [es] (item__template : string; ammo_holder__ammoCount : int)
      if !invoke(is_suitable_ammo_cb, item__template)
        return
      magazines.current++
      if ammo_holder__ammoCount < max_ammo_in_magazine
        magazines.partial++

  return magazines


def is_ammo_for_gun(ammo_template; ammo_holders_templates)
  for ammo_holder_template in ammo_holders_templates
    let holder = get_string(ammo_holder_template, "")
    if holder != "" && ammo_template == holder
      return true
  return false


def refill_ammo(requester; count; ammoTemplate)
  for _i in range(0, count)
    push_item_in_cont(requester, ammoTemplate)
  return count > 0


def has_grenade(itemContainer)
  for item in itemContainer
    if has(item, "hand_grenade")
      return true
  return false

def has_grenade_for_grenade_launcher(itemContainer, grenadeTemplate)
  for item in itemContainer
    let ammo_holder__templateName = get_ecs_string(item, "ammo_holder__templateName") ?? ""
    if ammo_holder__templateName == grenadeTemplate
      return true
  return false

def find_grenade_of_type(itemContainer, grenade_type)
  for itemEid in itemContainer
    let itemGrenadeType = get_ecs_string(itemEid, "item__grenadeType") ?? "shell"
    if itemGrenadeType == grenade_type
      return itemEid
  return INVALID_ENTITY_ID


def try_to_refill_grenades(requester, grenadeTemplate)
  if grenadeTemplate == ""
    return false
  var isAmmoRefilled = true
  query(requester) <| $ [es] (itemContainer : EidList)
    isAmmoRefilled &&= !has_grenade(itemContainer)
    isAmmoRefilled &&= refill_ammo(requester, 1, grenadeTemplate)
  return isAmmoRefilled

def try_to_refill_grenades_launcher(requester, grenadeTemplate)
  if grenadeTemplate == ""
    return false
  var isAmmoRefilled = true
  query(requester) <| $ [es] (itemContainer : EidList)
    isAmmoRefilled &&= !has_grenade_for_grenade_launcher(itemContainer, grenadeTemplate)
    isAmmoRefilled &&= refill_ammo(requester, 1, grenadeTemplate)
  return isAmmoRefilled

def resupply_gun(empty_magazines_count, partial_magazines_count : int;
                 requester : EntityId;
                 holder_ammo_count : int;
                 reserve_ammo_template : string | #;
                 var item_container : EidList&;
                 is_suitable_ammo_cb : block<(itemTemplate : string) : bool>)
  let magazinesCount = empty_magazines_count + partial_magazines_count
  if magazinesCount <= 0
    return

  
  var i = length(item_container) - 1
  var numPartialMagsToBeRemoved = partial_magazines_count

  while i >= 0
    if numPartialMagsToBeRemoved <= 0
      break
    query(item_container[i]) <| $ [es] (item__template : string; ammo_holder__ammoCount : int)
      if !invoke(is_suitable_ammo_cb, item__template) || ammo_holder__ammoCount >= holder_ammo_count
        return
      destroyEntity(item_container[i])
      item_container |> erase(i)
      --numPartialMagsToBeRemoved
    --i

  refill_ammo(requester, magazinesCount, reserve_ammo_template)


def refill_ammo_for_gun(requester_eid : EntityId;
                        gun_eid : EntityId;
                        ammo_in_gun : int;
                        ammo_template : string | #;
                        num_reserve_ammo : int;
                        var item_container : EidList;
                        is_suitable_ammo_cb : block<(itemTemplate : string) : bool>)
  let ammoTplComp = ammo_template |> getTemplateByName
  if ammoTplComp == null
    logerr("Template '{ammo_template}' not exist in entity '{getEntityTemplateName(gun_eid)}'")
    return

  let holderAmmoCount = *ammoTplComp |> getTemplateComponent("ammo_holder__ammoCount") ?? 0
  if holderAmmoCount <= 0
    logerr("<{requester_eid}> ammo_holder.ammoCount is less than or equal to 0 in template: {ammo_template}")
    return

  let magazines = get_magazines_count(ammo_in_gun, holderAmmoCount, item_container, is_suitable_ammo_cb)
  error("magazines = {magazines.current}/{magazines.partial}")
  let emptyMagazineCount = num_reserve_ammo - magazines.current
  error("emptyMagazineCount = {emptyMagazineCount}")

  resupply_gun(emptyMagazineCount, magazines.partial, requester_eid, holderAmmoCount, ammo_template, item_container, is_suitable_ammo_cb)


def is_useful_equip(item_eid : EntityId;
                    to_whom : EntityId)
  var res = Usefulness.UNKNOWN
  query(to_whom) <| $ [es] (human_equipment__slots : Object const?)
    query(item_eid) <| $ [es] (item__equipToSlots : Array;
                               item__uniqueName aka new_item__uniqueName : string;
                               item__pickupScore aka new_item__pickupScore : float = -1.0)
      if length(item__equipToSlots) > 0
        res = Usefulness.NO
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
            res = Usefulness.YES 
            return
          query(equippedItem) <| $ [es] (item__uniqueName aka equipped_item__uniqueName : string;
                                         item__pickupScore aka equipped_item__pickupScore : float = -1.0)
            if new_item__uniqueName == equipped_item__uniqueName
              return
            if new_item__pickupScore > equipped_item__pickupScore
              res = Usefulness.YES
          if res == Usefulness.YES
            return
  return res


def is_weapon_useful(item_eid : EntityId;
                     to_whom : EntityId;
                     weap_templ_name : string;
                     weap_slots : Array const?;
                     gun_eids : EidList const?;
                     gun_mods : Array const?)
  if weap_templ_name != ""
    
    if find_gunslot_to_change_weapon(to_whom, item_eid) >= 0
      return Usefulness.YES

    if gun_eids != null && weap_slots != null
      var useful = false
      query(item_eid) <| $ [es] (item__weapType aka new_item__weapType : string;
                                 item__pickupScore aka new_item__pickupScore : float)
        for slot in *weap_slots
          let slotId = slot as string
          if slotId == null
            return
          let slotIdx = HUWeaponSlots(*slotId |> string())
          if int(slotIdx) < 0
            logerr("Incorrect slotId = {slotId}!")
            return

          query((*gun_eids)[int(slotIdx)]) <| $ [es] (item__weapType aka equipped_item__weapType : string;
                                                      item__pickupScore aka equipped_item__pickupScore : float)
            useful = (new_item__weapType == equipped_item__weapType &&
                     new_item__pickupScore > equipped_item__pickupScore)
          if useful
            return
      if useful
        return Usefulness.YES
  if has(item_eid, "gunAttachable")
    if gun_eids == null || gun_mods == null
      return Usefulness.NO

    let itemGunSlotName = get_ecs_string(item_eid, "gunAttachable__gunSlotName")
    if itemGunSlotName != null
      let usefulScopesLimit = get_int(to_whom, "human_inventory__usefulScopesLimit") ?? 2 
      let usefulScopesOverflow = get_int(to_whom, "human_inventory__usefulScopesOverflow") ?? 0
      let itemCont = get_ecs_EidList(to_whom, "itemContainer")
      var inventoryScopes = 0
      var wishScopes = 0
      var weaponScopes = 0
      if itemCont != null
        for item in *itemCont
          let gunSlotName = get_ecs_string(item, "gunAttachable__gunSlotName")
          if gunSlotName != null && (*gunSlotName == *itemGunSlotName)
            inventoryScopes++
      for i in range(int(HUWeaponSlots.EWS_NUM))
        let gunModsList = get_ecs_EidList((*gun_mods)[i])
        if gunModsList == null
          continue
        var haveMod = false
        for gunModEid in *gunModsList
          let gunSlotName = get_ecs_string(gunModEid, "gunAttachable__gunSlotName")
          if gunSlotName != null && (*gunSlotName == *itemGunSlotName)
            haveMod = true
            ++weaponScopes
            break
        if !haveMod && is_gunmod_allowed((*gun_eids)[i], item_eid)
          wishScopes++
      if inventoryScopes < usefulScopesOverflow + wishScopes && inventoryScopes + weaponScopes < usefulScopesLimit
        return Usefulness.YES

    return Usefulness.NO
  return Usefulness.UNKNOWN






























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


def is_item_useful(to_whom : EntityId;
                   item_eid : EntityId)
  if !doesEntityExist(to_whom)
    return false

  var itemId = INVALID_ITEM_ID
  var weapTemplName = ""
  var weapSlots : Array const? = null
  var isContainer = false
  var alwaysUseful = false
  var disabledPickup = false
  var hasUseTime = false
  var isEquippable = false
  query(item_eid) <| $ [es] (item__weapTemplate : das_string const?;
                             item__weapSlots : Array const?;
                             container_contents_chances : Object const?;
                             containerContents : StringList const?;
                             containerContentsPreset : Array const?;
                             containerContentsWeightedPreset : Object const?;
                             container__restrictLootingToEids : EidList const?;
                             item__useTime : float const?;
                             item__useTimeToTarget : float const?;
                             item__alwaysUseful : Tag const?;
                             item__equipToSlots : Array const?;
                             item__disablePickup : bool = false;
                             item__id : int = INVALID_ITEM_ID)
    itemId = item__id
    if item__weapTemplate != null
      weapTemplName := *item__weapTemplate |> string()
    weapSlots = item__weapSlots
    isContainer = (container_contents_chances != null || containerContentsPreset != null ||
                  containerContentsWeightedPreset != null || containerContents != null)
    isContainer = isContainer && can_loot_container(to_whom, container__restrictLootingToEids)
    alwaysUseful = item__alwaysUseful != null
    hasUseTime = item__useTime != null || item__useTimeToTarget != null
    isEquippable = item__equipToSlots != null
    disabledPickup = item__disablePickup

  if disabledPickup
    return false

  if itemId == INVALID_ITEM_ID && !isEquippable
    return false

  if has_same_weapon(to_whom, itemId, weapSlots)
    return false

  if alwaysUseful
    return true

  var gunEids : EidList const? = null
  var gunMods : Array const? = null
  query(to_whom) <| $ [es] (human_weap__gunEids : EidList const?;
                            human_weap__gunMods : Array const?)
    gunEids = human_weap__gunEids
    gunMods = human_weap__gunMods

  if isContainer
    return true

  let isUsefulEquip = is_useful_equip(item_eid, to_whom)
  if isUsefulEquip != Usefulness.UNKNOWN
    return isUsefulEquip == Usefulness.YES

  if hasUseTime
    return true

  let isWeaponUseful = is_weapon_useful(item_eid, to_whom, weapTemplName, weapSlots, gunEids, gunMods)
  if isWeaponUseful != Usefulness.UNKNOWN
    return isWeaponUseful == Usefulness.YES

  
  
  

  return false

def is_fast_pickup_item(to_whom, item_eid : EntityId)
  return is_item_useful(to_whom, item_eid) || has(item_eid, "fastPickup")


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


def get_item_pickup_score(eid, item_eid, gunEid : EntityId; view_convex : Point4List; view_itm : float3x4; aimDir, aimFrom, aimTo, minPickupBox : float3; was_selected : bool) : ItemPickupScore
  var ret = ItemPickupScore(score = -1.0, useful = false)
  query(item_eid) <| $ [es] (animchar_render__enabled : bool = true;
                             item__lastOwner : EntityId;
                             item__equipToSlots : Array const?;
                             var transform : float3x4 const?;
                             collres : CollisionResource const?;
                             animchar : AnimcharBaseComponent;
                             animchar_render : AnimcharRendComponent;
                             gun__ammoHolders aka item_gun__ammoHolders : Array const?;
                             item__pickupOnlyAmmo : Tag const?;
                             item__id : int = INVALID_ITEM_ID;
                             item_pickup_priority__lookAtWeight : float = 4.f;
                             item_pickup_priority__usefulWeight : float = 2.f;
                             item_pickup_priority__angleWeight : float = 1.f;
                             item_pickup_priority__useCollresMinWidth : float = 1.5f;
                             item__visible : bool = true;
                             container__destroyEmpty = true)
    if !animchar_render__enabled || !item__visible
      return

    if item__pickupOnlyAmmo != null
      var result = false
      let pickUpAmmoTemplate = item_gun__ammoHolders?[0] ?? ""
      if !empty(pickUpAmmoTemplate)
        let pickUpAmmoHolderId = int(ecs_hash(pickUpAmmoTemplate))
        query(gunEid) <| $ [es] (gun__ammoHolderIds : IntList)
          for ammoHolderId in gun__ammoHolderIds
            if pickUpAmmoHolderId == ammoHolderId
              result = true
      if !result
        return

    if item__id == INVALID_ITEM_ID && item__equipToSlots == null
      if !container__destroyEmpty
        ret.score = 0.01 
      return

    if transform == null
      transform = get_TMatrix(item__lastOwner, "transform")
    if transform == null
      return

    var lbb = BBox3()
    scene_instance_get_local_bounding_box(animchar_render.sceneInstance, lbb)
    lbb |> bbox3_add(minPickupBox)
    lbb |> bbox3_add(-minPickupBox)
    let entPos = (*transform) * lbb.center
    let checkPos = view_itm * entPos
    for plane in view_convex
      let dist = distance_plane_point3(plane, checkPos)
      if dist > 0.0
        ret.score = -1.0
        return

    ret.score = dot(normalize(entPos - aimFrom), aimDir) * item_pickup_priority__angleWeight

    let width = lbb.width
    if collres == null || width.x + width.y + width.z < item_pickup_priority__useCollresMinWidth
      let itemItm = inverse(*transform)
      let from = itemItm * aimFrom
      let to = itemItm * aimTo
      if test_segment_box_intersection(from, to, lbb)
        ret.score += item_pickup_priority__lookAtWeight
    else
      let t = 10f
      if collres_rayhit(*collres, *transform, animchar.nodeTree, aimFrom, aimDir, t)
        ret.score += item_pickup_priority__lookAtWeight

    ret.useful = is_item_useful(eid, item_eid)
    if ret.useful
      ret.score += item_pickup_priority__usefulWeight

    let selectedItemBias = 0.05
    if was_selected
      ret.score += selectedItemBias

  return ret


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
        let noAmmo = (totalAmmo <= 0 && slotIdx != HUWeaponSlots.EWS_MELEE
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


def install_item_on_weap_impl(eid, item_eid : EntityId;
                              slot_id : int;
                              weap_slot : string) : bool
  var res = false
  query(item_eid) <| $ [es] (item__id : int = INVALID_ITEM_ID;
                             gunAttachable : Tag const?)
    if item__id == INVALID_ITEM_ID
      return
    if gunAttachable == null || slot_id < 0 || dead_or_downed(eid)
      return
    if !is_server()
      logerr("[Install item on weap impl2] This function mustn't be called from client.")
      return

    query(eid) <| $ [es] (human_weap__gunEids : EidList;
                          human_weap__gunMods : Array;
                          var itemContainer : EidList?)
      if !is_gunmod_allowed(human_weap__gunEids[slot_id], item_eid)
        return

      if itemContainer != null
        if remove_entity_from_container(*itemContainer, item_eid)
          let gunMods = human_weap__gunMods[slot_id] |> get_ecs_EidList()
          var found = false
          for gunModEid in *gunMods
            query(gunModEid) <| $ [es] (gunAttachable__gunSlotName, item__template : string)
              if gunAttachable__gunSlotName == weap_slot
                *itemContainer |> push(createEntity(item__template))
                found = true
            if found
              break

          var nullCustomProps : Object? = null
          human_weap_attach_item_to_gun(eid, slot_id, item_eid, weap_slot, true, nullCustomProps)
          destroyEntity(item_eid)
      res = true

  return res















def drop_weap_from_slot_impl(eid : EntityId; slot_id : int; reset_weap, can_drop_from_dead : bool) : void
  if slot_id < 0 || (!can_drop_from_dead && dead_or_downed(eid))
    return

  query(eid) <| $ [es] (transform : float3x4;
                        human_inventory__dropsLoot : bool = true;
                        human_inventory__dropLootOffset : float3;
                        human_inventory__lootCleanupTime : float = -1.f;
                        allowOnlyPrimaryWeaponDrop : Tag const?)
    if allowOnlyPrimaryWeaponDrop != null && HUWeaponSlots(slot_id) != HUWeaponSlots.EWS_PRIMARY
      return
    if human_inventory__dropsLoot
      var tm = transform
      tm[3] = tm * human_inventory__dropLootOffset
      drop_gun(eid, slot_id, tm, "", false) <| $(loot_desc)
        drop_item(loot_desc, true, human_inventory__lootCleanupTime, true, INVALID_ENTITY_ID)

    if reset_weap
      var nullCustomProps : Object? = null
      human_weap_set_item_to_slot(eid, "", "", slot_id, nullCustomProps) 

    sendEvent(eid, EventOnLootDrop(itemEid = INVALID_ENTITY_ID))


def drop_weap_from_slot(eid : EntityId; slot_name : string) : void
  if eid == INVALID_ENTITY_ID
    return

  let slotId = int(HUWeaponSlots(slot_name))

  if is_server()
    drop_weap_from_slot_impl(eid, slotId, true, false)
  else
    send_net_event(eid, HumanDropWeapRequest(slotId = slotId))

    if slotId >= int(HUWeaponSlots.EWS_NUM)
      logerr("[Drop weap from slot2] slotId <{slotId}> is out of range")
      return
    query(eid) <| $ [es] (human_weap__gunEids : EidList)
      let itemEid = human_weap__gunEids[slotId]
      if itemEid != INVALID_ENTITY_ID
        sendEvent(eid, EventOnLootDrop(itemEid = itemEid))















def remove_all_attaches_from_looted_item(item_eid : EntityId)
  query() <| $ [es] (eid, animchar_attach__attachedTo : EntityId)
    
    
    if animchar_attach__attachedTo == item_eid
      destroyEntity(eid)


def on_weap_slot_item_looted(eid, item_eid : EntityId; slot_id : int)
  remove_all_attaches_from_looted_item(item_eid)
  query(item_eid) <| $ [es] (var item__id : int&)
    item__id = INVALID_ITEM_ID
  notify_player_looted(eid, item_eid)
  sendEventImmediate(eid, EventOnWeapSlotItemPickup(itemEid = item_eid, slotId = slot_id))


def pickup_gun(weap_templ_name, custom_skin : string;
               eid, item_eid : EntityId;
               slot_id : int) : void
  steal_gun_from_owner(eid, item_eid)

  query(eid) <| $ [es] (human_weap__gunMods : Array;
                        human_weap__currentGunSlot : int = -1;
                        droppedGunKeepsMods : Tag const?)
    query(item_eid) <| $ [es] (var customProps : Object?)
      if customProps == null
        logerr("{item_eid}: {getEntityTemplateName(item_eid)} item without required customProps component")
      var slotId = slot_id
      if slotId < 0
        var haveGun = false
        slotId = find_gunslot_to_change_weapon(eid, item_eid, haveGun)
        if !haveGun
          if slotId >= 0
            human_weap_set_item_to_slot(eid, weap_templ_name, custom_skin, slotId, customProps)
            on_weap_slot_item_looted(eid, item_eid, slotId)
            destroyEntity(item_eid)
            return
          
          slotId = find_best_weap_slot_id(eid, item_eid, slotId, human_weap__currentGunSlot)

      if slotId >= 0
        let keepScope = droppedGunKeepsMods != null

        
        let scopeEid = !keepScope ? remove_item_from_weap_impl(eid, slotId, "scope",  false) : INVALID_ENTITY_ID

        drop_weap_from_slot_impl(eid, slotId, false, false)
        
        human_weap_set_item_to_slot(eid, weap_templ_name, custom_skin, slotId, customProps)

        
        
        if scopeEid != INVALID_ENTITY_ID
          var scopeFound = false
          let gunMods = human_weap__gunMods[slotId] |> get_ecs_EidList()
          if gunMods != null
            for gunModEid in *gunMods
              query(gunModEid) <| $ [es] (gunAttachable__gunSlotName : string)
                if gunAttachable__gunSlotName == "scope"
                  scopeFound = true
              if scopeFound
                break
            if !scopeFound
              install_item_on_weap_impl(eid, scopeEid, slotId, "scope")

        on_weap_slot_item_looted(eid, item_eid, slotId)
        destroyEntity(item_eid)


def pickup_gun(eid : EntityId;
               item_eid : EntityId)
  return query(item_eid) <| $ [es] (item__weapTemplate : string;
                                    gun__ammoHolders aka picking_up_gun__ammoHolders : Array;
                                    item__pickupOnlyAmmo : Tag const?;
                                    gun__customSkin : das_string const?)
    let pickingAmmoTemplate = picking_up_gun__ammoHolders?[0] ?? ""
    if item__pickupOnlyAmmo != null && !empty(pickingAmmoTemplate)
      let pickingUpAmmoTplComp = pickingAmmoTemplate |> getTemplateByName
      let pickingUpHolderAmmoCount = *pickingUpAmmoTplComp |> getTemplateComponent("ammo_holder__ammoCount") |> get_int ?? 0
      query(eid) <| $ [es] (human_weap__gunEids : EidList;
                            var itemContainer : EidList)
        var ammoWasPickedUp = false
        for gunEid in human_weap__gunEids
          if ammoWasPickedUp
            break
          query(gunEid) <| $ [es] (gun__ammoHolders aka player_gun__ammoHolders : Array;
                                   gun__ammo : int;
                                   gun__numReserveAmmo : int)
            let ammoTemplate = player_gun__ammoHolders?[0] ?? ""
            if ammoTemplate == pickingAmmoTemplate
              let magazines = get_magazines_count(gun__ammo, pickingUpHolderAmmoCount, itemContainer) <| $(itemTemplate)
                return is_ammo_for_gun(itemTemplate, gun__ammoHolders)
              let numMagazinesToResupply = magazines.current + 1 > gun__numReserveAmmo ? 0 : 1
              if numMagazinesToResupply > 0
                resupply_gun(numMagazinesToResupply,
                    0,
                    eid,
                    pickingUpHolderAmmoCount,
                    pickingAmmoTemplate,
                    itemContainer) <| $(itemTemplate)
                  return is_ammo_for_gun(itemTemplate, gun__ammoHolders)
                ammoWasPickedUp = true
              else
                send_net_event(eid, CmdHeroLogEvent(event = "ammo_full", text = "resupply/ammo_full"))
        if ammoWasPickedUp
          remove_all_attaches_from_looted_item(item_eid)
          destroyEntity(item_eid)
    else
      if gun__customSkin != null
        pickup_gun(item__weapTemplate, *gun__customSkin |> string(), eid, item_eid, -1)
      else
        pickup_gun(item__weapTemplate, "", eid, item_eid, -1)

def insert_item(eid, item_eid : EntityId) : void
  if pickup_gun(eid, item_eid)
    return

  query(eid) <| $ [es] (var itemContainer : EidList;
                        var human_inventory__currentVolume : float?)
    itemContainer |> push(item_eid)
    if human_inventory__currentVolume != null
      query(item_eid) <| $ [es] (item__volume : float = 0.f)
        *human_inventory__currentVolume += item__volume 

  on_item_entity_looted(eid, item_eid)


def drop_gun(eid : EntityId;
             slot_id : int;
             tm : float3x4;
             var out_descs_ctr : int&;
             additional_gun_template : string;
             force_client : bool;
             cb : block<(out_desc : ItemDesc) : void>) : bool
  var isOk = false
  query(eid) <| $ [es] (human_weap__gunEids : EidList;
                        human_weap__gunMods : Array)
    if !is_server() && !force_client
      logerr("[Drop gun2] Attempted to call drop_gun from client.")
      return
    if slot_id >= int(HUWeaponSlots.EWS_NUM)
      logerr("[Drop gun2] slot_id = <{slot_id}> is out of range.")
      return

    query(human_weap__gunEids[slot_id]) <| $ [es] (item__template : string;
                                                   item__id : int const?;
                                                   gun__customSkin : das_string const?)
      out_descs_ctr++
      using() <| $(var desc : ItemDesc)
        var templOverride = item__template
        if gun__customSkin != null && !empty(*gun__customSkin)
          templOverride += "+{*gun__customSkin}"
          desc |> setCustomSkin(string(*gun__customSkin))
        desc |> setTemplOverride(templOverride)
        var addTemplate = "item_in_world"
        if !empty(additional_gun_template)
          addTemplate = add_sub_template_name(addTemplate, additional_gun_template)
        desc |> setAddTemplate(addTemplate)
        desc.ownerEid = eid
        desc.id = item__id != null ? *item__id : int(uint(human_weap__gunEids[slot_id]))
        desc.tm = tm

        human_gun_to_custom_props(human_weap__gunEids[slot_id], desc.customProps, !force_client)

        let gunMods = human_weap__gunMods[slot_id] |> get_ecs_EidList()
        for gunModEid in *gunMods
          query(gunModEid) <| $ [es] (gunAttachable__gunSlotName : string;
                                      item__template : das_string const?)
            if item__template != null && !empty(*item__template)
              desc |> pushModTemplate(getEntityTemplateName(gunModEid))
              human_gun_mod_to_custom_props(eid, slot_id, gunAttachable__gunSlotName, desc.customProps, !force_client)

        invoke(cb, desc)
      isOk = true
  return isOk


def drop_gun(eid : EntityId;
             slot_id : int;
             tm : float3x4;
             additional_gun_template : string;
             force_client : bool;
             cb : block<(out_desc : ItemDesc) : void>) : bool
  var ctr = 0
  let isOk = drop_gun(eid, slot_id, tm, ctr, additional_gun_template, force_client) <| $(out_desc)
    invoke(cb, out_desc)
  return isOk


def is_unique_item_better(item_what : EntityId;
                          item_than : EntityId)
  return get_float(item_what, "item__pickupScore") ?? -1.0 > get_float(item_than, "item__pickupScore") ?? -1.0


def check_pickup_item_by_uniqueness(eid : EntityId;
                                    item_eid : EntityId;
                                    var out_worst_slot_name : string&)
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


def try_pickup_item(eid, item_eid : EntityId)
  var res = true
  query(item_eid) <| $ [es] (item__isOnGround : bool = true;
                             item__disablePickup : bool = false;
                             item__lastOwner : EntityId = INVALID_ENTITY_ID;
                             item__ownerEid : EntityId = INVALID_ENTITY_ID;
                             item__actionDisabledMessage : string = "pickup_locked";
                             canItemPickedUpOnlyByLastOwner : Tag const?)
    if canItemPickedUpOnlyByLastOwner != null && item__lastOwner != eid
      res = false
      return

    if item__disablePickup
      sendEvent(eid, EventOnActionDisabled(action = item__actionDisabledMessage))
      res = false
      return

    if item__isOnGround
      return
    if item__ownerEid != eid
      sendEvent(eid, EventOnActionDisabled(action = item__actionDisabledMessage))
    res = false
  return res






















































def pickup_and_install_item_on_weap_impl(eid, item_eid : EntityId; slot_id : int; weap_slot : string) : bool
  if !is_server()
    logerr("[Pickup and install item on weap impl2] Attempt to call pickup_and_install_item_on_weap_impl from client.")
    return false

  if !has(item_eid, "gunAttachable") || slot_id < 0 || dead_or_downed(eid)
    return false

  var res = false
  query(eid) <| $ [es] (human_weap__gunEids : EidList;
                        human_weap__gunMods : Array;
                        var itemContainer : EidList)
    if !is_gunmod_allowed(human_weap__gunEids[slot_id], item_eid)
      return

    let gunMods = human_weap__gunMods[slot_id] |> get_ecs_EidList()
    if gunMods == null
      return

    for gunModEid in *gunMods
      var oldModRemoved = false
      query(gunModEid) <| $ [es] (gunAttachable__gunSlotName, item__template : string)
        if gunAttachable__gunSlotName == weap_slot
          
          createEntity(item__template) <| $(var init)
            set(init, "item__ownerEid", eid)
          oldModRemoved = true
      if oldModRemoved
        break

    var nullCustomProps : Object? = null
    human_weap_attach_item_to_gun(eid, slot_id, item_eid, weap_slot, true, nullCustomProps)

    remove_entity_from_container(itemContainer, item_eid)

    on_weap_slot_item_looted(eid, item_eid, slot_id)
    destroyEntity(item_eid)
    res = true

  return res

















def notify_player_looted(eid : EntityId;
                         item_eid : EntityId)
  query(item_eid) <| $ [es] (item__lootType : string;
                             spawnedInRegion : string = "";
                             var item__alreadyLooted : bool&)
    if item__lootType != "" && !item__alreadyLooted
      query(eid) <| $ [es] (possessedByPlr : EntityId)
        sendEvent(possessedByPlr, EventOnPlayerLooted(itemType = item__lootType, region = spawnedInRegion))
        item__alreadyLooted = true
  sendEventImmediate(eid, EventOnLootPickup(itemEid = item_eid))


def equip_item_entity_to_slot(eid : EntityId;
                              item_eid : EntityId;
                              slot : string;
                              allow_reorder_slots : bool)
  if !has(item_eid, "item__isPickable")
    
    query(eid) <| $ [es] (human_equipment__slots : Object)
      for eqSlot in human_equipment__slots
        let value = eqSlot.value as Object
        if ((*value).item ?? INVALID_ENTITY_ID) == item_eid
          sendEvent(eid, CmdSwapEquipSlots(item = item_eid, fromSlotName = eqSlot.key, toSlotName = slot))
          return
    return
  elif !check_pickup_item_by_uniqueness(eid, item_eid)
    return
  notify_player_looted(eid, item_eid)
  sendEventImmediate(eid, CmdEquipItemDirect(itemEid = item_eid, slot = slot, allowReorderSlots = allow_reorder_slots, dropPrevItem = true))


def equip_item_entity(eid : EntityId;
                      item_eid : EntityId;
                      equip_slots : Array)
  var res = false
  query(eid) <| $ [es] (human_equipment__slots : Object)
    if length(human_equipment__slots) == 0
      return

    var slotName : string
    let uniqRes = check_pickup_item_by_uniqueness(eid, item_eid, slotName)
    if has(item_eid, "item__isPickable") && !uniqRes
      return
    if slotName == ""
      
      slotName = equip_slots[0] ?? ""
      for slot in equip_slots
        let name = slot ?? ""
        let item = human_equipment__slots |> get_child(name)
        if item != null
          let slotItemEid = (*item as Object)?.item ?? INVALID_ENTITY_ID
          if slotItemEid != INVALID_ENTITY_ID
            continue
          slotName = name
        else
          continue
        break
    equip_item_entity_to_slot(eid, item_eid, slotName, true)
    res = true
  return res


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


def pickup_one_item_impl(eid, item_eid : EntityId) : void
  var isPickedUp = false
  let lastOwner = get_Eid(item_eid, "item__lastOwner") ?? INVALID_ENTITY_ID
  query(lastOwner) <| $ [es(REQUIRE=lootable)] (isAlive : bool = true;
                                                var itemContainer : EidList)
    if isAlive
      return
    if remove_entity_from_container(itemContainer, item_eid)
      isPickedUp = true
      insert_item(eid, item_eid)

  if isPickedUp
    return

  if (!has(lastOwner, "lootable") &&
      (!has(item_eid, "item__isPickable") || !(get_bool(item_eid, "item__isOnGround") ?? false)))
    return
  if !can_pickup_item_by_volume(item_eid, eid)
    return

  insert_item(eid, item_eid)

def pickup_item_impl(eid, item_eid : EntityId; useful_only : bool) : void
  if item_eid == INVALID_ENTITY_ID || dead_or_downed(eid) || !can_pickup_items(eid)
    return
  if useful_only && !is_item_useful(eid, item_eid)
    return
  if !try_pickup_item(eid, item_eid)
    return
  if has(item_eid, "item__specialPickup")
    sendEvent(item_eid, CmdPickupSpecialItem(pickuperEid = eid, usefulOnly = useful_only))
    return

  var equipToSlots = false
  query(item_eid) <| $ [es] (item__equipToSlots : Array)
    if length(item__equipToSlots) != 0
      equipToSlots = true
      if equip_item_entity(eid, item_eid, item__equipToSlots)
        remove_item_from_entity_container(item_eid)
  if equipToSlots
    return

  let res = query(item_eid) <| $ [es] (item__id : int)
    if item__id != INVALID_ITEM_ID
      pickup_one_item_impl(eid, item_eid)
  if !res
    logwarn("Unable to pickup item {item_eid}, exist={doesEntityExist(item_eid)}")


def pickup_item_ex(eid, item_eid : EntityId; useful_only : bool) : void
  if eid == INVALID_ENTITY_ID
    return
  if !try_pickup_item(eid, item_eid)
    return
  if is_server()
    pickup_item_impl(eid, item_eid, useful_only)
  else
    send_net_event(eid, HumanPickupItemRequest(itemEid = item_eid, usefulOnly = useful_only))

    if can_pickup_item(item_eid, eid)
      sendEvent(eid, EventOnLootPickup(itemEid = item_eid))


def pickup_item(eid, item_eid : EntityId) : void
  pickup_item_ex(eid, item_eid, false)













def stop_use_item_impl(eid : EntityId)
  sendEventImmediate(eid, EventInterruptItemUse())


def stop_use_item(eid : EntityId)
  if is_server()
    stop_use_item_impl(eid)
  else
    send_net_event(eid, HumanStopUseItemRequest())
