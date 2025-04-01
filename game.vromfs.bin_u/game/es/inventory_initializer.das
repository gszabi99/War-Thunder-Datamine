require ecs
require ecs.safe

[es(on_appear, tag=server)]
def create_items_for_soldier_on_appear(evt : Event;
                                       eid : EntityId;
                                       inventory__itemCreateTemplates : Object)
  for it in inventory__itemCreateTemplates
    let item_template = it.key
    let items_count = it.value ?? 0
    for _i in range(0, items_count)
      createEntity(item_template) <| $(var init : ComponentsInitializer)
        set(init, "item__lastOwner", eid)
        set(init, "item__ownerEid", eid)