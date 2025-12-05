require ecs
require app
require math.base
require AnimV20
require Dacoll
require GeomNodeTree
require Grid
require DagorMath
require CollRes
require %game.events


[es(tag=gameClient, on_appear, track=item__visible)]
def cache_item_visibility(evt : Event; item__visible : bool; var item__visibleCached : bool&)
  item__visibleCached = item__visible


[es(tag=render, REQUIRE=human_visibility_tracer)]
def human_visibility_tracer_es(info : ParallelUpdateFrameDelayed;
                               transform : float3x4;
                               animchar : AnimcharBaseComponent;
                               human_inventory__visTraceMatId : int = -1;
                               human_inventory__lookNodeId : int = -1;
                               visibilityTraceRadius : float = 10.f;
                               timeBetweenVisibilityChecks : float = 0.5;
                               human__canSeeLootItems : bool = true)
  let traceFromPos = human_inventory__lookNodeId >= 0 ? geomtree_getNodeWpos(*animchar.nodeTree, human_inventory__lookNodeId) : transform[3] + float3(0.f, 1.f, 0.f)
  let heroPos = transform[3]
  let curTime = get_sync_time()
  let visibilityTraceRadiusSq = square(visibilityTraceRadius)

  if human__canSeeLootItems
    for_each_entity_in_grid(ecs_hash("loot"), BSphere3(heroPos, visibilityTraceRadius), GridEntCheck.POS) <| $(lootEid : EntityId)
      if !has(lootEid, "traceVisibility")
        addSubTemplate(lootEid, "visibility_traceable_item")

  query() <| $ [es(REQUIRE=traceVisibility)] (eid : EntityId;
                                              transform : float3x4;
                                              var lastVisibilityTraceTime : float&;
                                              var lastVisibilityTraceOffset : int&;
                                              var item__visible : bool&;
                                              item__visibleCheckHeight : float = 0.5)
    if timeBetweenVisibilityChecks + lastVisibilityTraceTime > curTime
      return

    if length_sq(heroPos - transform[3]) > visibilityTraceRadiusSq || !human__canSeeLootItems
      item__visible = false
      removeSubTemplate(eid, "visibility_traceable_item")
      return

    var traceable = false
    let maxTraces = 4
    let traceOffsMult = item__visibleCheckHeight / float(maxTraces - 1)
    let offs = lastVisibilityTraceOffset
    let margin = 0.15f
    for j in range(maxTraces)
      let curOffs = (j + offs) % maxTraces
      let ht = float(curOffs) * traceOffsMult
      let dir = transform[3] + float3(0.f, ht, 0.f) - traceFromPos
      var dist = length(dir)
      let dirn = dir * safeinv(dist)
      dist = max(dist - margin, margin)
      traceable ||= !rayhit_normalized(traceFromPos, dirn, dist, ETF_DEFAULT, human_inventory__visTraceMatId)
      if traceable
        lastVisibilityTraceOffset = curOffs
        break

    item__visible = traceable
    lastVisibilityTraceTime = curTime


[es(tag=render, on_appear, REQUIRE=traceVisibility, REQUIRE_NOT=transform)]
def remove_trace_visibility_on_pickup_es(evt : Event; eid : EntityId)
  removeSubTemplate(eid, "visibility_traceable_item")


[es(tag=render, on_appear, track=transform, REQUIRE_NOT=phys_obj_net_phys)]
def visibility_traceable_item_created_es(evt : Event;
                                         item__isOnGround : bool = false;
                                         transform : float3x4;
                                         collres : CollisionResource;
                                         var item__visibleCheckHeight : float&;
                                         item__visibleCheckStartOffset : float = 0.1)
  if !item__isOnGround
    return
  let itemHeight = (transform * BBox3(collres.vFullBBox)).boxMax.y - transform[3].y
  let visibleCheckStartOffset = (collres.vFullBBox.bmax.y >= collres.vFullBBox.bmin.y) ? max(itemHeight, 0.f) : item__visibleCheckStartOffset
  let dir = float3(0.0, 1.0, 0.0)
  var norm : float3
  traceray_normalized(transform[3] + dir * visibleCheckStartOffset, dir, item__visibleCheckHeight, norm)
  item__visibleCheckHeight = max(0.0, visibleCheckStartOffset + item__visibleCheckHeight - 0.01)
