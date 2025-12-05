require ecs
require ecs.common


[es(tag=server, track=human_weap__gunEids)]
def track_weapon_slots(evt : Event; human_weap__gunEids : EidList)
  for gunIdx in iter_range(human_weap__gunEids)
    query(human_weap__gunEids[gunIdx]) <| $ [es] (var slot_attach__weaponSlotIdx : int&)
      slot_attach__weaponSlotIdx = gunIdx


[es(tag=server, track=human_weap__gunMods)]
def track_mods_slots(evt : Event; human_weap__gunMods : Array)
  for modSlotIdx in iter_range(human_weap__gunMods)
    let gunMods = human_weap__gunMods[modSlotIdx] |> get_ecs_EidList()
    if gunMods != null
      for gunModEid in *gunMods
        query(gunModEid) <| $ [es] (var slot_attach__weaponSlotIdx : int&)
          slot_attach__weaponSlotIdx = modSlotIdx


[es(tag=server, on_appear, REQUIRE_NOT=weaponMod)]
def track_weapon_slot(evt : Event; eid, gun__owner : EntityId; var slot_attach__weaponSlotIdx : int&)
  if slot_attach__weaponSlotIdx < 0
    query(gun__owner) <| $ [es] (human_weap__gunEids : EidList)
      slot_attach__weaponSlotIdx = find_index(human_weap__gunEids, eid)


[es(tag=server, on_appear, REQUIRE=weaponMod)]
def track_weapon_mod_slot(evt : Event;
                          animchar_attach__attachedTo : EntityId;
                          var slot_attach__weaponSlotIdx aka mod_slot_attach__weaponSlotIdx : int&)
  if mod_slot_attach__weaponSlotIdx < 0
    query(animchar_attach__attachedTo) <| $ [es] (slot_attach__weaponSlotIdx : int)
      mod_slot_attach__weaponSlotIdx = slot_attach__weaponSlotIdx

[es(tag=server, on_appear, REQUIRE=itemInWorld)]
def item_in_world_always_visible(evt : Event; var slot_attach__visible : bool&)
  slot_attach__visible = true
