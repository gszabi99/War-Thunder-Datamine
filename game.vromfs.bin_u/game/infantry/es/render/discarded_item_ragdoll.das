require ecs
require ecs.common
require math
require math.base
require app
require AppTime
require AnimV20
require PhysDecl
require Dacoll
require DagorMath
require DngHuman

require %game.events
require %appGame.wt_events
require %appGame.infantry.es.inventory_drop_common


let DISCARDED_ITEM_RI_CACHE_TTL = 10.
let DISCARDED_ITEM_THROW_FWD_SPEED = 3.5
let DISCARDED_ITEM_THROW_UP_SPEED = 1.2
let DISCARDED_ITEM_CLEANUP_TIME = 60.
let DISCARDED_ITEM_REQUEST_TIMEOUT = 2.


def update_ri_cache_for_throw(box : BBox3)
  let curRiDestrTtl = dacoll_exchange_ttl_for_collision_instances(DISCARDED_ITEM_RI_CACHE_TTL)
  update_ri_cache_in_volume_to_phys_world(box)
  dacoll_exchange_ttl_for_collision_instances(curRiDestrTtl)





[es(tag=render, on_disappear)]
def discarded_item_spawn_thrown_copy_es(evt : Event;
                                        eid aka gun_eid : EntityId;
                                        gun__discardRequestedAtTime : float;
                                        gun__owner : EntityId;
                                        animchar : AnimcharBaseComponent;
                                        animchar__res : string)
  if gun__discardRequestedAtTime < 0. || get_sync_time() - gun__discardRequestedAtTime > DISCARDED_ITEM_REQUEST_TIMEOUT
    return
  
  
  var ownerCanDrop = false
  var throwVel = float3(0., 0., 0.)
  query(gun__owner) <| $ [es] (transform aka owner_transform : float3x4;
                               human_net_phys : HumanActor;
                               isAlive : bool = true;
                               isDowned : bool = false;
                               isInVehicle : bool = false;
                               human__controlledDrone : EntityId = INVALID_ENTITY_ID)
    ownerCanDrop = isAlive && !isDowned && !isInVehicle && !human__controlledDrone
    throwVel = (human_net_phys.phys.currentState.velocity +
                owner_transform[0] * DISCARDED_ITEM_THROW_FWD_SPEED + float3(0., DISCARDED_ITEM_THROW_UP_SPEED, 0.))
  if !ownerCanDrop
    return
  var throwTm = IDENT_TM
  animchar |> animchar_get_tm(throwTm)
  createEntity("discarded_item_thrown") <| $(var init : ComponentsInitializer)
    set(init, "transform", throwTm)
    set(init, "animchar__res", animchar__res)
    set(init, "discarded_item_ragdoll__throwVel", throwVel)
    set(init, "entity_destroyer__destroyAtTime", get_sync_time() + DISCARDED_ITEM_CLEANUP_TIME)
  
  sendEventImmediate(gun__owner, EventOnLootDrop(itemEid = gun_eid))




[es(tag=render, on_appear, REQUIRE=discardedItem)]
def discarded_item_throw_ragdoll_es(evt : Event;
                                    var transform : float3x4&;
                                    discarded_item_ragdoll__throwVel : float3;
                                    var discarded_item_ragdoll__bodyToRoot : float3x4&;
                                    var ragdoll : PhysRagdoll?;
                                    var animchar : AnimcharBaseComponent;
                                    var animchar_node_wtm : AnimcharNodesMat44;
                                    var animchar_render__root_pos : vec4f&)
  animchar_set_tm(animchar, transform, true)
  animchar |> animchar_act(0., true)

  *ragdoll |> ragdoll_setOverrideVel(discarded_item_ragdoll__throwVel)
  
  let interactMask = PhysLayer.EPL_ALL & ~PhysLayer.EPL_CHARACTER
  *ragdoll |> ragdoll_startRagdoll(int(PhysLayer.EPL_CHARACTER), int(interactMask), animchar.nodeTree)
  
  
  var physSys = ragdoll_getPhysSys(*ragdoll)
  if physSys == null
    drop_item_on_ground(transform)
    animchar_set_tm(animchar, transform, true)
    animchar |> animchar_act(0., true)
    
    animchar |> animchar_copy_nodes(animchar_node_wtm, animchar_render__root_pos)
    return

  let throwPos = transform[3]
  let cacheHalf = float3(4., 2.5, 4.)
  update_ri_cache_for_throw(BBox3(throwPos - cacheHalf, throwPos + cacheHalf))

  
  
  var physBody = phys_system_instance_getBody(*physSys, 0)
  if physBody != null
    var bodyTm : float3x4
    phys_body_getTm(*physBody, bodyTm)
    var rootTm = IDENT_TM
    animchar |> animchar_get_tm(rootTm)
    discarded_item_ragdoll__bodyToRoot = inverse(bodyTm) * rootTm




[es(tag=render, after=before_animchar_update_sync, before=after_animchar_update_sync, REQUIRE=discardedItem)]
def discarded_item_ragdoll_update_es(info : ParallelUpdateFrameDelayed;
                                     discarded_item_ragdoll__bodyToRoot : float3x4;
                                     var discarded_item_ragdoll__riCacheLastUpdatePos : float3&;
                                     var discarded_item_ragdoll__nextUpdateCacheTime : float&;
                                     var ragdoll : PhysRagdoll?;
                                     var animchar : AnimcharBaseComponent;
                                     var animchar_node_wtm : AnimcharNodesMat44;
                                     var animchar_render__root_pos : vec4f&)
  
  var physSys = ragdoll_getPhysSys(*ragdoll)
  if physSys == null
    return
  var physBody = phys_system_instance_getBody(*physSys, 0)
  if physBody != null
    var bodyTm : float3x4
    phys_body_getTm(*physBody, bodyTm)
    
    if (distance_sq(discarded_item_ragdoll__riCacheLastUpdatePos, bodyTm[3]) > 0.25 ||
        discarded_item_ragdoll__nextUpdateCacheTime < info.curTime)
      let cacheHalf = float3(0.5, 0.5, 0.5)
      update_ri_cache_for_throw(BBox3(bodyTm[3] - cacheHalf, bodyTm[3] + cacheHalf))
      discarded_item_ragdoll__riCacheLastUpdatePos = bodyTm[3]
      discarded_item_ragdoll__nextUpdateCacheTime = info.curTime + (DISCARDED_ITEM_RI_CACHE_TTL - 1.)
    animchar_set_tm(animchar, bodyTm * discarded_item_ragdoll__bodyToRoot, true)
  animchar |> animchar_act(info.dt, true)
  animchar |> animchar_copy_nodes(animchar_node_wtm, animchar_render__root_pos)
