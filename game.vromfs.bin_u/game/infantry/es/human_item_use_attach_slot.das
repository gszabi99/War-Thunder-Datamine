require ecs
require ecs.common
require strings

[es(tag=gameClient, track=human_inventory__entityToUse)]
def human_inventory_use_vis_entity(evt : Event;
                                   eid : EntityId;
                                   human_inventory__entityToUse : EntityId;
                                   human_inventory__targetToUse : EntityId;
                                   var human_item_use__visEntity : EntityId&)
  destroyEntity(human_item_use__visEntity)
  human_item_use__visEntity = INVALID_ENTITY_ID

  let selfUse = human_inventory__targetToUse == INVALID_ENTITY_ID || human_inventory__targetToUse == eid
  let templName = (selfUse
                    ? get_string(human_inventory__entityToUse, "item__selfUseVisEntityTemplateName", "")
                    : get_string(human_inventory__entityToUse, "item__targetUseVisEntityTemplateName", "")
                  )
  if !empty(templName)
    human_item_use__visEntity = createEntity(templName) <| $(var init : ComponentsInitializer)
      set(init, "animchar_attach__attachedTo", eid)

[es(tag=gameClient, on_disappear)]
def human_inventory_cleanup(evt : Event; var human_item_use__visEntity : EntityId&)
  destroyEntity(human_item_use__visEntity)
  human_item_use__visEntity = INVALID_ENTITY_ID
