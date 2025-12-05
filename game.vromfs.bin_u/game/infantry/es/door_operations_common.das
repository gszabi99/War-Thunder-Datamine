module door_operations_common shared
require ecs
require app
require math.base

require %appGame.wt_events
require DagorMathUtils


enum DoorState
  CLOSED
  OPENED
  AJAR

def get_omni_rotate_door_opened_angle_with_dir(door_operations__openedAngle : float;
                                               door_operations__closedAngle : float;
                                               koef : float)
  return door_operations__closedAngle + (door_operations__closedAngle - door_operations__openedAngle) * koef


def get_target_angle(transform : float3x4;
                     opener_pos : float3;
                     target_state : int;
                     door_operations__omniRotate : bool;
                     door_operations__openedAngle : float;
                     door_operations__closedAngle : float;
                     door_operations__ajarAngleKoef : float)
  let doorPos = transform[3]
  let doorDir = transform[2]
  let dirSign = dot(doorDir, (doorPos - opener_pos)) > 0f ? 1f : -1f
  let angleSign = (door_operations__openedAngle - door_operations__closedAngle) > 0f ? 1f : -1f
  let sign = dirSign * angleSign

  if target_state == int(DoorState.OPENED)
    if door_operations__omniRotate
      return get_omni_rotate_door_opened_angle_with_dir(door_operations__openedAngle, door_operations__closedAngle, sign)
    else
      return door_operations__openedAngle
  elif target_state == int(DoorState.AJAR)
    if door_operations__omniRotate
      let koef = door_operations__ajarAngleKoef * sign
      return get_omni_rotate_door_opened_angle_with_dir(door_operations__openedAngle, door_operations__closedAngle, koef)
    else
      return get_omni_rotate_door_opened_angle_with_dir(door_operations__openedAngle, door_operations__closedAngle, -door_operations__ajarAngleKoef)
  else
    return door_operations__closedAngle


def detect_door_state_by_angle(current_angle : float;
                               opened_angle : float;
                               closed_angle : float)
  let tol = 1e-3
  if abs(angle_diff(current_angle * DEG_TO_RAD, closed_angle * DEG_TO_RAD) * RAD_TO_DEG) < tol
    return int(DoorState.CLOSED)

  let openedAngle1 = opened_angle
  if abs(angle_diff(current_angle * DEG_TO_RAD, openedAngle1 * DEG_TO_RAD) * RAD_TO_DEG) < tol
    return int(DoorState.OPENED)

  let openedAngle2 = get_omni_rotate_door_opened_angle_with_dir(opened_angle, closed_angle, 1.0)
  if abs(angle_diff(current_angle * DEG_TO_RAD, openedAngle2 * DEG_TO_RAD) * RAD_TO_DEG) < tol
    return int(DoorState.OPENED)

  return int(DoorState.AJAR)


def get_door_full_rotation_angle(opened_angle : float;
                                 closed_angle : float)
  return abs(angle_diff(opened_angle * DEG_TO_RAD, closed_angle * DEG_TO_RAD) * RAD_TO_DEG)


def get_door_ajar_rotation_angle(opened_angle : float;
                                 closed_angle : float;
                                 ajar_angle_koef : float)
  return get_door_full_rotation_angle(opened_angle, closed_angle) * ajar_angle_koef


def change_door_state(door_eid : EntityId;
                      target_door_state : int;
                      opener_pos : float3;
                      is_server : bool;
                      ignore_lock : bool = false;
                      ignore_cooldown : bool = false)
  query(door_eid) <| $ [es] (var door_operations__reqState : int&;
                             var rendinst_axis_rotation__targetAngle : float&;
                             var door_operations__serverTargetAngle : float&;
                             var door_operations__lastUseTime : float&;
                             var rendinst_axis_rotation__rotSpeedKoef : float&;
                             rendinst_axis_rotation__curAngle : float;
                             door_operations__state : int;
                             locked__isLocked : bool = false;
                             door_operations__openedAngle : float;
                             door_operations__closedAngle : float;
                             door_operations__ajarAngleKoef : float;
                             door_operations__ajarSpeedKoef : float;
                             initialTransform : float3x4;
                             door_operations__omniRotate : bool = false;
                             door_operations__useCooldown : float;
                             rotating_rendinst_simple_phys__processingTemplate : das_string const?)
    let curTime = get_sync_time()
    if curTime - door_operations__lastUseTime < door_operations__useCooldown && !ignore_cooldown
      return
    if locked__isLocked && !ignore_lock
      return

    if is_server
      door_operations__reqState = target_door_state

    sendEvent(door_eid, EventDoorChangeStateRequest(target_door_state = target_door_state))

    let targetAngle = get_target_angle(initialTransform, opener_pos, target_door_state,
                                              door_operations__omniRotate,
                                              door_operations__openedAngle, door_operations__closedAngle,
                                              door_operations__ajarAngleKoef)
    let angleDiff = abs(angle_diff(rendinst_axis_rotation__curAngle * DEG_TO_RAD, targetAngle * DEG_TO_RAD) * RAD_TO_DEG)

    let ajarRotationAngle = get_door_ajar_rotation_angle(door_operations__openedAngle, door_operations__closedAngle, door_operations__ajarAngleKoef)

    if (target_door_state == int(DoorState.AJAR) ||
      (door_operations__state == int(DoorState.AJAR) && (angleDiff - 1e-3) <= ajarRotationAngle))
      rendinst_axis_rotation__rotSpeedKoef = door_operations__ajarSpeedKoef
    else
      rendinst_axis_rotation__rotSpeedKoef = 1.0

    if rotating_rendinst_simple_phys__processingTemplate != null
      removeSubTemplate(door_eid, string(*rotating_rendinst_simple_phys__processingTemplate))

    rendinst_axis_rotation__targetAngle = targetAngle
    door_operations__lastUseTime = curTime

    if is_server
      door_operations__serverTargetAngle = targetAngle 
    else 
      let alreadyPredicting = find_query() <| $ [es] (door_client_prediction__doorEid : EntityId; var door_client_prediction__atTime : float&)
        if door_client_prediction__doorEid == door_eid
          door_client_prediction__atTime = curTime
          return true
        return false

      if !alreadyPredicting
        createEntity("door_client_prediction_tracker") <| $(init)
          init |> set("door_client_prediction__doorEid", door_eid)
          init |> set("door_client_prediction__atTime", curTime)


def cmd_use_door(door_eid, opener_eid, pair_door__eid : EntityId;
                 target_state : int;
                 is_server : bool)
  let isLocked = get_bool(door_eid, "door__isLocked") ?? false
  let isLocking = get_bool(door_eid, "door__isLocking") ?? false
  if isLocking
    return
  if isLocked
    return
  query(opener_eid) <| $ [es] (transform : float3x4)
    let openerPos = transform[3]
    change_door_state(door_eid, target_state, openerPos, is_server)
    change_door_state(pair_door__eid, target_state, openerPos, is_server)


def get_door_main_action(cur_state : int;
                         door_tm : float3x4;
                         door_initial_tm : float3x4;
                         opener_pos : float3)
  if cur_state == int(DoorState.OPENED)
    return int(DoorState.CLOSED)
  elif cur_state == int(DoorState.AJAR)
    let doorInitialDir = door_initial_tm[0]
    let doorPos = door_tm[3]
    let doorDir = door_tm[0]
    let openerDir = opener_pos - doorPos
    let openerDirProjected = openerDir - dot(openerDir, door_initial_tm[1]) * door_initial_tm[1]
    let isDoorCloseToOpener = dot(cross(doorInitialDir, doorDir), cross(doorInitialDir, openerDirProjected)) > 0.0

    if isDoorCloseToOpener
      return int(DoorState.CLOSED)
    else
      return int(DoorState.OPENED)
  return int(DoorState.OPENED)


def get_door_alt_action(cur_state : int)
  if cur_state == int(DoorState.CLOSED)
    return int(DoorState.AJAR)
  else
    return int(DoorState.CLOSED)


def get_window_main_action(cur_state : int)
  if cur_state == int(DoorState.OPENED)
    return int(DoorState.CLOSED)
  return int(DoorState.OPENED)
