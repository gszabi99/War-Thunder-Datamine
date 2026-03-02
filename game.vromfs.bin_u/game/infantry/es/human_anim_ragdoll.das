require ecs
require PhysDecl
require DagorMath
require Dacoll
require AnimV20
require %game.events

let RAGDOLL_COLLISION_INSTANCES_TTL = 10.

def start_ragdoll(var ragdoll__nextUpdateCacheTime : float&;
                  var ragdoll__riCacheLastUpdatePos : float3&;
                  var ragdoll : PhysRagdoll;
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
  ragdoll__riCacheLastUpdatePos = unitTm[3]
  dacoll_set_ttl_for_collision_instances(curRiDestrTtl)
  ragdoll__nextUpdateCacheTime  = curTime + (RAGDOLL_COLLISION_INSTANCES_TTL - 1.f)
  
  
  
  
  
  
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

[es(tag=render, REQUIRE=deadEntity)]
def update_ri_cache_around_ragdoll(info : ParallelUpdateFrameDelayed;
                                   animchar__updatable : bool;
                                   var ragdoll__riCacheLastUpdatePos : float3&;
                                   var ragdoll : PhysRagdoll&;
                                   var ragdoll__nextUpdateCacheTime : float&)
  if !animchar__updatable
    return

  var physSys = ragdoll_getPhysSys(ragdoll)
  if physSys == null
    return
  var physBody = phys_system_instance_getBody(*physSys, 0)
  if physBody == null
    return
  var tm : float3x4
  phys_body_getTm(*physBody, tm)

  if distance_sq(ragdoll__riCacheLastUpdatePos, tm[3]) > 0.25
    let boxScale = float3(0.5f)
    let box = BBox3(tm[3] - boxScale, tm[3] + boxScale)
    let curRiDestrTtl = dacoll_get_ttl_for_collision_instances()
    dacoll_set_ttl_for_collision_instances(RAGDOLL_COLLISION_INSTANCES_TTL)
    update_ri_cache_in_volume_to_phys_world(box)
    dacoll_set_ttl_for_collision_instances(curRiDestrTtl)
    ragdoll__riCacheLastUpdatePos = tm[3]
    ragdoll__nextUpdateCacheTime  = info.curTime + (RAGDOLL_COLLISION_INSTANCES_TTL - 1.f)

[es(tag=render, REQUIRE=deadEntity)]
def update_ri_cache_time_around_ragdoll(info : ParallelUpdateFrameDelayed;
                                        transform : float3x4;
                                        animchar__updatable : bool;
                                        var ragdoll__nextUpdateCacheTime : float&)
  if animchar__updatable && ragdoll__nextUpdateCacheTime < info.curTime
    let boxScale = float3(0.5f)
    let box = BBox3(transform[3] - boxScale, transform[3] + boxScale)
    let curRiDestrTtl = dacoll_get_ttl_for_collision_instances()
    dacoll_set_ttl_for_collision_instances(RAGDOLL_COLLISION_INSTANCES_TTL)
    update_ri_cache_in_volume_to_phys_world(box)
    dacoll_set_ttl_for_collision_instances(curRiDestrTtl)
    ragdoll__nextUpdateCacheTime  = info.curTime + (RAGDOLL_COLLISION_INSTANCES_TTL - 1.f)

[es(tag=render, before=human_anim_ragdoll_start_es, after=ragdoll_deactivation_es)]
def human_anim_ragdoll_es(info : ParallelUpdateFrameDelayed)
  var ragdollStarts = -1
  query() <| $ [es(REQUIRE=deadEntity)] (animchar__updatable : bool;
                                         human_net_phys__locationPos : DPoint3;
                                         transform : float3x4;
                                         eid : EntityId;
                                         ragdoll__isAllowed : bool = true;
                                         ragdoll__maxEntitiesInUpdate : int = 2;
                                         var ragdoll__nextUpdateCacheTime : float&;
                                         var ragdoll__riCacheLastUpdatePos : float3&;
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
        
        start_ragdoll(ragdoll__nextUpdateCacheTime, ragdoll__riCacheLastUpdatePos, ragdoll, ragdoll__applyParams, animchar, transform, float3(human_net_phys__locationPos), eid, curTime)
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


[es(tag=render, on_disappear, REQUIRE=(deadEntity))]
def start_animation_after_reanimation_es(evt : Event;
                                         var animchar__updatable : bool&)
  animchar__updatable = true



