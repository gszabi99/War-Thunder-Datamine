require ecs
require app
require %game.events

require %appGame.wt_events
require %appGame.infantry.es.door_operations_common
require %appGame.infantry.es.riextra_damage_common
require RendInst
require math.base
require math.ang

[es]
def door_operations(evt : CmdUse;
                    eid : EntityId;
                    door_operations__reqState : int;
                    pair_door__eid : EntityId;
                    transform aka door_transform : float3x4;
                    initialTransform aka door_initialTransform : float3x4)
  query(evt.requesterEid) <| $ [es] (transform aka opener_transform : float3x4)
    cmd_use_door(eid, evt.requesterEid, pair_door__eid,
                 get_door_main_action(door_operations__reqState, door_transform, door_initialTransform, opener_transform[3]),
                 true)

[es]
def door_operations_alt(evt : CmdUseAlt;
                        eid : EntityId;
                        door_operations__reqState : int;
                        pair_door__eid : EntityId)
  cmd_use_door(eid, evt.requesterEid, pair_door__eid,
               get_door_alt_action(door_operations__reqState),
               true)

def door_set_lock(doorEid : EntityId)
  query(doorEid) <| $ [es] (var door__isLocked : bool&)
    door__isLocked = true

def door_set_locking(doorEid : EntityId)
  query(doorEid) <| $ [es] (var door__isLocking : bool&)
    door__isLocking = true

def door_unset_locking(doorEid : EntityId)
  query(doorEid) <| $ [es] (var door__isLocking : bool&)
    door__isLocking = false

def locking_door_reset_timers(var human_locking_door__actionStartTime, human_locking_door__actionEndTime : float&)
  human_locking_door__actionStartTime = -1.0
  human_locking_door__actionEndTime = -1.0

def door_set_breaking(doorEid : EntityId)
  query(doorEid) <| $ [es] (var door__isBreaking : bool&)
    door__isBreaking = true

def door_unset_breaking(doorEid : EntityId)
  query(doorEid) <| $ [es] (var door__isBreaking : bool&)
    door__isBreaking = false

def breaking_door_reset_timers(var human_breaking_door__actionStartTime, human_breaking_door__actionEndTime : float&)
  human_breaking_door__actionStartTime = -1.0
  human_breaking_door__actionEndTime = -1.0

[es(tag=server)]
def locking_door_on_start(evt : CmdStartLockingDoor;
                          human_locking_door__actionDuration : float;
                          var human_locking_door__actionStartTime : float&;
                          var human_locking_door__actionEndTime : float&;
                          var human_locking_door__eid : EntityId&)

  let isLocked = get_bool(evt.doorEid, "door__isLocked") ?? false
  if isLocked
    return
  human_locking_door__eid = evt.doorEid
  human_locking_door__actionStartTime = get_sync_time()
  human_locking_door__actionEndTime = human_locking_door__actionStartTime + human_locking_door__actionDuration

[es(tag=server)]
def breaking_down_door_on_start(evt : CmdStartBreakingDoor;
                                human_breaking_door__actionDuration : float;
                                var human_breaking_door__actionStartTime : float&;
                                var human_breaking_door__actionEndTime : float&;
                                var human_breaking_door__eid : EntityId&)
  human_breaking_door__eid = evt.doorEid
  human_breaking_door__actionStartTime = get_sync_time()
  human_breaking_door__actionEndTime = human_breaking_door__actionStartTime + human_breaking_door__actionDuration

[es(tag=server, no_order)]
def breaking_down_door_on_update(info : ParallelUpdateFrameDelayed;
                                 eid : EntityId;
                                 human__aimTm : float3x4;
                                 human_use_object__useDist : float;
                                 human_breaking_door__power : float = 5f;
                                 human_breaking_door__damage : float = 1000f;
                                 var human_breaking_door__eid : EntityId&;
                                 var human_breaking_door__actionStartTime : float&;
                                 var human_breaking_door__actionEndTime : float&)
  if human_breaking_door__actionStartTime < 0.0
    return

  var doorPos = float3()
  query(human_breaking_door__eid) <| $ [es] (transform : float3x4&)
    doorPos = transform[3]
  if distance_sq(human__aimTm[3], doorPos) > square(human_use_object__useDist)
    human_breaking_door__eid = INVALID_ENTITY_ID
    breaking_door_reset_timers(human_breaking_door__actionStartTime, human_breaking_door__actionEndTime)
    return

  door_set_breaking(human_breaking_door__eid)

  if human_breaking_door__actionEndTime < info.curTime
    breaking_door_reset_timers(human_breaking_door__actionStartTime, human_breaking_door__actionEndTime)
    query(human_breaking_door__eid) <| $ [es] (ri_extra : RiExtraComponent)
      if !ri_extra.valid
        return
      let bsph = getRIGenExtraBSphere(ri_extra.handle)
      let riPos = bsph.xyz
      let lookDir = normalize(riPos - human__aimTm[3])
      damage_ri_on_server(ri_extra.handle, human_breaking_door__damage, riPos, lookDir * human_breaking_door__power, 0.f, eid)
    door_unset_breaking(human_breaking_door__eid)
    human_breaking_door__eid = INVALID_ENTITY_ID

[es(tag=server, on_event=CmdStopBreakingDoor)]
def breaking_down_on_stop(evt : Event;
                          var human_breaking_door__eid : EntityId&;
                          var human_breaking_door__actionStartTime : float&;
                          var human_breaking_door__actionEndTime : float&)
  door_unset_breaking(human_breaking_door__eid)
  human_breaking_door__eid = INVALID_ENTITY_ID
  breaking_door_reset_timers(human_breaking_door__actionStartTime, human_breaking_door__actionEndTime)

[es(tag=server, no_order)]
def locking_door_on_update(info : ParallelUpdateFrameDelayed;
                           human_locking_door__eid : EntityId;
                           human__aimTm : float3x4;
                           human_use_object__useDist : float;
                           var human_locking_door__actionStartTime : float&;
                           var human_locking_door__actionEndTime : float&)
  if human_locking_door__actionStartTime < 0.0
    return

  var doorPos = float3()
  query(human_locking_door__eid) <| $ [es] (transform : float3x4&)
    doorPos = transform[3]
  if distance_sq(human__aimTm[3], doorPos) > square(human_use_object__useDist)
    locking_door_reset_timers(human_locking_door__actionStartTime, human_locking_door__actionEndTime)
    return

  door_set_locking(human_locking_door__eid)

  if human_locking_door__actionEndTime < info.curTime
    locking_door_reset_timers(human_locking_door__actionStartTime, human_locking_door__actionEndTime)
    door_set_lock(human_locking_door__eid)
    door_unset_locking(human_locking_door__eid)

[es(tag=server, on_event=CmdStopLockingDoor)]
def locking_door_on_stop(evt : Event;
                         human_locking_door__eid : EntityId;
                         var human_locking_door__actionStartTime : float&;
                         var human_locking_door__actionEndTime : float&)
  door_unset_locking(human_locking_door__eid)
  locking_door_reset_timers(human_locking_door__actionStartTime, human_locking_door__actionEndTime)

[es(tag=gameClient, REQUIRE=watchedByPlr)]
def human_select_door_with_lock(info : ParallelUpdateFrameDelayed;
                                human_use_object__selectedObject : EntityId;
                                var human_use_object__lockDoorEid : EntityId&;
                                var human_use_object__doorIsLocked : bool&)
  human_use_object__lockDoorEid = INVALID_ENTITY_ID
  query(human_use_object__selectedObject) <| $ [es(REQUIRE=(isDoor))] (door__isLocked : bool;
                                                                       rendinst_axis_rotation__curAngle : float;
                                                                       door_operations__closedAngle : float)
    let isDoorClosed = rendinst_axis_rotation__curAngle == door_operations__closedAngle
    if isDoorClosed
      human_use_object__lockDoorEid = human_use_object__selectedObject
      human_use_object__doorIsLocked = door__isLocked


[es(tag=server, REQUIRE=isDoor)]
def restore_locked_doors_initial_state_es(evt : EventResetDoorToInitialState;
                                          var door__isLocked : bool&;
                                          var door__isLocking : bool&;
                                          var door__isBreaking : bool&)
  door__isLocked = false
  door__isLocking = false
  door__isBreaking = false

[es(tag=netClient)]
def door_client_operations(evt : HumanUseObjectRequest;
                           eid : EntityId;
                           transform aka opener_transform : float3x4)
  query(evt.objectEid) <| $ [es] (pair_door__eid : EntityId;
                                  door_operations__reqState : int;
                                  transform aka door_transform : float3x4;
                                  initialTransform aka door_initialTransform : float3x4)
    cmd_use_door(evt.objectEid, eid, pair_door__eid,
                 get_door_main_action(door_operations__reqState, door_transform, door_initialTransform, opener_transform[3]),
                 true)

[es(tag=netClient)]
def door_client_operations_alt(evt : HumanUseAltObjectRequest;
                               eid : EntityId)
  query(evt.objectEid) <| $ [es] (pair_door__eid : EntityId; door_operations__reqState : int)
    cmd_use_door(evt.objectEid, eid, pair_door__eid,
                 get_door_alt_action(door_operations__reqState),
                 true)


[es(tag=netClient, no_order)]
def door_client_prediction(info : UpdateStageInfoAct; eid : EntityId; door_client_prediction__doorEid : EntityId;
                           door_client_prediction__atTime, door_client_prediction__timeout : float)
  if info.curTime >= door_client_prediction__atTime + door_client_prediction__timeout
    query(door_client_prediction__doorEid) <| $ [es] (var rendinst_axis_rotation__targetAngle : float&; door_operations__serverTargetAngle : float)
      rendinst_axis_rotation__targetAngle = door_operations__serverTargetAngle
    destroyEntity(eid)

[es(track=door_operations__serverTargetAngle, REQUIRE_NOT=rotating_rendinst_simple_phys_processing)]
def door_operations_apply_server(evt : Event; var rendinst_axis_rotation__targetAngle : float&; door_operations__serverTargetAngle : float)
  rendinst_axis_rotation__targetAngle = door_operations__serverTargetAngle

[es(tag=server, on_appear)]
def door_operations_init_server(evt : Event; rendinst_axis_rotation__targetAngle : float; var door_operations__serverTargetAngle : float&)
  door_operations__serverTargetAngle = rendinst_axis_rotation__targetAngle


[es(tag=server, REQUIRE=rendinst_axis_rotation__enabled, on_appear)]
def door_state_by_rendinst_axis_rotation_appear_server(evt : Event;
                                                       rendinst_axis_rotation__curAngle : float;
                                                       door_operations__openedAngle : float;
                                                       door_operations__closedAngle : float;
                                                       var door_operations__state : int&)
  door_operations__state = detect_door_state_by_angle(rendinst_axis_rotation__curAngle,
                                                          door_operations__openedAngle,
                                                          door_operations__closedAngle)


[es(tag=server, REQUIRE=rendinst_axis_rotation__enabled, on_disappear)]
def door_state_by_rendinst_axis_rotation_disappear_server(evt : Event;
                                                          rendinst_axis_rotation__curAngle : float;
                                                          door_operations__openedAngle : float;
                                                          door_operations__closedAngle : float;
                                                          var door_operations__state : int&;
                                                          var door_operations__reqState : int&)
  door_operations__state = detect_door_state_by_angle(rendinst_axis_rotation__curAngle,
                                                      door_operations__openedAngle,
                                                      door_operations__closedAngle)
  door_operations__reqState = door_operations__state


[es(REQUIRE=rotating_rendinst_simple_phys_processing, on_appear)]
def door_state_on_simple_phys_rotation_started(evt : Event;
                                               rendinst_axis_rotation__curAngle : float;
                                               door_operations__openedAngle : float;
                                               door_operations__closedAngle : float;
                                               door_operations__omniRotate : bool;
                                               rotating_door_simple_phys__closeOnClosedAngleReached : bool;
                                               var rotating_rendinst_simple_phys__clampAngles : float2&)
  if door_operations__omniRotate
    let diff = abs(door_operations__closedAngle - door_operations__openedAngle)
    var ang1 = 0.0
    if rotating_door_simple_phys__closeOnClosedAngleReached
      ang1 = door_operations__closedAngle
    else
      ang1 = rendinst_axis_rotation__curAngle > door_operations__closedAngle ? door_operations__closedAngle - diff : door_operations__closedAngle + diff
    let ang2 = rendinst_axis_rotation__curAngle > door_operations__closedAngle ? door_operations__closedAngle + diff : door_operations__closedAngle - diff
    let minClampAngle = min(ang1, ang2)
    let maxClampAngle = max(ang1, ang2)
    rotating_rendinst_simple_phys__clampAngles = float2(minClampAngle, maxClampAngle)
  else
    let minClampAngle = min(door_operations__openedAngle, door_operations__closedAngle)
    let maxClampAngle = max(door_operations__openedAngle, door_operations__closedAngle)
    rotating_rendinst_simple_phys__clampAngles = float2(minClampAngle, maxClampAngle)

[es(REQUIRE=rotating_rendinst_simple_phys_processing, on_appear)]
def door_state_on_simple_phys_rotation_started_server(evt : Event;
                                                      var door_operations__state : int&;
                                                      var door_operations__reqState : int&)
  door_operations__state = int(DoorState.AJAR)
  door_operations__reqState = door_operations__state


[es(tag=server, REQUIRE=rotating_rendinst_simple_phys_processing, on_disappear)]
def door_state_on_simple_phys_rotation_finished(evt : Event;
                                                door_operations__openedAngle : float;
                                                door_operations__closedAngle : float;
                                                rendinst_axis_rotation__curAngle : float;
                                                var door_operations__state : int&;
                                                var door_operations__reqState : int&)
  door_operations__state = detect_door_state_by_angle(rendinst_axis_rotation__curAngle,
                                                      door_operations__openedAngle,
                                                      door_operations__closedAngle)
  door_operations__reqState = door_operations__state


[es(tag=server, REQUIRE=rotating_rendinst_simple_phys__angularVelocity, after=rotating_rendinst_simple_phys_update_finished)]
def sync_door_target_angles_on_simple_phys_rotation_server(evt : RotatingRendinstSimplePhysUpdateFinished;
                                                           rendinst_axis_rotation__targetAngle : float;
                                                           var door_operations__serverTargetAngle : float&)
  door_operations__serverTargetAngle = rendinst_axis_rotation__targetAngle


[es(tag=netClient, REQUIRE=rotating_rendinst_simple_phys__angularVelocity, before=rotating_rendinst_simple_phys_fixed_update)]
def sync_door_target_angles_on_simple_phys_rotation_client(evt : RotatingRendinstSimplePhysFixedUpdate;
                                                           rendinst_axis_rotation__curAngle : float;
                                                           door_operations__minDesyncAngleValue : float = 0.1;
                                                           door_operations__desyncAngleTorquPow : float = 1.5;
                                                           door_operations__desyncAngleTorqueMult : float = 0.2;
                                                           door_operations__desyncAngleTorqueMin : float = 1.0;
                                                           door_operations__serverTargetAngle : float;
                                                           var rotating_rendinst_simple_phys__torque : float&;
                                                           var rotating_rendinst_simple_phys__idleUpdate : bool&)
  let desyncAngleDelta = door_operations__serverTargetAngle - renorm_ang(rendinst_axis_rotation__curAngle * DEG_TO_RAD, door_operations__serverTargetAngle * DEG_TO_RAD)  * RAD_TO_DEG
  let desyncAngleValue = abs(desyncAngleDelta)

  if desyncAngleValue > door_operations__minDesyncAngleValue
    
    let syncTorque = pow(desyncAngleDelta, door_operations__desyncAngleTorquPow) * door_operations__desyncAngleTorqueMult
    let syncTorqueSign = sign(desyncAngleDelta)
    rotating_rendinst_simple_phys__torque += syncTorqueSign * max(door_operations__desyncAngleTorqueMin, syncTorque)
    rotating_rendinst_simple_phys__idleUpdate = false


[es(tag=server, on_appear, on_event=EventRendinstsLoaded, track=door_operations__state)]
def rotating_rendinst_simple_phys_enabled_by_door_state(evt : Event;
                                                        door_operations__state : int;
                                                        rendinst_axis_rotation__targetAngle : float;
                                                        door_operations__closedAngle : float;
                                                        rotating_door_simple_phys__closeOnClosedAngleReached : bool;
                                                        var rotating_rendinst_simple_phys__startEnabled : bool&)
  if (rotating_door_simple_phys__closeOnClosedAngleReached &&
    door_operations__state == int(DoorState.CLOSED) &&
    is_equal_float(rendinst_axis_rotation__targetAngle, door_operations__closedAngle))
    rotating_rendinst_simple_phys__startEnabled = false
  else
    rotating_rendinst_simple_phys__startEnabled = true


[es]
def rotating_rendinst_simple_phys_close_door_by_clamp_angle_reached(evt : RotatingRendinstSimplePhysClampAngleReached;
                                                                    door_operations__closedAngle : float;
                                                                    rotating_door_simple_phys__closeOnClosedAngleReached : bool;
                                                                    var rotating_rendinst_simple_phys__angularVelocity : float&;
                                                                    var rotating_rendinst_simple_phys__torque : float&)
  if rotating_door_simple_phys__closeOnClosedAngleReached && is_equal_float(evt.angle, door_operations__closedAngle)
    rotating_rendinst_simple_phys__angularVelocity = 0.0
    rotating_rendinst_simple_phys__torque = 0.0


[es(tag=server)]
def rotating_rendinst_simple_phys_close_door_by_clamp_angle_reached_server(evt : RotatingRendinstSimplePhysClampAngleReached;
                                                                           door_operations__closedAngle : float;
                                                                           rotating_door_simple_phys__closeOnClosedAngleReached : bool;
                                                                           var door_operations__state : int&;
                                                                           var door_operations__reqState : int&;
                                                                           var rendinst_axis_rotation__targetAngle : float&;
                                                                           var door_operations__serverTargetAngle : float&;
                                                                           var rotating_rendinst_simple_phys__startEnabled : bool&)
  if rotating_door_simple_phys__closeOnClosedAngleReached && is_equal_float(evt.angle, door_operations__closedAngle)
    door_operations__state = int(DoorState.CLOSED)
    door_operations__reqState = int(DoorState.CLOSED)

    rendinst_axis_rotation__targetAngle = door_operations__closedAngle
    door_operations__serverTargetAngle = door_operations__closedAngle

    rotating_rendinst_simple_phys__startEnabled = false
