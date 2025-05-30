require ecs
require Mission
require DagorSystem
require math
require Unit

[cpp_event(unicast)]
struct EventMoveByRoute
  uEid : EntityId
  wpEid : EntityId
  start : bool

[cpp_event(unicast)]
struct ArrivedToWayPoint
  uEid : EntityId
  wpEid : EntityId

def square(x : float)
  return x * x

[es(tag=server, on_event=EventLevelLoaded)]
def route_init(evt : Event;
               route__wayPointsNames : StringList;
               var route__wayPoints : EidList)
  for i in range(0, length(route__wayPointsNames))
    let wayPointName = string(route__wayPointsNames[i])
    find_query() <| $ [es] (way_point__name : string; eid : EntityId)
      if wayPointName == way_point__name
        push(route__wayPoints, eid)
      return wayPointName == way_point__name

def set_next_way_point(wpEid, unitEid : EntityId)
  ecs::query(wpEid) <| $ [es] (way_point__moveType : string;
                               way_point__transform : float3x4;
                               way_point__speed : float)
    set_destination_way_point(get_unit_by_eid(unitEid), way_point__moveType, way_point__transform, way_point__speed)
  ecs::query(unitEid) <| $ [es] (var unit_current_route__curWayPoint : EntityId&)
    unit_current_route__curWayPoint = wpEid

def get_next_way_point(curWp : EntityId; routeWps : EidList; isLooped : bool)
  if (curWp != INVALID_ENTITY_ID)
    for i in range(0, length(routeWps))
      if routeWps[i] == curWp && i < length(routeWps) - 1
        return routeWps[i + 1]
      elif i == length(routeWps) - 1
        return isLooped ? routeWps[0] : INVALID_ENTITY_ID
  return INVALID_ENTITY_ID

[es(tag=server)]
def start_move_along_path_es(evt : EventMoveByRoute;
                             route__wayPoints : EidList)
  if length(route__wayPoints) != 0
    let isEvtWpInvalid = evt.wpEid == INVALID_ENTITY_ID
    if !evt.start && isEvtWpInvalid
      logerr("start_move_along_path_es: try to continue path by invalid way_point Eid")
    let wpEid = evt.start || isEvtWpInvalid ? route__wayPoints[0] : evt.wpEid
    set_next_way_point(wpEid, evt.uEid)

[es(tag=server)]
def way_point_on_arrived_es(evt : ArrivedToWayPoint;
                            route__wayPoints : EidList;
                            route__isLooped : bool)
  set_next_way_point(get_next_way_point(evt.wpEid, route__wayPoints, route__isLooped), evt.uEid)

[es(tag=server, no_order)]
def routing_update_es(act : ecs::UpdateStageInfoAct;
                      eid, unit_current_route__curWayPoint, unit_current_route__routeEid : EntityId)
  if (unit_current_route__curWayPoint != INVALID_ENTITY_ID &&
    unit_current_route__routeEid != INVALID_ENTITY_ID)
    let state = get_move_sys_state(get_unit_by_eid(eid))
    if (state == int(MoveSysState.ST_HALT))
      sendEvent(unit_current_route__routeEid, ArrivedToWayPoint(uEid = eid, wpEid = unit_current_route__curWayPoint))

[es(tag=server, no_order, REQUIRE_NOT=move_sys__maxDecel)]
def plane_routing_update_es(act : ecs::UpdateStageInfoAct;
                            eid, unit_current_route__curWayPoint, unit_current_route__routeEid : EntityId)
  if (unit_current_route__curWayPoint != INVALID_ENTITY_ID &&
   unit_current_route__routeEid != INVALID_ENTITY_ID)
    ecs::query(unit_current_route__curWayPoint) <| $ [es] (way_point__transform : float3x4;
                                                           way_point__radius : float)
      let distSq = length_sq(way_point__transform[3] - get_unit_pos(get_unit_by_eid(eid)))
      if (distSq < way_point__radius * way_point__radius)
        sendEvent(unit_current_route__routeEid, ArrivedToWayPoint(uEid = eid, wpEid = unit_current_route__curWayPoint))