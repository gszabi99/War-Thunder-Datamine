require ecs
require DagorMath
require DagorSystem
require math.base
require Mission
require Unit
require DagorDataBlock
require %appGame.wt_events
require %game.unit.unit_events

[es(tag=server, on_event=EventFlightStart, REQUIRE=unit_spawn_and_route)]
def unit_spawn_and_route_wake_es(evt : Event;
                                 var unit__ref : UnitRef&;
                                 unit__missionName : string)
  var spawnPointTm = IDENT_TM
  if !get_waypoints_point_tm("{unit__missionName}_waypoints", 0, spawnPointTm)
    return
  *unit__ref.unit |> setDelayed(false)

[es(tag=server, on_event=EventUnitDelayedStatusChanged, REQUIRE=unit_spawn_and_route, after=unit_init_completed_es)]
def unit_spawn_and_route_assign_es(evt : Event;
                                   var unit__ref : UnitRef&;
                                   unit__missionName : string;
                                   active : bool)
  if !active
    return
  let routeName = "{unit__missionName}_waypoints"
  var spawnPointTm = IDENT_TM
  if !get_waypoints_point_tm(routeName, 0, spawnPointTm)
    logerr("unit_spawn_and_route: route '{routeName}' not found for '{unit__missionName}'")
    return
  var spawnHeading = spawnPointTm[0]
  var nextPointTm = IDENT_TM
  if get_waypoints_point_tm(routeName, 1, nextPointTm)
    var directionToNextPoint = nextPointTm[3] - spawnPointTm[3]
    directionToNextPoint.y = 0.
    if length(directionToNextPoint) > 0.01
      spawnHeading = normalize(directionToNextPoint)
  let up = float3(0., 1., 0.)
  *unit__ref.unit |> teleportToPos(false, spawnPointTm[3])
  unit__ref.unit |> setOrientation(spawnHeading, up)
  using() <| $(var blk : DataBlock)
    add(blk, "object", unit__missionName)
    add(blk, "route", routeName)
    call_mission_action("unitSetRoute", blk)
