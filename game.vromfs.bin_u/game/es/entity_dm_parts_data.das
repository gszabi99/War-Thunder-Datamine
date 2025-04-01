require ecs
require ecs.common
require ecs.safe
require CollRes
require DagorSystem
require DagorConsole
require AnimV20
require DagorRandom


[es(on_appear)]
def dm_parts_es(evt : Event;
                collres : CollisionResource&;
                var dm_parts__parts : Object&;
                var dm_parts__dmgMult : FloatList&;
                var dm_parts__type : StringList&;
                var dm_parts__bulletTransparent : BoolList&;
                var dm_parts__partsArmor : FloatList&;
                var dm_parts__partsArmorMin : FloatList?;
                var dm_parts__dotMult : FloatList?;
                var dm_parts__armorItemEids : EidList?)
  let haveSpecificParts = !empty(dm_parts__parts)
  var type_str = ""
  for nodeId in range(0, collres_get_nodesCount(collres))
    var dmgMult = 1.0f
    var dotMult = 0.0f
    var armor = 0.0f
    var armorMin = 0.0f
    let name = collres_get_node(collres, nodeId) |> collnode_get_name()
    var part = dm_parts__parts[name] ?as Object
    var bulletTransparent = haveSpecificParts
    if part != null
      dmgMult = get_float(*part, "dmgMult") ?? dmgMult
      dotMult = get_float(*part, "dotMult") ?? 0.0f
      armor = get_float(*part, "armor") ?? armor
      armorMin = get_float(*part, "armorMin") ?? armorMin
      type_str = get_string(*part, "type", "")
      var collNodeId =  (*part)["collNodeId"] ?as int
      assert(collNodeId == null || *collNodeId == nodeId)
      set(*part, "collNodeId", nodeId)
      bulletTransparent = get_bool(*part, "bulletTransparent") ?? false
    else
      dm_parts__parts |> push_to_object(name) <| $(var info : Object)
        info |> set("collNodeId", nodeId)
      type_str = ""
    push(dm_parts__dmgMult, dmgMult)
    push(dm_parts__type, type_str)
    push(dm_parts__bulletTransparent, bulletTransparent)
    push(dm_parts__partsArmor, armor)
    if dm_parts__partsArmorMin != null
      push(*dm_parts__partsArmorMin, armorMin)
    if dm_parts__dotMult != null
      push(*dm_parts__dotMult, dotMult)

  if dm_parts__armorItemEids != null
    resize(*dm_parts__armorItemEids, collres_get_nodesCount(collres))

[es(on_appear)]
def dm_parts_verefication_es(evt : Event;
                             eid : EntityId;
                             collres : CollisionResource&;
                             dm_parts__parts : Object&;
                             collres__res : string = "")
  for dmPart in dm_parts__parts
    let nodeIdx = collres_get_node_index_by_name(collres, dmPart.key)
    if nodeIdx < 0
      logerr("Entity with template '{getEntityTemplateName(eid)}' references collnode '{dmPart.key}'
              in 'dm_parts__parts' component and it is not found in collres '{collres__res}'")

def find_anim_by_name(name : string;
                      dm_parts__parts : Object&)
  let it = dm_parts__parts[name] ?as Object
  if it == null
    return -1
  let animModeName = get_string(*it, "type", "")
  return animModeName != "" ? animV20_get_enum_value_by_name(animModeName) : -1

[es(tag=render, on_appear)]
def client_dm_parts_es(evt : Event;
                       collres : CollisionResource&;
                       dm_parts__parts : Object&;
                       var dm_parts__hitPartsAnimationId : Array&)
  for nodeId in range(0, collres_get_nodesCount(collres))
    push(dm_parts__hitPartsAnimationId, find_anim_by_name(collres_get_node(collres, nodeId) |> collnode_get_name(), dm_parts__parts))
