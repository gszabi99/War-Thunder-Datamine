require ecs
require ecs.common
require AnimV20
require MotionMatching
require %game.events
require %appGame.infantry.es.vehicle.vehicle_seats_common


let SEAT_ANIM_SNAP_ACT_TIME = 0.2f

def private snap_mm_and_camera(human_eid : EntityId)
  
  
  query(human_eid) <| $ [es] (var motion_matching__controller : MotionMatchingController)
    motion_matching__controller |> updateNodeWeights(false, 1.f, 100.f)
  
  query(human_eid) <| $ [es] (var human_cam__offsetMult : float&;
                              isInVehicle : bool = false)
    human_cam__offsetMult = isInVehicle ? 0.f : 1.f

def private try_snap_seat_anim(human_eid : EntityId)
  query(human_eid) <| $ [es] (var animchar : AnimcharBaseComponent;
                              isInVehicle : bool;
                              human_anim__vehicleSelected : EntityId;
                              human_vehicle_anim__upperId : int;
                              human_vehicle_anim__lowerId : int;
                              human_vehicle_anim__fireReadyUpperId : int = -1;
                              human_vehicle_anim__fireReadyLowerId : int = -1;
                              human_vehicle__isHoldingGunPassenger : bool = false;
                              animchar__animSpeed : float = 0.f)
    if !isInVehicle || human_anim__vehicleSelected == INVALID_ENTITY_ID
      return
    var animGraph = animchar.animGraph
    if animGraph == null
      return
    let holdingGun = human_vehicle__isHoldingGunPassenger
    var upperId = (holdingGun && human_vehicle_anim__fireReadyUpperId >= 0) ? human_vehicle_anim__fireReadyUpperId : human_vehicle_anim__upperId
    var lowerId = (holdingGun && human_vehicle_anim__fireReadyLowerId >= 0) ? human_vehicle_anim__fireReadyLowerId : human_vehicle_anim__lowerId
    if upperId < 0 || lowerId < 0
      
      query(human_anim__vehicleSelected) <| $ [es] (vehicle_seats__seatEids : EidList)
        let seatEid = find_seat_eid_with_owner(human_eid, vehicle_seats__seatEids)
        query(seatEid) <| $ [es] (seat_anim__upper : string;
                                  seat_anim__lower : string)
          upperId = *animGraph |> anim_graph_getStateIdx(seat_anim__upper)
          lowerId = *animGraph |> anim_graph_getStateIdx(seat_anim__lower)
    if upperId < 0 || lowerId < 0
      return
    *animGraph |> anim_graph_enqueueState(*animchar.animState, upperId, -1.f, animchar__animSpeed)
    *animGraph |> anim_graph_enqueueState(*animchar.animState, lowerId, -1.f, animchar__animSpeed)
    animchar |> animchar_act(SEAT_ANIM_SNAP_ACT_TIME, true)
  snap_mm_and_camera(human_eid)

[es(tag=gameClient, track=isInVehicle, REQUIRE=human_vehicle_anim__upperId)]
def human_seat_anim_snap_es(evt : Event;
                            eid : EntityId;
                            isInVehicle : bool)
  if isInVehicle
    try_snap_seat_anim(eid)


[es(tag=gameClient, track=seat__ownerEid, REQUIRE=seat_anim__upper)]
def seat_owner_anim_snap_es(evt : Event;
                            seat__ownerEid : EntityId)
  if seat__ownerEid != INVALID_ENTITY_ID
    try_snap_seat_anim(seat__ownerEid)



[es(tag=gameClient, after=anim_state_es, REQUIRE=human_vehicle_anim__upperId)]
def human_seat_anim_snap_exit_es(info : ParallelUpdateFrameDelayed;
                                 eid : EntityId;
                                 isInVehicle : bool;
                                 var human_vehicle_anim__prevIsInVehicle : bool&;
                                 var animchar : AnimcharBaseComponent)
  if isInVehicle == human_vehicle_anim__prevIsInVehicle
    return
  human_vehicle_anim__prevIsInVehicle = isInVehicle
  if isInVehicle
    return
  animchar |> animchar_act(SEAT_ANIM_SNAP_ACT_TIME, true)
  snap_mm_and_camera(eid)
