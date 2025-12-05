require ecs
require inventory
require DagorSystem

[es(on_appear)]
def items_es(evt : Event; eid : EntityId; item__proto : string; var item__id : int&)
  if empty(item__proto)
    logerr("item__proto is empty for entity <{eid}> with template '{getEntityTemplateName(eid)}'")
    return
  if item__id == INVALID_ITEM_ID
    item__id = int(ecs_hash(item__proto))
