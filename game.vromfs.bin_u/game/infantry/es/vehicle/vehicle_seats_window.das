require ecs
require ecs.safe
require ecs.common
require math.base
require DagorMath
require DagorSystem
require GeomNodeTree
require Unit
require WTDamageModel







def private calc_parent_model_tm(tree : GeomNodeTree; node_id : int; var out_tm : float3x4&)
  out_tm = IDENT_TM
  var idx = geomtree_getParentNodeIdx(tree, node_id)
  while idx >= 0
    var localTm : float3x4
    geomtree_getNodeTmScalar(tree, idx, localTm)
    out_tm = localTm * out_tm
    idx = geomtree_getParentNodeIdx(tree, idx)

[es(no_order)]
def vehicle_seats_window_es(info : UpdateStageInfoAct;
                            seat__id : int;
                            seat__vehicleEid : EntityId;
                            seat__ownerEid : EntityId;
                            var seat_window__inited : bool&;
                            var seat_window__isValid : bool&;
                            var seat_window__openPos : float&;
                            var seat_window__slideDist : float&;
                            seat_window__openVel : float;
                            var seat_window__nodeIds : IntList;
                            var seat_window__baseLocalPos : Point3List;
                            var seat_window__slideDirLocal : Point3List)
  if seat_window__inited && !seat_window__isValid
    return

  
  if !seat_window__inited
    query(seat__vehicleEid) <| $ [es] (@shared_comp vehicle_seats__seats : Array;
                                       unit__ref : UnitRef)
      let tree = get_entity_visual_node_tree(unit__ref)
      if tree == null
        return
      seat_window__inited = true
      let seat = get_ecs_object(vehicle_seats__seats, seat__id)
      if seat == null
        return
      let windowNodes = get_ecs_array(*seat, "windowNodes")
      if windowNodes == null
        return
      seat_window__slideDist = get_float(*seat, "windowSlideDist") ?? seat_window__slideDist
      for nodeNo in iter_range(*windowNodes)
        let nodeName = get_string((*windowNodes)[nodeNo], "")
        let nodeId = geomtree_findNodeIndex(*tree, nodeName)
        if nodeId < 0
          logerr("vehicle_seats_window: node '{nodeName}' not found in '{getEntityTemplateName(seat__vehicleEid)}'")
          continue
        var nodeTm : float3x4
        geomtree_getNodeTmScalar(*tree, nodeId, nodeTm)
        var parentModelTm : float3x4
        calc_parent_model_tm(*tree, nodeId, parentModelTm)
        seat_window__nodeIds |> push(nodeId)
        seat_window__baseLocalPos |> push(nodeTm[3])
        seat_window__slideDirLocal |> push(normalize(rotate(inverse(parentModelTm), float3(0.0f, -1.0f, 0.0f))))
      seat_window__isValid = length(seat_window__nodeIds) > 0
    if !seat_window__isValid
      return

  var isOpen = false
  query(seat__ownerEid) <| $ [es] (human_vehicle__isHoldingGunPassenger : bool = false;
                                   isAlive : bool = false)
    isOpen = human_vehicle__isHoldingGunPassenger && isAlive

  let target = isOpen ? 1.0f : 0.0f
  if seat_window__openPos == target
    return
  seat_window__openPos = clamp(seat_window__openPos + (isOpen ? 1.0f : -1.0f) * seat_window__openVel * info.dt, 0.0f, 1.0f)

  query(seat__vehicleEid) <| $ [es] (var unit__ref : UnitRef)
    var unit = unit__ref.unit
    if unit == null || unit.visual == null
      return
    let tree = get_entity_visual_node_tree(unit__ref)
    if tree == null
      return
    for nodeId, basePos, slideDir in seat_window__nodeIds, seat_window__baseLocalPos, seat_window__slideDirLocal
      var nodeTm : float3x4
      geomtree_getNodeTmScalar(*tree, nodeId, nodeTm)
      nodeTm[3] = basePos + slideDir * (seat_window__slideDist * seat_window__openPos)
      *unit.visual |> dvm_set_visual_node_tm(nodeId, nodeTm)
