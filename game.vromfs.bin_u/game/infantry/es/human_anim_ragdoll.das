require ecs
require PhysDecl
require DagorMath
require Dacoll
require AnimV20
require %game.events

let RAGDOLL_COLLISION_INSTANCES_TTL = 10.

def start_ragdoll(var ragdoll : PhysRagdoll;
                  var ragdoll__applyParams : bool&;
                  var animchar : AnimcharBaseComponent;
                  unitTm : float3x4;
                  pos : float3;
                  eid : EntityId;
                  curTime : float)
  animchar |> animchar_resetPostController()

  let boxScale = float3(0.5f)
  let box = BBox3(unitTm[3] - boxScale, unitTm[3] + boxScale)
  let curRiDestrTtl = dacoll_get_ttl_for_collision_instances()
  dacoll_set_ttl_for_collision_instances(RAGDOLL_COLLISION_INSTANCES_TTL)
  update_ri_cache_in_volume_to_phys_world(box)
  dacoll_set_ttl_for_collision_instances(curRiDestrTtl)
  
  
  
  
  
  
  animchar |> animchar_set_tm(pos, unitTm[0], unitTm[1])
  
  animchar |> animchar_recalc_wtm()
  ragdoll__applyParams = true
  sendEvent(eid, CmdApplyRagdollParameters(cur_time = curTime))
  animchar |> animchar_setPostController(ragdoll)

def stop_ragdoll(var ragdoll : PhysRagdoll;
                 var animchar : AnimcharBaseComponent)
  ragdoll |> ragdoll_endRagdoll()
  animchar |> animchar_resetPostController()

[es(tag=render, REQUIRE=deadEntity, after=human_anim_ragdoll_es, before=ragdoll_start_es)]
def human_anim_ragdoll_start_es(info : ParallelUpdateFrameDelayed;
                                var animchar : AnimcharBaseComponent;
                                var ragdoll : PhysRagdoll;
                                human_vehicle__occupiedSeatEid : EntityId = INVALID_ENTITY_ID;
                                ragdoll__applyParams : bool;
                                human_net_phys__locationPos : DPoint3;
                                human_net_phys__velocity : float3;
                                human_anim__dynamicRagdollClipoutTimeout : float = 0.4;
                                human_anim__dynamicRagdollClipoutOffset : float3 = float3(0., 0.5, 0.))
  if !ragdoll__applyParams
    return
  let pos = float3(human_net_phys__locationPos)
  let vel = human_net_phys__velocity
  if (human_anim__dynamicRagdollClipoutTimeout > 0.0f)
    let toPos = pos + human_anim__dynamicRagdollClipoutOffset
    ragdoll |> ragdoll_setDynamicClipout(toPos, human_anim__dynamicRagdollClipoutTimeout)
  ragdoll |> ragdoll_setOverrideVel(vel)
  let mask = PhysLayer.EPL_ALL
  let extraMask = (~(PhysLayer.EPL_KINEMATIC | PhysLayer.EPL_CHARACTER))
  let interactMask = !!human_vehicle__occupiedSeatEid ? mask & extraMask : mask
  ragdoll |> ragdoll_startRagdoll(int(PhysLayer.EPL_CHARACTER),
                                  int(interactMask),
                                  animchar.nodeTree)


[es(tag=render, before=human_anim_ragdoll_start_es, after=ragdoll_deactivation_es)]
def human_anim_ragdoll_es(info : ParallelUpdateFrameDelayed)
  var ragdollStarts = -1
  query() <| $ [es(REQUIRE=deadEntity)] (animchar__updatable : bool;
                                         human_net_phys__locationPos : DPoint3;
                                         transform : float3x4;
                                         eid : EntityId;
                                         ragdoll__isAllowed : bool = true;
                                         ragdoll__maxEntitiesInUpdate : int = 2;
                                         var ragdoll__applyParams : bool&;
                                         var human_anim__ragdollEnabled : bool&;
                                         var ragdoll : PhysRagdoll;
                                         var animchar : AnimcharBaseComponent)
    if !animchar__updatable
      return

    let shouldDoRagdoll = ragdoll__isAllowed
    if shouldDoRagdoll != human_anim__ragdollEnabled
      if shouldDoRagdoll
        if ragdollStarts < 0 && ragdoll__maxEntitiesInUpdate > 0
          ragdollStarts = ragdoll__maxEntitiesInUpdate

        if ragdollStarts == 0
          return

        human_anim__ragdollEnabled = true
        let curTime = info.curTime
        
        start_ragdoll(ragdoll, ragdoll__applyParams, animchar, transform, float3(human_net_phys__locationPos), eid, curTime)
        ragdollStarts--
      else
        human_anim__ragdollEnabled = false
        stop_ragdoll(ragdoll, animchar)


[es(tag=render, REQUIRE=deadEntity, on_event=(EventComponentsDisappear))]
def stop_ragdoll_es(event : Event;
                    var animchar : AnimcharBaseComponent;
                    var human_anim__ragdollEnabled : bool&;
                    var ragdoll : PhysRagdoll)
  if human_anim__ragdollEnabled
    human_anim__ragdollEnabled = false
    stop_ragdoll(ragdoll, animchar)




