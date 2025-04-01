module human_weapon_utils_common shared
require ecs
require inventory
require DagorSystem

def create_ammo_holder_in_container(item_template : string; container_owner : EntityId; ammo_count : int)
  createEntity(item_template) <| $ [es] (init)
    init |> set("ammo_holder__ammoCount", ammo_count)
    init |> set("item__ownerEid", container_owner)


def put_ammo_to_container(ammo_count : int; item_eid, owner : EntityId)
  if ammo_count <= 0
    return

  var success = false
  query(item_eid) <| $ [es] (ammo_holder__templateName : string;
                             ammo_holder__boxedAmmo : Tag const?;
                             ammo_holder__id aka add_ammo_holder__id = INVALID_ITEM_ID;
                             boxed_ammo__maxAmmoCount : int const?)
    success = true

    if ammo_holder__boxedAmmo == null
      create_ammo_holder_in_container(ammo_holder__templateName, owner, ammo_count)
    else
      query(owner) <| $ [es] (var itemContainer : EidList)
        var countLeft = ammo_count
        let maxAmmoCount = boxed_ammo__maxAmmoCount != null ? *boxed_ammo__maxAmmoCount : ammo_count
        if countLeft % maxAmmoCount != 0
          
          
          var isSomeMagazineRefilled = false
          for i in iter_range(itemContainer)
            query(itemContainer[i]) <| $ [es] (ammo_holder__ammoCount : int; ammo_holder__id aka eisting_ammo_holder__id = INVALID_ITEM_ID)
              if add_ammo_holder__id == eisting_ammo_holder__id && ammo_holder__ammoCount < maxAmmoCount
                let ammoToFill = maxAmmoCount - ammo_holder__ammoCount
                create_ammo_holder_in_container(ammo_holder__templateName, owner, ammo_holder__ammoCount + min(countLeft, ammoToFill))
                destroyEntity(itemContainer[i])
                itemContainer |> erase(i)
                countLeft = max(0, countLeft - ammoToFill)
                isSomeMagazineRefilled = true
            if isSomeMagazineRefilled
              break
        while countLeft > 0
          create_ammo_holder_in_container(ammo_holder__templateName, owner, min(maxAmmoCount, countLeft))
          countLeft -= maxAmmoCount
  if !success
    logerr("can't put ammo to container, item.ammoTemplate is expected in {item_eid} <{getEntityTemplateName(item_eid)}>")
