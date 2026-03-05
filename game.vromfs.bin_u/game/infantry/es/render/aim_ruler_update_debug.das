options no_aot
require ecs
require Grid
require GridCollision
require CollisionTraces


def private trace_grid(grid_type : uint; pos, dir : float3; var len : float&)
  var retEid = INVALID_ENTITY_ID
  trace_entities_in_grid(grid_type, pos, dir, len, INVALID_ENTITY_ID, SortIntersections.YES) <| $(intersections : array<IntersectedEntity>#)
    if length(intersections) != 0
      retEid = intersections[0].eid
  return retEid


[es(tag=render, before=draw_ruler_es, REQUIRE=aimRulerDebug)]
def aim_ruler_update_es(evt : UpdateStageInfoAct;
                        var aim_ruler__shouldDraw : bool&;
                        var aim_ruler__tracePos : float3&;
                        var aim_ruler__traceDir : float3&;
                        var aim_ruler__traceLen : float&;
                        var aim_ruler__targetEid : EntityId&)
  aim_ruler__shouldDraw = find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    if !camera__active
      return false
    aim_ruler__traceDir = transform[2]
    aim_ruler__tracePos = transform[3]
    return true

  aim_ruler__traceLen = 4000f
  let humanTarget = trace_grid(ecs_hash("humans"), aim_ruler__tracePos, aim_ruler__traceDir, aim_ruler__traceLen)
  let vehicleTarget = trace_grid(ecs_hash("vehicles"), aim_ruler__tracePos, aim_ruler__traceDir, aim_ruler__traceLen)
  let lootTarget = trace_grid(ecs_hash("loot"), aim_ruler__tracePos, aim_ruler__traceDir, aim_ruler__traceLen)
  let gunTarget = trace_grid(ecs_hash("interactable"), aim_ruler__tracePos, aim_ruler__traceDir, aim_ruler__traceLen)
  aim_ruler__targetEid = !!gunTarget ? gunTarget : !!lootTarget ? lootTarget : !!humanTarget ? humanTarget : vehicleTarget
