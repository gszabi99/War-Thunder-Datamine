require ecs
require AnimV20
require DngHuman
require DaWeapons
require GeomNodeTree
require math
require %appGame.infantry.es.human_weap_common
require %game.events

def human_aim_tm_common(info : ParallelUpdateFrameDelayed;
                        eid : EntityId;
                        human_weap__currentGunEid : EntityId;
                        transform : float3x4;
                        human_attached_gun__attachedGunEid : EntityId;
                        human_net_phys : HumanActor;
                        human_use_object__nodeId : int;
                        animchar : AnimcharBaseComponent;
                        var human__aimTm : float3x4)
  var gunEid : EntityId
  if human_attached_gun__attachedGunEid != INVALID_ENTITY_ID
    gunEid = human_attached_gun__attachedGunEid
  elif human_weap__currentGunEid != INVALID_ENTITY_ID
    gunEid = human_weap__currentGunEid

  var gunPtr : Gun const?
  query(gunEid) <| $ [es] (gun : Gun const?)
    gunPtr = gun

  let spectated = eid |> has("watchedByPlr") && !(eid |> has("hero"))
  if spectated || gunPtr == null || !is_human_allowed_shooting(eid, human_attached_gun__attachedGunEid, human_net_phys)
    
    if human_use_object__nodeId >= 0
      human__aimTm[0] = human_net_phys.phys.currentState.gunDir
      human__aimTm[1] = normalize(cross(transform[2], human_net_phys.phys.currentState.gunDir))
      human__aimTm[2] = transform[2]
      human__aimTm[3] = geomtree_getNodeWpos(*animchar.nodeTree, human_use_object__nodeId)
    else
      human__aimTm = transform
  else
    human__aimTm = lerpGunTm(*gunPtr, get_phys_interp_time(human_net_phys.phys, info.curTime))

[es(tag=gameClient, before=camera_set_sync, after=(human_weap_request_reload_es, animchar_es), REQUIRE=watchedByPlr)]
def human_aim_tm_es(info : ParallelUpdateFrameDelayed;
                    eid : EntityId;
                    human_weap__currentGunEid : EntityId;
                    transform : float3x4;
                    human_attached_gun__attachedGunEid : EntityId;
                    human_net_phys : HumanActor;
                    human_use_object__nodeId : int;
                    animchar : AnimcharBaseComponent;
                    var human__aimTm : float3x4)

  human_aim_tm_common(info, eid, human_weap__currentGunEid, transform, human_attached_gun__attachedGunEid,
                      human_net_phys, human_use_object__nodeId, animchar, human__aimTm)

[es(tag=server, before=camera_set_sync, after=(human_weap_request_reload_es, animchar_es), REQUIRE_NOT=(deadEntity, watchedByPlr))]
def human_aim_tm_server_es(info : ParallelUpdateFrameDelayed;
                           eid : EntityId;
                           human_weap__currentGunEid : EntityId;
                           transform : float3x4;
                           human_attached_gun__attachedGunEid : EntityId;
                           human_net_phys : HumanActor;
                           human_use_object__nodeId : int;
                           animchar : AnimcharBaseComponent;
                           var human__aimTm : float3x4)

  human_aim_tm_common(info, eid, human_weap__currentGunEid, transform, human_attached_gun__attachedGunEid,
                      human_net_phys, human_use_object__nodeId, animchar, human__aimTm)
