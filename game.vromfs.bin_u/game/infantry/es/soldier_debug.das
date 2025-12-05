options no_aot
require ecs
require ecs.safe
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
