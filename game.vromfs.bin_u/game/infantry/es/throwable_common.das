module throwable_common shared
require app
require ecs
require ecs.extra_set
require net
require DngHuman
require DagorMath

require %appGame.wt_events


enum ThrowableLauncherLocalItemReplaceMode
  TLLIRM_INSTANT
  TLLIRM_LERP

enum ThrowableLauncherThrowMode
  TLTM_DELAYED
  TLTM_DIRECT

def throwable_launcher_start_throw(owner_eid : EntityId;
                                   throwable_launcher_eid : EntityId;
                                   throwable_launcher_throw__template : string;
                                   throwable_launcher_throw__createItemInAdvance : bool;
                                   throwable_launcher_throw__throwTime : float;
                                   throwable_launcher_throw__collisionWithOwnerDelay : float;
                                   throwable_launcher_anim__throwTime : float;
                                   var throwable_launcher__inProgress : bool&;
                                   var throwable_launcher_throw__item : EntityId&;
                                   var throwable_launcher_throw__itemThrowed : bool&;
                                   var throwable_launcher_throw__startAtTime : float&;
                                   var throwable_launcher_anim__throwInProgress : bool&;
                                   var throwable_launcher_anim__throwStart : float&;
                                   var throwable_launcher_anim__throwEnd : float&;
                                   is_local : bool;
                                   at_tiem : float;
                                   current_time : float)
  throwable_launcher__inProgress = true
  throwable_launcher_throw__startAtTime = at_tiem
  throwable_launcher_throw__itemThrowed = false
  throwable_launcher_anim__throwInProgress = true
  throwable_launcher_anim__throwStart = at_tiem
  throwable_launcher_anim__throwEnd = at_tiem + throwable_launcher_anim__throwTime

  if !throwable_launcher_throw__createItemInAdvance
    throwable_launcher_throw__item = INVALID_ENTITY_ID
  else
    query(owner_eid) <| $ [es] (human_net_phys : HumanActor)
      let throwAtTime = at_tiem + throwable_launcher_throw__throwTime
      let throwableItemTM = get_throwable_item_transform_relative_to_human(human_net_phys)
      throwable_launcher_throw__item = create_throwable_item(owner_eid, throwable_launcher_eid, throwable_launcher_throw__template, is_local, true, throwableItemTM,
                                                             current_time, throwAtTime, throwable_launcher_throw__collisionWithOwnerDelay)

def get_throwable_item_transform_relative_to_human(human_net_phys : HumanActor;
                                                   var position_offset : float3 = float3(0.0, 0.0, 0.0);
                                                   var direction : float3 = float3(0.0, 0.0, 0.0))
  var throwableItemTM : float3x4
  human_net_phys.phys.currentState.location |> location_toTM(throwableItemTM)
  if length_sq(direction) <= 0.0
    direction = human_net_phys.phys.appliedCT.wishLookDir
  let dirQuat = dir_to_quat(direction)
  if length_sq(position_offset) > 0.0
    position_offset = dirQuat * position_offset

  make_tm(dirQuat, throwableItemTM[3] + position_offset, throwableItemTM)
  return throwableItemTM

def create_throwable_item(owner_eid : EntityId;
                          throwable_launcher_eid : EntityId;
                          throwable_template : string;
                          is_local : bool;
                          in_advance : bool;
                          transform : float3x4;
                          current_time : float;
                          throw_at_time : float;
                          var collision_with_owner_delay : float;
                          velocity : float3 = float3(0.0);
                          omega : float3 = float3(0.0))
  let generalTemplate = "throwable_item+" + (is_local ? "client_side" : "replicating")
  if in_advance
    collision_with_owner_delay += throw_at_time - current_time

  return createEntity("{throwable_template}+{generalTemplate}") <| $(var init)
    set(init, "transform", transform)
    set(init, "throwable_item__owner", owner_eid)
    set(init, "throwable_item__launcher", throwable_launcher_eid)
    set(init, "throwable_item__throwAtTime", throw_at_time)
    set(init, "shell__launchAtTime", throw_at_time)
    set(init, "throwable_item__throwed", !in_advance)

    if collision_with_owner_delay > 0.0
      set(init, "ignoreObjs__time", collision_with_owner_delay)
      set(init, "ignoreObjs__eids", [ owner_eid])

    if !in_advance
      set(init, "start_vel", velocity)
      set(init, "start_omega", omega)

def throwable_launcher_request_throw(owner_eid : EntityId;
                                     throwable_launcher_eid : EntityId;
                                     at_time : float)
  query(throwable_launcher_eid) <| $ [es] (throwable_launcher_throw__localTemplate : string;
                                           throwable_launcher_throw__createLocalItemInAdvance : bool;
                                           throwable_launcher_throw__useLocalItem : bool;
                                           throwable_launcher_throw__throwTime : float;
                                           throwable_launcher_throw__collisionWithOwnerDelay : float;
                                           throwable_launcher_anim__throwTime : float;
                                           var throwable_launcher__inProgress : bool&;
                                           var throwable_launcher_throw__localItem : EntityId&;
                                           var throwable_launcher_throw__localItemThrowed : bool&;
                                           var throwable_launcher_throw__startAtTime : float&;
                                           var throwable_launcher_anim__throwInProgress : bool&;
                                           var throwable_launcher_anim__throwStart : float&;
                                           var throwable_launcher_anim__throwEnd : float&)
    send_net_event(owner_eid, RequestThrowableLauncherStartThrow(throwableLauncherEid = throwable_launcher_eid, atTime = at_time))
    if is_server() || !throwable_launcher_throw__useLocalItem
      throwable_launcher_throw__localItemThrowed = false
      return

    throwable_launcher_start_throw(owner_eid,
                                   throwable_launcher_eid,
                                   throwable_launcher_throw__localTemplate,
                                   throwable_launcher_throw__createLocalItemInAdvance,
                                   throwable_launcher_throw__throwTime,
                                   throwable_launcher_throw__collisionWithOwnerDelay,
                                   throwable_launcher_anim__throwTime,
                                   throwable_launcher__inProgress,
                                   throwable_launcher_throw__localItem,
                                   throwable_launcher_throw__localItemThrowed,
                                   throwable_launcher_throw__startAtTime,
                                   throwable_launcher_anim__throwInProgress,
                                   throwable_launcher_anim__throwStart,
                                   throwable_launcher_anim__throwEnd,
                                   true,
                                   at_time,
                                   get_sync_time())
