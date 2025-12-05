require ecs
require ecs.common
require ecs.safe
require CollRes
require DagorSystem
require AnimV20
require GeomNodeTree


[es(on_appear)]
def dm_parts_es(evt : Event;
                collres : CollisionResource&;
                var dm_parts__parts : Object&;
                var dm_parts__dmgMult : FloatList&;
                var dm_parts__type : StringList&;
                var dm_parts__bulletTransparent : BoolList&;
                var dm_parts__partsArmor : FloatList&;
                var dm_parts__dotMult : FloatList?)
  let haveSpecificParts = !empty(dm_parts__parts)
  var type_str = ""
  for nodeId in range(0, collres_get_nodesCount(collres))
    var dmgMult = 1.0f
    var dotMult = 0.0f
    var armor = 0.0f
    let name = collres_get_node(collres, nodeId) |> collnode_get_name()
    var part = dm_parts__parts[name] ?as Object
    var bulletTransparent = haveSpecificParts
    if part != null
      dmgMult = get_float(*part, "dmgMult") ?? dmgMult
      dotMult = get_float(*part, "dotMult") ?? 0.0f
      armor = get_float(*part, "armor") ?? armor
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
    if dm_parts__dotMult != null
      push(*dm_parts__dotMult, dotMult)

[es(on_appear)]
def init_segmented_armor_orientation_node(evt : Event;
                                          animchar : AnimcharBaseComponent&;
                                          human__segmentedArmorOrientationNode : string;
                                          var human__segmentedArmorOrientationNodeId : int&)
  human__segmentedArmorOrientationNodeId = geomtree_findNodeIndex(*animchar.nodeTree, human__segmentedArmorOrientationNode)

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

[es(tag=server, on_appear)]
def on_segmented_armor_appear(evt : Event;
                              eid : EntityId;
                              item__ownerEid : EntityId;
                              item__lastOwner : EntityId;
                              @shared_comp segmented_armor__segmentTemplates : StringList;
                              @shared_comp segmented_armor__hudDMAssignment : StringList;
                              var segmented_armor__segmentsEids : EidList&)
  if length(segmented_armor__segmentTemplates) != length(segmented_armor__hudDMAssignment)
    logerr("lengths of segmented_armor__hudDMAssignment and segmented_armor__hudDMAssignment are not equal!")
    return
  var uniqueHudDmParts : table<string>
  var duplicateHudDmPartsFound = false
  for hudDmPart in segmented_armor__hudDMAssignment
    if !empty(hudDmPart) && key_exists(uniqueHudDmParts, string(hudDmPart))
      duplicateHudDmPartsFound = true
      logerr("segmented_armor__hudDMAssignment has a duplicate key: {hudDmPart} in template {getEntityTemplateName(eid)}")
    else
      uniqueHudDmParts |> insert(string(hudDmPart))
  if duplicateHudDmPartsFound
    return
  for segmentTmpl, hudDmPart in segmented_armor__segmentTemplates, segmented_armor__hudDMAssignment
    if empty(segmentTmpl)
      push(segmented_armor__segmentsEids, INVALID_ENTITY_ID) 
    else
      let segmentEid = createEntity(string(segmentTmpl)) <| $(var init)
        init |> set("item__ownerEid", item__ownerEid)
        init |> set("item__lastOwner", item__lastOwner)
        init |> set("item__armorHudDmPart", hudDmPart)
      if !segmentEid
        logerr("Failed to create entity {segmentTmpl}")
      push(segmented_armor__segmentsEids, segmentEid)

[es(tag=server, on_appear, track=(item__ownerEid, item__lastOwner))]
def on_segmented_armor_change_owner(evt : Event;
                                    item__ownerEid aka parent_item__ownerEid : EntityId;
                                    item__lastOwner aka parent_item__lastOwner : EntityId;
                                    segmented_armor__segmentsEids : EidList)
  for segmentEid in segmented_armor__segmentsEids
    query(segmentEid) <| $ [es] (var item__ownerEid : EntityId&;
                                 var item__lastOwner : EntityId&)
      item__ownerEid = parent_item__ownerEid
      item__lastOwner = parent_item__lastOwner

[es(tag=server, on_disappear)]
def on_segmented_armor_disappear(evt : Event;
                                 var segmented_armor__segmentsEids : EidList&)
  for segmentEid in segmented_armor__segmentsEids
    destroyEntity(segmentEid)
