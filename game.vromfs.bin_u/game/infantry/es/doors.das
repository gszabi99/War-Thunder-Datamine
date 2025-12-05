require ecs
require math.base
require DagorMath

require %appGame.wt_events
require %appGame.infantry.es.door_operations_common


[es(tag=server, on_appear)]
def door_check_from_door_controller_on_appear(evt : Event;
                                              eid aka door_eid : EntityId;
                                              transform aka door_transform : float3x4;
                                              isDoor : bool)
  if !isDoor
    return

  find_query() <| $ [es] (eid aka door_controller_eid : EntityId;
                          door_controller__detectDoorRadius : float;
                          transform aka door_controller_transform : float3x4;
                          var door_controller__doorEid : EntityId&)
    if door_controller__doorEid != INVALID_ENTITY_ID
      return false

    let distSq = distance_sq(door_transform[3], door_controller_transform[3])
    if distSq <= square(door_controller__detectDoorRadius)
      door_controller__doorEid = door_eid
      sendEvent(door_controller_eid, EventDoorControllerInited())
      return true
    return false


[es(tag=server)]
def door_controller_init_state(evt : EventDoorControllerInited;
                               door_controller__initState : int;
                               door_controller__doorEid : EntityId)
  change_door_state(door_controller__doorEid, door_controller__initState, float3(), true)


[es(on_appear)]
def door_calculate_rotation_speed_by_mass(evt : Event;
                                          rendinst__mass : float;
                                          door__rotSpeedPerMass : float = 3000.0;
                                          var rendinst_axis_rotation__rotSpeed : float&)
  if rendinst__mass > 0.0
    rendinst_axis_rotation__rotSpeed = door__rotSpeedPerMass / rendinst__mass


[es(on_appear, after=door_calculate_rotation_speed_by_mass, before=rotating_rendinst_simple_phys_appear)]
def door_calculate_mass_by_rotation_speed(evt : Event;
                                          rendinst_axis_rotation__rotSpeed : float;
                                          door__rotSpeedPerMass : float = 3000.0;
                                          var rendinst__mass : float&)
  if rendinst__mass == 0.0 && rendinst_axis_rotation__rotSpeed > 0.0
    rendinst__mass = door__rotSpeedPerMass / rendinst_axis_rotation__rotSpeed


[es(on_appear)]
def rotating_door_init_opened_dir(evt : Event;
                                  rendinst_axis_rotation__axis : float3;
                                  door_operations__openedAngle : float;
                                  initialTransform : float3x4;
                                  var door_operations__openedDir : float3&)
  var tm : float3x4
  make_tm(rendinst_axis_rotation__axis, deg_to_rad(door_operations__openedAngle), tm)
  tm = initialTransform * tm
  door_operations__openedDir = tm[0]
