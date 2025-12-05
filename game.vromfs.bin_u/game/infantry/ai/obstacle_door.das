require ecs
require app
require pathfinder
require DagorMath
require RendInst

def obstacle_door_update(var obstacle__handle : int&;
                         transform : float3x4;
                         rendinst_axis_rotation__curAngle : float;
                         door_operations__closedAngle : float;
                         ri_extra : RiExtraComponent;
                         obstacle__padding : float;
                         obstacle__doorMaxAngleDeviationFromClosed : float;
                         in_progress : bool)
  let isDoorClosed = abs(rendinst_axis_rotation__curAngle - door_operations__closedAngle) < obstacle__doorMaxAngleDeviationFromClosed

  if isDoorClosed && !in_progress
    tilecache_obstacle_remove(obstacle__handle)
    obstacle__handle = 0
    return

  let blocking = tilecache_is_blocking(ri_extra.handle)
  let riType = handle_to_ri_type(ri_extra.handle)
  let doorCollres = get_ri_gen_extra_collres(int(riType))
  if doorCollres != null
    var box = doorCollres.vFullBBox
    box.bmin.y -= obstacle__padding
    if obstacle__handle == 0
      obstacle__handle = tilecache_obstacle_add(transform, BBox3(box), blocking)
    else
      tilecache_obstacle_move(obstacle__handle, transform, BBox3(box), blocking)

[es(tag=server, on_appear, on_event=EventLevelLoaded)]
def obstacle_door_created_es(evt : Event;
                             var obstacle__handle : int&;
                             transform : float3x4;
                             rendinst_axis_rotation__curAngle : float;
                             door_operations__closedAngle : float;
                             obstacle__doorMaxAngleDeviationFromClosed : float;
                             ri_extra : RiExtraComponent;
                             isDoor : bool = false;
                             obstacle__padding : float = 0.0f)
  if !isDoor
    return
  obstacle_door_update(obstacle__handle, transform,
    rendinst_axis_rotation__curAngle, door_operations__closedAngle,
    ri_extra, obstacle__padding, obstacle__doorMaxAngleDeviationFromClosed, false)


[es(tag=server, on_event=EventComponentsDisappear, REQUIRE=rendinst_axis_rotation__enabled)]
def obstacle_door_move_done_es(evt : Event;
                               var obstacle__handle : int&;
                               transform : float3x4;
                               rendinst_axis_rotation__curAngle : float;
                               door_operations__closedAngle : float;
                               obstacle__doorMaxAngleDeviationFromClosed : float;
                               ri_extra : RiExtraComponent;
                               isDoor : bool = false;
                               obstacle__padding : float = 0.0f)
  if !isDoor
    return
  obstacle_door_update(obstacle__handle, transform,
    rendinst_axis_rotation__curAngle, door_operations__closedAngle,
    ri_extra, obstacle__padding, obstacle__doorMaxAngleDeviationFromClosed, false)


[es(tag=server, on_event=EventComponentsDisappear, REQUIRE=rotating_rendinst_simple_phys_processing)]
def obstacle_door_physics_done_es(evt : Event;
                                  var obstacle__handle : int&;
                                  transform : float3x4;
                                  rendinst_axis_rotation__curAngle : float;
                                  door_operations__closedAngle : float;
                                  obstacle__doorMaxAngleDeviationFromClosed : float;
                                  ri_extra : RiExtraComponent;
                                  isDoor : bool = false;
                                  obstacle__padding : float = 0.0f)
  if !isDoor
    return
  obstacle_door_update(obstacle__handle, transform,
    rendinst_axis_rotation__curAngle, door_operations__closedAngle,
    ri_extra, obstacle__padding, obstacle__doorMaxAngleDeviationFromClosed, false)


[es(tag=server, on_appear, REQUIRE=(rendinst_axis_rotation__enabled, door_operations__closedAngle, ri_extra))]
def obstacle_door_move_start_es(evt : Event;
                                var obstacle__lastCheckTime : float&;
                                isDoor : bool = false)
  if !isDoor
    return
  obstacle__lastCheckTime = get_sync_time()


[es(tag=server, on_appear, REQUIRE=(rotating_rendinst_simple_phys_processing, door_operations__closedAngle, ri_extra))]
def obstacle_door_physics_start_es(evt : Event;
                                   var obstacle__lastCheckTime : float&;
                                   isDoor : bool = false)
  if !isDoor
    return
  obstacle__lastCheckTime = get_sync_time()


[es(tag=server, no_order)]
def obstacle_door_check_es(info : UpdateStageInfoAct;
                           transform : float3x4;
                           rendinst_axis_rotation__curAngle : float;
                           door_operations__closedAngle : float;
                           ri_extra : RiExtraComponent;
                           obstacle__checkDelta : float;
                           var obstacle__lastCheckTime : float&;
                           var obstacle__handle : int&;
                           rotating_rendinst_simple_phys_processing : Tag const?;
                           rendinst_axis_rotation__enabled : Tag const?;
                           isDoor : bool = false;
                           obstacle__padding : float = 0.0f;
                           obstacle__doorMaxStillAngularVelocity : float = 10.0;
                           obstacle__doorMaxAngleDeviationFromClosed : float = 45.0;
                           rotating_rendinst_simple_phys__angularVelocity : float = FLT_MAX)
  if !isDoor || (rendinst_axis_rotation__enabled == null && rotating_rendinst_simple_phys_processing == null)
    return
  if (info.curTime < obstacle__lastCheckTime + obstacle__checkDelta)
    return
  obstacle__lastCheckTime = info.curTime
  obstacle_door_update(obstacle__handle, transform,
    rendinst_axis_rotation__curAngle, door_operations__closedAngle,
    ri_extra, obstacle__padding, obstacle__doorMaxAngleDeviationFromClosed, abs(rotating_rendinst_simple_phys__angularVelocity) > obstacle__doorMaxStillAngularVelocity)
