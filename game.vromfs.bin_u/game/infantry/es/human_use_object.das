require ecs
require %appGame.infantry.es.human_use_object_common
require %appGame.infantry.es.human_attached_gun_common
require %game.events

require %appGame.wt_events
require AnimV20
require GeomNodeTree


[es(tag=server, REQUIRE=human_use_object__selectedObject, REQUIRE_NOT=deadEntity)]
def on_human_use_object_request(evt : HumanUseObjectRequest;
                                eid : EntityId;
                                transform aka user_transform : float3x4;
                                isDowned : bool = false;
                                human_use_object__thresholdDist : float = 12.f)
  if !isDowned
    human_try_use_object(eid, user_transform[3], human_use_object__thresholdDist, evt.objectEid)


[es(tag=server, REQUIRE=human_use_object__selectedObject, REQUIRE_NOT=deadEntity)]
def on_human_use_alt_object_request(evt : HumanUseAltObjectRequest;
                                    eid : EntityId;
                                    transform aka user_transform : float3x4;
                                    isDowned : bool = false;
                                    human_use_object__thresholdDist : float = 12.f)
  if !isDowned
    human_try_use_object_alt(eid, user_transform[3], human_use_object__thresholdDist, evt.objectEid)


[es(on_appear)]
def human_use_object_created_es(evt : Event;
                                animchar : AnimcharBaseComponent;
                                human_use_object__lookNodeName : string;
                                var human_use_object__nodeId : int&)
  if human_use_object__lookNodeName != ""
    human_use_object__nodeId = *animchar.nodeTree |> geomtree_findNodeIndex(human_use_object__lookNodeName)
  else
    human_use_object__nodeId = 0 


[es(REQUIRE=hero)]
def hero_human_pre_use_object_es(info : ParallelUpdateFrameDelayed;
                                 var human_use_object__selectedObject : EntityId&;
                                 var human_use_object__lookAtSelected : bool&;
                                 var human_use_object__lookAtObject : EntityId&;
                                 var customUsePrompt : das_string)
  human_use_object__selectedObject = INVALID_ENTITY_ID
  human_use_object__lookAtSelected = false
  human_use_object__lookAtObject = INVALID_ENTITY_ID
  customUsePrompt := ""


[es(REQUIRE=hero, after=hero_human_pre_use_object_es, before=hero_human_final_use_object_sync)]
def hero_human_use_current_vehicle_object_es(info : ParallelUpdateFrameDelayed;
                                             isInVehicle : bool = false;
                                             human_anim__vehicleSelected : EntityId = INVALID_ENTITY_ID;
                                             var human_use_object__selectedObject : EntityId&;
                                             var human_use_object__lookAtSelected : bool&)
  if !isInVehicle || !human_anim__vehicleSelected
    return
  human_use_object__selectedObject = human_anim__vehicleSelected
  human_use_object__lookAtSelected = true


[es(REQUIRE=hero, after=(hero_human_use_current_vehicle_object_es, hero_human_pre_use_object_es), before=hero_human_final_use_object_sync)]
def hero_human_use_stationary_gun_object_es(info : ParallelUpdateFrameDelayed;
                                            eid : EntityId;
                                            human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                                            human_use_object__lockStationaryGunUse : bool = false;
                                            var human_use_object__selectedObject : EntityId&)
  if human_use_object__selectedObject != INVALID_ENTITY_ID
    return
  let gunEid = find_gun_to_attach(eid, 2.0, false)
  if gunEid != INVALID_ENTITY_ID
    if !human_use_object__lockStationaryGunUse
      human_use_object__selectedObject = gunEid
  elif human_attached_gun__attachedGunEid != INVALID_ENTITY_ID
    human_use_object__selectedObject = human_attached_gun__attachedGunEid
