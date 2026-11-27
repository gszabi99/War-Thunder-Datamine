module attach_common shared
require ecs
require ecs.safe
require ecs.common
require math
require DagorSystem
require AnimV20
require GeomNodeTree
require %game.events

def get_node_no(node : uint16)
  return int(node) & int(0xFF)

def find_base_attach_parent(parent_eid : EntityId)
  var parent = parent_eid
  query(parent_eid) <| $ [es] (animchar_attach__attachedTo : EntityId)
    parent = find_base_attach_parent(animchar_attach__attachedTo)
  return parent

def get_remapped_node_no(node : uint16)
  return (int(node) >> 8) & int(0xFF)


def skeleton_attach_with_remap_parent_impl(eid : EntityId;
                                           skeleton_attach__remapParentSlots : StringList;
                                           slots : Object;
                                           var animchar_attach__attachedTo : EntityId&;
                                           invalid_parent_eid = INVALID_ENTITY_ID)
  for slotName in skeleton_attach__remapParentSlots
    let possibleParent = slots[string(slotName)] ?as Object
    let possibleParentEid = possibleParent?.item ?? INVALID_ENTITY_ID
    if possibleParentEid == eid
      logerr("Entity try to attach to itself. Invalid slots in {skeleton_attach__remapParentSlots} for {eid} {getEntityTemplateName(eid)}")
      return
    if (!!possibleParentEid &&
        possibleParentEid != invalid_parent_eid &&
        has(possibleParentEid, "skeleton_attach__remapAffectSlots"))
      if animchar_attach__attachedTo != possibleParentEid

        var list = getRW_ecs_EidList(animchar_attach__attachedTo, "attaches_list")
        if list != null 
          let idx = find_index(*list, eid)
          if idx >= 0
            erase(*list, idx)

        animchar_attach__attachedTo = possibleParentEid
        sendEventImmediate(eid, CmdInitSkeletonAttach())
      return


def apply_slots_scale_attaches(slots : Object)
  for it in slots
    let item = (it.value as Object)?.item ?? INVALID_ENTITY_ID
    query(item) <| $ [es] (var animchar__scaledWtmNodeIds : IntList;
                           var animchar__scaledWtmScales : Point3List;
                           var animchar__scaledWtmRecalc : BoolList)
      clear(animchar__scaledWtmNodeIds)
      clear(animchar__scaledWtmScales)
      clear(animchar__scaledWtmRecalc)

  for it in slots
    let slot = it.key
    let item = (it.value as Object)?.item ?? INVALID_ENTITY_ID
    if !!item
      query(item) <| $ [es] (equipment__scaleAttaches : Object)
        for hideIt in equipment__scaleAttaches
          let affectSlotId = hideIt.key
          if slot == affectSlotId
            logerr("slot can't affect himself")
          let hideData = hideIt.value as Object
          if hideData != null
            let affectSlot = slots[string(affectSlotId)] ?as Object
            let affectEid = affectSlot?.item ?? INVALID_ENTITY_ID
            query(affectEid) <| $ [es] (animchar : AnimcharBaseComponent;
                                        var animchar__scaledWtmNodeIds : IntList;
                                        var animchar__scaledWtmScales : Point3List;
                                        var animchar__scaledWtmRecalc : BoolList)
              for node in *hideData
                let nodeName = node.key
                let hideNodeData = node.value as Object
                if hideNodeData != null
                  let intNodeNo = geomtree_findNodeIndex(*animchar.nodeTree, string(nodeName))
                  if intNodeNo < 0
                    return
                  let idx = find_index(animchar__scaledWtmNodeIds, intNodeNo)
                  if idx >= 0
                    let scale = (*hideNodeData).scale ?as float3
                    if scale != null
                      animchar__scaledWtmScales[idx].x = min(animchar__scaledWtmScales[idx].x, (*scale).x)
                      animchar__scaledWtmScales[idx].y = min(animchar__scaledWtmScales[idx].y, (*scale).y)
                      animchar__scaledWtmScales[idx].z = min(animchar__scaledWtmScales[idx].z, (*scale).z)
                    animchar__scaledWtmRecalc[idx] = (*hideNodeData)["recalc"] ?? false
                  else
                    animchar__scaledWtmNodeIds |> push(intNodeNo)
                    animchar__scaledWtmScales |> push((*hideNodeData)["scale"] ?? float3(1., 1., 1))
                    animchar__scaledWtmRecalc |> push((*hideNodeData)["recalc"] ?? false)
