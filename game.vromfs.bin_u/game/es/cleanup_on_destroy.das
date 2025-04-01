require ecs

[es(on_disappear, tag=server)]
def cleanup_equipment_on_destroy_es(evt : Event; human_equipment__slots : ecs::Object)
  for it in human_equipment__slots
    let obj = get_ecs_object(it.value)
    destroyEntity(deref(get_Eid(deref(deref(obj)["item"]))))
    for ent in deref(get_ecs_array(deref(deref(obj)["entities"])))
      destroyEntity(get_Eid(ent) ?? INVALID_ENTITY_ID)

[es(on_disappear, tag=server)]
def cleanup_intentory_on_destroy_es(evt : Event; itemContainer : EidList)
  for itemEid in itemContainer
    destroyEntity(itemEid)
