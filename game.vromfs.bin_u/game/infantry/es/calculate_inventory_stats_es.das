require ecs

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
      on_event=EventScriptReloaded)]
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
