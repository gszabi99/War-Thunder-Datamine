require ecs
require AnimV20
require GeomNodeTree
require DagorSystem


[es(on_appear)]
def backstab_node_load_es(evt : Event; eid : EntityId; animchar : AnimcharBaseComponent; backstab__nodeName : string; var backstab__nodeIdx : int&)
  backstab__nodeIdx = geomtree_findNodeIndex(*animchar.nodeTree, backstab__nodeName)
  if backstab__nodeIdx < 0
    logerr("backstab.nodeName \"{backstab__nodeName}\" not found (eid: {eid} template: {getEntityTemplateName(eid)})")


[es(tag=server, track=human_equipment__slots, on_appear)]
def backstab_head_armor_es(evt : Event; human_equipment__slots : Object; var backstab__headArmor : float&)
  backstab__headArmor = 0.0
  let headSlot = get_ecs_object(human_equipment__slots, "head")
  if headSlot != null
    let headArmorEid = get_Eid(*headSlot, "item") ?? INVALID_ENTITY_ID
    backstab__headArmor = get_float(headArmorEid, "item__armorAmount") ?? 0.0
