require ecs

[es(after=human_inventory_medkit_es, on_appear, track=human_inventory__entityToUse)]
def loc_human_use_medikt(evt : Event; isDowned : bool; human_inventory__entityToUse : EntityId; var heal__continuousInput : bool&)
  heal__continuousInput = has(human_inventory__entityToUse, "item__healAmount") ? !isDowned : true
