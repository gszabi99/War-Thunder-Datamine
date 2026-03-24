require ecs
require ecs.safe
require ecs.common

[es(on_appear, tag=server, after=unit_init_completed_es)]
def create_items_for_soldier_on_appear(evt : Event;
                                       eid : EntityId;
                                       inventory__itemCreateTemplates : Object;
                                       var inventory__itemsWaitingCreate : EidList?)
  for it in inventory__itemCreateTemplates
    let item_template = add_sub_template_name(it.key, "initial_inventory")
    let items_count = it.value ?? 0
    for _i in range(0, items_count)
      let itemEid = createEntity(item_template) <| $(var init : ComponentsInitializer)
        set(init, "item__lastOwner", eid)
        set(init, "item__ownerEid", eid)
      if inventory__itemsWaitingCreate != null
        *inventory__itemsWaitingCreate |> push(itemEid)

[es(on_appear, tag=server)]
def check_items_for_soldier_on_appear(evt : Event;
                                      eid aka item_eid : EntityId;
                                      item__ownerEid : EntityId)
  if !!item__ownerEid
    query(item__ownerEid) <| $ [es(REQUIRE_NOT=inventory_created)] (var inventory__itemsWaitingCreate : EidList?)
      if inventory__itemsWaitingCreate == null
        addSubTemplate(item__ownerEid, "inventory_created")
        return
      else
        let itemIdx = find_index(*inventory__itemsWaitingCreate, item_eid)
        if itemIdx >= 0
          erase(*inventory__itemsWaitingCreate, itemIdx)
        if length(*inventory__itemsWaitingCreate) == 0
          addSubTemplate(item__ownerEid, "inventory_created")