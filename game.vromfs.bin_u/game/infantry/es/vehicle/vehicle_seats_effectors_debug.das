options no_aot
require ecs
require DagorSystem
require GeomNodeTree
require DagorConsole
require Unit
require %appGame.infantry.es.vehicle.vehicle_events


[es(tag=render, on_appear, track=ik_effector_name)]
def vehicle_seats_effectors_init_debug(evt : Event;
                                       ik_effector_name : string;
                                       var transform aka debug_transform : float3x4)
  query() <| $ [es(REQUIRE=heroVehicle)] (unit__ref : UnitRef;
                                          vehicle_seats__effectors : Array;
                                          vehicle_seats__seatEids : EidList;
                                          transform aka vehicle_transform : float3x4)
    if vehicle_seats__effectors.empty
      return
    let tree = get_entity_visual_node_tree(unit__ref)
    if tree == null
      return
    var vehicleRootTm : float3x4
    geomtree_getNodeWtmRelScalar(*tree, 0, vehicleRootTm)
    for seatOwnerNo, seatEid in iter_range(vehicle_seats__seatEids), vehicle_seats__seatEids
      let ownerEid = get_Eid(seatEid, "seat__ownerEid") ?? INVALID_ENTITY_ID
      query(ownerEid) <| $ [es(REQUIRE=hero)] (isInVehicle : bool;
                                               isInVehicleHidden : bool)
        if !isInVehicle || isInVehicleHidden
          return
        let effectors = get_ecs_object(vehicle_seats__effectors[seatOwnerNo])
        if effectors == null
          return
        for field in *effectors
          let effectorName = field.key
          if effectorName != ik_effector_name
            continue

          let vehicleWofs = geomtree_calc_optimal_wofs(vehicle_transform[3])
          var vehicleLocalWtm = vehicle_transform
          vehicleLocalWtm[3] = vehicle_transform[3] - vehicleWofs
          let effectorObj = get_ecs_object(*effectors, effectorName)
          if effectorObj != null
            let effectorNodeIdx = get_int(*effectorObj, "node_id") ?? -1
            geomtree_getNodeWtmScalar(*tree, effectorNodeIdx, debug_transform)
            let relTm = get_TMatrix(*effectorObj, "tm")
            if relTm != null
              debug_transform = debug_transform * (*relTm)
            debug_transform = vehicleLocalWtm * (inverse(vehicleRootTm) * debug_transform)
            let tm0 = debug_transform[0]
            debug_transform[0] = debug_transform[2]
            debug_transform[2] = tm0

[es(tag=render, on_event=ParallelUpdateFrameDelayed)]
def vehicle_seats_effectors_debug(evt : Event;
                                  transform aka debug_transform : float3x4;
                                  ik_effector_name : string;
                                  var ik_ffector__relativeTm : float3x4)
  query() <| $ [es(REQUIRE=heroVehicle)] (unit__ref : UnitRef;
                                          @shared_comp vehicle_seats__seats : Array;
                                          vehicle_seats__seatEids : EidList;
                                          var vehicle_seats__effectors : Array;
                                          transform aka vehicle_transform : float3x4)
    if vehicle_seats__seats.empty
      return
    let tree = get_entity_visual_node_tree(unit__ref)
    if tree == null
      return
    for i, seat, seatEid in iter_range(vehicle_seats__seats), vehicle_seats__seats, vehicle_seats__seatEids
      let ownerEid = get_Eid(seatEid, "seat__ownerEid") ?? INVALID_ENTITY_ID
      if !has(ownerEid, "hero") 
        continue
      let seatObj = get_ecs_object(seat)
      if seatObj == null
        continue

      var obj = getRW_ecs_object(vehicle_seats__effectors[i])
      if obj == null
        logerr("auto effectors works only with inited vehicle_seats__effectors component")
        continue

      let effectors = get_ecs_object(seatObj, "effectors")
      if effectors == null
        continue

      for field in *effectors
        if ik_effector_name == field.key
          let effObj = get_ecs_object(field.value)
          if effObj == null
            continue

          let nodeName = get_string(effObj, "node", "")
          if nodeName == ""
            logerr("incorrect node name for calculating relative matrix")

          let nodeIndex = geomtree_findNodeIndex(*tree, nodeName)

          var relNodeTm : float3x4
          var tm = debug_transform
          tm[0] = tm[2]
          tm[2] = debug_transform[0]
          geomtree_getNodeWtmScalar(*tree, nodeIndex, relNodeTm)
          relNodeTm = vehicle_transform * relNodeTm
          ik_ffector__relativeTm = inverse(relNodeTm) * tm

          using() <| $(var effector_obj : Object)
            set(effector_obj, "node_id", nodeIndex)
            set(effector_obj, "tm", ik_ffector__relativeTm)
            set(*obj, field.key, effector_obj)

[console_cmd(name="vehicle.heroPlaceSeat")]
def vehicle_place_seat(seat_id : int)
  var found = false
  query() <| $ [es(REQUIRE=hero)] (eid aka human_eid : EntityId; human_anim__vehicleSelected : EntityId)
    found = true
    sendEvent(human_anim__vehicleSelected, CmdVehiclePlaceSeat(eid = human_eid, seat = seat_id))
  if found
    return
  query() <| $ [es(REQUIRE=hero)] (eid aka vehicle_eid : EntityId)
    find_query() <| $ [es(REQUIRE=isInVehicle)] (eid aka soldier_eid : EntityId; human_anim__vehicleSelected : EntityId)
      if human_anim__vehicleSelected != vehicle_eid
        return false
      sendEvent(vehicle_eid, CmdVehiclePlaceSeat(eid = soldier_eid, seat = seat_id))
      return true
