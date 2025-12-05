require ecs
require ecs.safe

require %appGame.wt_events


[es(tag=server)]
def gun_initial_ammo_spawn_on_loot_gun(evt : EventOnWeapSlotItemPickup; eid : EntityId)
  query(evt.itemEid) <| $ [es] (gun__ammoHolders : Array;
                                gun__initialAmmoHoldersCount : IntList;
                                var gun__isInitialAmmoHoldersSpawned : bool&)
    if gun__isInitialAmmoHoldersSpawned
      return
    gun__isInitialAmmoHoldersSpawned = true

    let ammoHoldersLen = min(length(gun__ammoHolders), length(gun__initialAmmoHoldersCount))
    if ammoHoldersLen < 1
      return

    for ammoHolder, count in gun__ammoHolders, gun__initialAmmoHoldersCount
      let ammoTemplate = ammoHolder ?? ""
      if ammoTemplate == ""
        continue

      for _i in range(0, count)
        createEntity(ammoTemplate) <| $(var init : ComponentsInitializer)
          set(init, "item__ownerEid", eid)


[es(tag=server)]
def gun_initial_ammo_update_weap_info_on_loot_gun(evt : EventOnWeapSlotItemPickup;
                                                  var human_weap__weapInfo : Array&)
  query(evt.itemEid) <| $ [es] (gun__ammoHolders : Array;
                                gun__initialAmmoHoldersCount : IntList)
    let ammoHoldersLen = min(length(gun__ammoHolders), length(gun__initialAmmoHoldersCount))
    if ammoHoldersLen < 1
      return

    var weapInfo = getRW_ecs_object(human_weap__weapInfo[evt.slotId])
    if weapInfo == null
      return

    set(*weapInfo, "reserveAmmoTemplate", gun__ammoHolders[0])
    set(*weapInfo, "numReserveAmmo", gun__initialAmmoHoldersCount[0])

    if ammoHoldersLen < 2
      return

    using() <| $(var additional_ammo_templates : Array)
      using() <| $(var additional_ammo_nums : Array)
        for i in range(1, ammoHoldersLen)
          push(additional_ammo_templates, gun__ammoHolders[i])
          push(additional_ammo_nums, gun__initialAmmoHoldersCount[i])
        set(*weapInfo, "additionalReserveAmmoTemplates", additional_ammo_templates)
        set(*weapInfo, "additionalNumReserveAmmos", additional_ammo_nums)
