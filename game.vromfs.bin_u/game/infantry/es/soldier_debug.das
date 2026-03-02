options no_aot
require ecs
require ecs.safe
require ecs.ecs_template
require %appGame.infantry.es.net_console_macro
require %game.events


[net_console_cmd(name="soldier.rearm", hint="Restore soldier gun's ammo")]
def soldier_rearm_cmd(ammo_count : int = 10; @net_hero hero_eid : EntityId)
  query(hero_eid) <| $ [es] (human_weap__gunEids : EidList)
    for gunEid in human_weap__gunEids
      query(gunEid) <| $ [es] (gun__ammoHolders : Array)
        for ammoHolder in gun__ammoHolders
          let ammoTemplate = ammoHolder ?? ""
          if ammoTemplate == ""
            continue
          for _i in range(0, ammo_count)
            createEntity(ammoTemplate) <| $(var init : ComponentsInitializer)
              set(init, "item__ownerEid", hero_eid)


[net_console_cmd(name="soldier.unarm", hint="Disarm soldier gun's ammo")]
def soldier_unarm_cmd(@net_hero hero_eid : EntityId)
  query(hero_eid) <| $ [es] (human_weap__currentGunEid : EntityId;
                             var itemContainer : EidList&)
    query(human_weap__currentGunEid) <| $ [es] (gun__ammoHolders : Array)
      let humanAmmoTemplate = gun__ammoHolders?[0] ?? ""
      if empty(humanAmmoTemplate)
        return
      let humanAmmoHolderId = int(ecs_hash(humanAmmoTemplate))
      var index = length(itemContainer) - 1
      while index >= 0
        query(itemContainer[index]) <| $ [es] (ammo_holder__id : int)
          if ammo_holder__id == humanAmmoHolderId
            destroyEntity(itemContainer[index])
            itemContainer |> erase(index)
        index--
    sendEventImmediate(human_weap__currentGunEid, CmdUnloadAmmo(unloadManually = true))

[net_console_cmd(name="humanphys.forceSimplifiedPhysAll", hint="0 - default, 1 for enable, 2 force disable")]
def human_phys_simplified_phys_debug(mode = 0)
  let forceSimplifiedPhys = find_query() <| $ [es] (eid : EntityId; var human_phys__forceSimplifiedPhys : bool&)
    if mode == 0
      destroyEntity(eid)
    else
      human_phys__forceSimplifiedPhys = (mode == 1)
    return true
  if !forceSimplifiedPhys && mode != 0
    createEntity("force_simplified_phys") <| $(init)
      init |> set("human_phys__forceSimplifiedPhys", (mode == 1))

[net_console_cmd(name="humanphys.forceSimplifiedWalkQueryAll", hint="0 - default, 1 for enable, 2 force disable")]
def human_phys_simplified_walk_query_debug(mode = 0)
  let forceSimplifiedWalkQuery = find_query() <| $ [es] (eid : EntityId; var human_phys__forceSimplifiedWalkQuery : bool&)
    if mode == 0
      destroyEntity(eid)
    else
      human_phys__forceSimplifiedWalkQuery = (mode == 1)
    return true
  if !forceSimplifiedWalkQuery && mode != 0
    createEntity("force_simplified_walk_query") <| $(init)
      init |> set("human_phys__forceSimplifiedWalkQuery", (mode == 1))


[ecs_template]
struct full_body_anim_test
  full_body_anim_test_tag : Tag

[console_cmd(name="anim.full_body_test")]
def full_body_anim_test_cmd()
  let found = find_query() <| $ [es(REQUIRE=full_body_anim_test_tag)] (eid : EntityId)
    destroyEntity(eid)
    return true
  if !found
    createEntity("full_body_anim_test")
