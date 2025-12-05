require ecs
require %game.events

require %appGame.wt_events
require DngWeapon
require %appGame.infantry.es.human_weap_common


def fill_props(eid : EntityId; human_weap__gunEids : EidList; update_ammo_holder : bool)
  for slot, gunEid in iter_range(human_weap__gunEids), human_weap__gunEids
    query(gunEid) <| $ [es] (var customProps : Object; var item__lastOwner : EntityId&)
      item__lastOwner = eid
      human_gun_to_custom_props(gunEid, customProps, update_ammo_holder)
      human_gun_mod_to_custom_props(eid, slot, "", customProps, update_ammo_holder)

[es(tag=server)]
def human_inventory_fill_guns_custom_props_on_death(evt : EventEntityDied; eid : EntityId; human_weap__gunEids : EidList)
  fill_props(eid, human_weap__gunEids, true)

[es(tag=gameClient, REQUIRE=hero)]
def hero_human_inventory_fill_guns_custom_props_on_death(evt : EventEntityDied; eid : EntityId; human_weap__gunEids : EidList)
  
  fill_props(eid, human_weap__gunEids, false)
