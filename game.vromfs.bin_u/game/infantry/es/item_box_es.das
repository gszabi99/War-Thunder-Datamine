require ecs
require net

require %appGame.wt_events
require %appGame.infantry.es.inventory_common


[es(tag=server, before=useful_box_use_finish_es)]
def item_box_use_es(evt : CmdUseUsefulBox;
                    useful_box__giveItem : string;
                    var useful_box__successUse : bool&;
                    var useful_box__requiredUseCount : int&;
                    useful_box__fillMode : Tag const?;
                    useful_box__itemExistTag : string = "")
  useful_box__successUse = true
  useful_box__requiredUseCount = 1

  if useful_box__itemExistTag == "" 
    evt.requesterEid |> push_item_in_cont(useful_box__giveItem)
    return
  query(evt.requesterEid) <| $ [es] (itemContainer : EidList;
                                     human_equipment__slots : Object;
                                     human_inventory__usefulBoxItemsCapacity : int)
    var inventoryCapacity = human_inventory__usefulBoxItemsCapacity
    let backpack = get_ecs_object(human_equipment__slots, "backpack")
    if backpack != null
      let backpackItemEid = get_Eid(*backpack, "item")
      if backpackItemEid != null
        inventoryCapacity += get_int(*backpackItemEid, "attachable_backpack__capacity") ?? 0
    var inventoryItemsCount = 0
    for itemEid in itemContainer
      if has(itemEid, "backpackPlaceableItem")
        ++inventoryItemsCount

    if inventoryItemsCount < inventoryCapacity
      let emptyItemSpace = inventoryCapacity - inventoryItemsCount
      let addItemsAmount = useful_box__fillMode != null ? emptyItemSpace : 1
      for _i in range(addItemsAmount)
        evt.requesterEid |> push_item_in_cont(useful_box__giveItem)
    else
      useful_box__successUse = false

[es(tag=server, after=item_box_use_es, before=useful_box_use_finish_es, REQUIRE=useful_box__giveItem)]
def item_box_use_finish_es(evt : CmdUseUsefulBox; useful_box__successUse : bool; useful_box__hintItemFull : string)
  if !useful_box__successUse
    send_net_event(evt.requesterEid, CmdHeroLogEvent(event = "item_is_full", text = useful_box__hintItemFull))
