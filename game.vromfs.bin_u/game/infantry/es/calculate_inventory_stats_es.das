require ecs
require %appGame.wt_events

def calculate_current_volume_impl(itemContainer : EidList;
                                  human_equipment__slots : Object;
                                  human_weap__gunEids : EidList;
                                  human_weap__gunMods : Array;
                                  var human_inventory__currentVolume : float&;
                                  var human_inventory__currentWeight : float&)
  human_inventory__currentVolume = 0.0
  human_inventory__currentWeight = 0.0

  for itemEid in itemContainer
    if !itemEid
      continue
    let volume = get_float(itemEid, "item__volume") ?? 0.
    let weight = get_float(itemEid, "item__weight") ?? 0.
    human_inventory__currentVolume += volume
    human_inventory__currentWeight += weight

  for it in human_equipment__slots
    let obj = get_ecs_object(it.value)
    if obj == null
      continue
    let itemEid = get_Eid(obj, "item") ?? INVALID_ENTITY_ID
    if !itemEid
      continue
    query(itemEid) <| $ [es] (item__weight : float)
      human_inventory__currentWeight += item__weight

  for it in human_weap__gunEids
    query(it) <| $ [es] (item__weight : float)
      human_inventory__currentWeight += item__weight
    let ammoHolderEid = get_Eid(it, "gun__ammoHolderEid") ?? INVALID_ENTITY_ID
    if ammoHolderEid != INVALID_ENTITY_ID
      query(ammoHolderEid) <| $ [es] (item__weight : float)
        human_inventory__currentWeight += item__weight

  for it in human_weap__gunMods
    let gunModEids = get_ecs_EidList(it)
    for gunMod in *gunModEids
      query(gunMod) <| $ [es] (item__weight : float)
        human_inventory__currentWeight += item__weight

[es(tag=server,
      on_appear,
      track=itemContainer,
      track=human_equipment__slots,
      track=human_weap__gunEids,
      track=human_weap__gunMods,
      on_event=EventScriptReloaded,
      on_event=CmdRecalcHumanWeight)]
def calculate_current_volume_es(evt : Event;
                                itemContainer : EidList;
                                human_equipment__slots : Object;
                                human_weap__gunEids : EidList;
                                human_weap__gunMods : Array;
                                var human_inventory__currentVolume : float&;
                                var human_inventory__currentWeight : float&)
  calculate_current_volume_impl(itemContainer, human_equipment__slots,
    human_weap__gunEids, human_weap__gunMods,
    human_inventory__currentVolume, human_inventory__currentWeight)

[es(tag=server,
      on_appear,
      track=gun__ammoHolderEid,
      REQUIRE=gun__ammoHolderEid)]
def calculate_current_volume_for_gun_es(evt : Event;
                                        gun__owner : EntityId)
  query(gun__owner) <| $ [es] (itemContainer : EidList;
                               human_equipment__slots : Object;
                               human_weap__gunEids : EidList;
                               human_weap__gunMods : Array;
                               var human_inventory__currentVolume : float&;
                               var human_inventory__currentWeight : float&)
    calculate_current_volume_impl(itemContainer, human_equipment__slots,
      human_weap__gunEids, human_weap__gunMods,
      human_inventory__currentVolume, human_inventory__currentWeight)


def private recalc_magazine_weight_impl(ammo_holder__ammoCount : int;
                                        ammo_holder__emptyWeight : float;
                                        ammo_holder__bulletWeight : float;
                                        var item__weight : float&) : bool
  if ammo_holder__bulletWeight >= 0.0 && ammo_holder__emptyWeight >= 0.0
    item__weight = ammo_holder__emptyWeight + float(ammo_holder__ammoCount) * ammo_holder__bulletWeight
    return true
  return false

[es(tag=server, on_appear, before=inventory_item_push_es)]
def recalc_magazine_weight_es(evt : Event;
                              ammo_holder__ammoCount : int;
                              ammo_holder__emptyWeight : float;
                              ammo_holder__bulletWeight : float;
                              var item__weight : float&)
  recalc_magazine_weight_impl(ammo_holder__ammoCount, ammo_holder__emptyWeight, ammo_holder__bulletWeight, item__weight)

[es(tag=server, on_event=CmdRecalcMagazineWeight)]
def recalc_magazine_weight_on_reload_es(evt : Event;
                                        ammo_holder__ammoCount : int;
                                        ammo_holder__emptyWeight : float;
                                        ammo_holder__bulletWeight : float;
                                        item__ownerEid : EntityId;
                                        var item__weight : float&)
  if recalc_magazine_weight_impl(ammo_holder__ammoCount, ammo_holder__emptyWeight, ammo_holder__bulletWeight, item__weight)
    sendEvent(item__ownerEid, CmdRecalcHumanWeight())
