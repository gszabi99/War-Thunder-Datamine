require ecs
require Mission
require DagorSystem
require math

[cpp_event]
struct EventMoveByRoute
  uId : int
  uEid : EntityId
  wpEid : EntityId
  start : bool

[cpp_event]
struct ArrivedToWayPoint
  uId : int
  uEid : EntityId
  wpEid : EntityId

def square(x : float)
  return x * x

[es (tag=server, on_event=EventLevelLoaded)]
def route_init(evt : Event;
               route_dot_wayPointsNames : StringList;
               var route_dot_wayPoints : EidList)
  for i in range(0, length(route_dot_wayPointsNames))
    let wayPointName = string(route_dot_wayPointsNames[i])
    find_query() <| $ [es](way_point_dot_name : string; eid : EntityId)
      if wayPointName == way_point_dot_name
        push_back(route_dot_wayPoints, eid)
      return wayPointName == way_point_dot_name

def set_next_way_point(wpEid, unitEid : EntityId; uid : int)
  ecs::query(wpEid) <| $ [es] (way_point_dot_moveType : string;
                                way_point_dot_transform : float3x4;
                                way_point_dot_speed : float)
    set_destination_way_point(uid, way_point_dot_moveType, way_point_dot_transform, way_point_dot_speed)
  ecs::query(unitEid) <| $ [es] (var unit_current_route_dot_curWayPoint : EntityId&)
    unit_current_route_dot_curWayPoint = wpEid

def get_next_way_point(curWp : EntityId; routeWps : EidList; isLooped : bool)
  if (curWp != INVALID_ENTITY_ID)
    for i in range(0, length(routeWps))
      if routeWps[i] == curWp && i < length(routeWps) - 1
        return routeWps[i+1]
      elif i == length(routeWps) - 1
        return isLooped ? routeWps[0] : INVALID_ENTITY_ID
  return INVALID_ENTITY_ID

[es (tag=server)]
def start_move_along_path_es(evt : EventMoveByRoute;
                            route_dot_wayPoints : EidList)
  if length(route_dot_wayPoints) != 0
    let wpEid = evt.start ? route_dot_wayPoints[0] : evt.wpEid
    set_next_way_point(wpEid, evt.uEid, evt.uId)

[es (tag=server)]
def way_point_on_arrived_es(evt : ArrivedToWayPoint;
                            route_dot_wayPoints : EidList;
                            route_dot_isLooped : bool)
  set_next_way_point(get_next_way_point(evt.wpEid, route_dot_wayPoints, route_dot_isLooped), evt.uEid, evt.uId)

[es (tag=server, no_order)]
def routing_update_es(act : ecs::UpdateStageInfoAct;
                      eid, unit_current_route_dot_curWayPoint, unit_current_route_dot_routeEid : EntityId;
                      uid : int; move_sys_dot_maxDecel : float)
  if (unit_current_route_dot_curWayPoint != INVALID_ENTITY_ID &&
   unit_current_route_dot_routeEid != INVALID_ENTITY_ID)
    ecs::query(unit_current_route_dot_curWayPoint) <| $ [es] (way_point_dot_transform : float3x4)
      let vel = length_sq(get_move_sys_vel(uid))
      let dist = length_sq(way_point_dot_transform[3] - get_unit_pos(uid))
      let recDecel = move_sys_dot_maxDecel != 0.f ? 1.f / move_sys_dot_maxDecel : 1.f;
      let timeToDecel = dist < square(vel * recDecel * 0.5)
      if timeToDecel
        ecs::query(unit_current_route_dot_routeEid) <| $ [es] (route_dot_wayPoints : EidList;
                                                              route_dot_isLooped : bool)
          let nextWp = get_next_way_point(unit_current_route_dot_curWayPoint, route_dot_wayPoints, route_dot_isLooped)
          ecs::query(nextWp) <| $ [es] (way_point_dot_moveType : string)
            if way_point_dot_moveType == "USE_SPLINE"
              set_move_sys_state(uid, int(MoveSysState ST_HALT))
    let state = get_move_sys_state(uid)
    if (state == int(MoveSysState ST_HALT))
      sendEvent(unit_current_route_dot_routeEid, [[ArrivedToWayPoint uId=uid, uEid=eid, wpEid=unit_current_route_dot_curWayPoint ]])

[es (tag=server, no_order, REQUIRE_NOT=move_sys_dot_maxDecel)]
def plane_routing_update_es(act : ecs::UpdateStageInfoAct;
                      eid, unit_current_route_dot_curWayPoint, unit_current_route_dot_routeEid : EntityId;
                      uid : int)
  if (unit_current_route_dot_curWayPoint != INVALID_ENTITY_ID &&
   unit_current_route_dot_routeEid != INVALID_ENTITY_ID)
    ecs::query(unit_current_route_dot_curWayPoint) <| $ [es] (way_point_dot_transform : float3x4;
                                                              way_point_dot_radius : float)
      let distSq = length_sq(way_point_dot_transform[3] - get_unit_pos(uid))
      let dist = length(way_point_dot_transform[3] - get_unit_pos(uid))
      if (distSq < way_point_dot_radius * way_point_dot_radius)
        sendEvent(unit_current_route_dot_routeEid, [[ArrivedToWayPoint uId=uid, uEid=eid, wpEid=unit_current_route_dot_curWayPoint ]])