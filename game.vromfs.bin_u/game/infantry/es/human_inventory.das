require ecs
require net
require ecs.common
require DagorSystem
require HumanPhys
require AnimV20

require %appGame.wt_events
require %appGame.infantry.es.action_common
require %appGame.infantry.es.inventory_common
require %appGame.infantry.es.human_weap_common
require PropsManager

[es(tag=server, on_appear)]
def inventory_item_push_es(evt : Event; eid : EntityId; item__ownerEid : EntityId)
  query(item__ownerEid) <| $ [es] (var itemContainer : EidList)
    if find_index(itemContainer, eid) == -1
      push(itemContainer, eid)

[es(tag=server, on_appear)]
def set_armor_pickup_score(evt : Event; eid : EntityId; var item__pickupScore : float&; item__armorAmount : float)
  if item__pickupScore < 0.0
    item__pickupScore = item__armorAmount
  else
    logerr("item {getEntityTemplateName(eid)} has multiple pickupScore sources")


[es(tag=server, on_appear)]
def set_inventory_extension_pickup_score(evt : Event; eid : EntityId; var item__pickupScore : float&; item__inventoryExtension : float)
  if item__pickupScore < 0.0
    item__pickupScore = item__inventoryExtension
  else
    logerr("item {getEntityTemplateName(eid)} has multiple pickupScore sources")


[es(tag=server, on_disappear, on_event=(EventEntityDied))]
def human_inventory_on_death(evt : Event; eid, human_inventory__entityToUse : EntityId)
  if human_inventory__entityToUse != INVALID_ENTITY_ID
    sendEventImmediate(eid, EventInterruptItemUse())


[es(tag=server, after=before_human_inventory_use_update)]
def human_inventory_server_es(info : UpdateStageInfoAct;
                              eid : EntityId;
                              human_inventory__entityUseEnd : float;
                              var human_inventory__entityToUse : EntityId&;
                              human_inventory__targetToUse : EntityId;
                              var itemContainer : EidList&)
  if !human_inventory__entityToUse
    return

  if !(info.curTime > human_inventory__entityUseEnd && info.curTime - info.dt <= human_inventory__entityUseEnd)
    return

  var needRemove = true
  query(human_inventory__entityToUse) <| $ [es] (var item__useCount : int&) { needRemove = --item__useCount <= 0; }

  if !needRemove
    sendEventImmediate(human_inventory__entityToUse, EventOnLootItemUsed(target = human_inventory__targetToUse))
    sendEventImmediate(eid, EventOnLootUse(itemEid = human_inventory__entityToUse))
    human_inventory__entityToUse = INVALID_ENTITY_ID
  elif remove_item_from_cont(human_inventory__entityToUse, itemContainer)
    sendEventImmediate(human_inventory__entityToUse, EventOnLootItemUsed(target = human_inventory__targetToUse))
    sendEventImmediate(eid, EventOnLootUse(itemEid = human_inventory__entityToUse))
    destroyEntity(human_inventory__entityToUse)

  sendEventImmediate(eid, EventInterruptItemUse())
















[es(REQUIRE=human_inventory)]
def human_inventory_pickup_es(evt : CmdInventoryPickup; eid : EntityId)
  let itemEid = evt.itemEid
  run_action(eid, "pickup")
  if has(itemEid, "gunAttachable")
    if try_pickup_item(eid, itemEid) && can_pickup_item(itemEid, eid)
      sendEvent(eid, EventOnLootPickup(itemEid = itemEid))
    send_net_event(eid, CmdInventoryPickupGunMod(item = itemEid))
    return
  pickup_item_ex(eid, itemEid, evt.usefulOnly)


[es(REQUIRE=(human_inventory, human_weap))]
def human_inventory_drop_gun_es_event_handler(evt : CmdInventoryDropGun; eid : EntityId)
  if evt.slotId < 0
    return
  drop_weap_from_slot(eid, get_human_weapon_slot_name(evt.slotId))


[es(tag=server, REQUIRE=human_inventory)]
def human_drop_weap_request_es_event_handler(evt : HumanDropWeapRequest; eid : EntityId)
  drop_weap_from_slot_impl(eid, evt.slotId, true, false)

















[es(tag=server, REQUIRE=human_inventory)]
def human_remove_item_from_weap_request_es_event_handler(evt : HumanRemoveItemFromWeapRequest; eid : EntityId)
  remove_item_from_weap_impl(eid, evt.slotId, evt.slotName, evt.toGround)

[es(tag=server, REQUIRE=human_inventory)]
def human_pickup_item_request_es_event_handler(evt : HumanPickupItemRequest; eid : EntityId)
  pickup_item_impl(eid, evt.itemEid, evt.usefulOnly)


[es(on_appear, tag=server)]
def drop_item_cb(evt : Event;
                 eid : EntityId;
                 drop_item_cb__lootCleanupTime : float;
                 drop_item_cb__modTemplates : StringList)
  if empty(drop_item_cb__modTemplates)
    if drop_item_cb__lootCleanupTime >= 0.f
      eid |> sendEvent(CmdBodyCleanup(time = drop_item_cb__lootCleanupTime))
  else
    for tmpl, i in drop_item_cb__modTemplates, range(length(drop_item_cb__modTemplates))
      let isLast = i == (length(drop_item_cb__modTemplates) - 1)
      let modTemplate = string(tmpl) |> add_sub_template_name("item_mod_creation_cb")
      createEntity(modTemplate) <| $(var init)
        init |> set("item_mod_creation_cb__lootCleanupTime", drop_item_cb__lootCleanupTime)
        init |> set("item_mod_creation_cb__isLast", isLast)
        init |> set("animchar_attach__attachedTo", eid)
  removeSubTemplate(eid, "drop_item_cb")


[es(on_appear, tag=server)]
def item_mod_creation_cb(evt : Event;
                         eid : EntityId;
                         animchar_attach__attachedTo : EntityId;
                         item_mod_creation_cb__lootCleanupTime : float;
                         item_mod_creation_cb__isLast : bool;
                         gunAttachable__slotName : string;
                         var slot_attach__slotId : int&)
  slot_attach__slotId = animchar_getSlotId(gunAttachable__slotName)
  if item_mod_creation_cb__lootCleanupTime >= 0.f
    if item_mod_creation_cb__isLast
      animchar_attach__attachedTo |> sendEvent(CmdBodyCleanup(time = item_mod_creation_cb__lootCleanupTime))
    eid |> sendEvent(CmdBodyCleanup(time = item_mod_creation_cb__lootCleanupTime))
  removeSubTemplate(eid, "item_mod_creation_cb")


[es(tag=server, REQUIRE=human_inventory)]
def human_inventory_on_stop_use_item_request(evt : HumanStopUseItemRequest;
                                             eid : EntityId)
  stop_use_item_impl(eid)
