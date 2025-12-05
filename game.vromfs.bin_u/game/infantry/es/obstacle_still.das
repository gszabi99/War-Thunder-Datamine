require ecs
require pathfinder
require math.base
require DagorMath
require DagorSystem
require WTDamageModel
require CollRes
require RendInst
require strings
require Unit
require Grid


def add_obstacle_template(eid : EntityId; transform : float3x4; cur_time : float; obstacle_template : string)
  addSubTemplate(eid, obstacle_template) <| $(var init : ComponentsInitializer)
    set(init, "obstacle__lastStillTransform", transform)
    set(init, "obstacle__lastStillTime", cur_time)

def still_player_obstacles_from_grid(cur_time : float; obstacle_template : string)
  query() <| $ [es(REQUIRE_NOT=(obstacle__still, obstacle__handle, deadEntity), REQUIRE=(human, collres, grid_obj))] (eid : EntityId; transform : float3x4; beh_tree__enabled : bool)
    if !beh_tree__enabled
      add_obstacle_template(eid, transform, cur_time, obstacle_template)

  query() <| $ [es(REQUIRE=(human, obstacle__still))] (eid : EntityId; isAlive : bool; beh_tree__enabled : bool = false)
    if beh_tree__enabled || !isAlive
      removeSubTemplate(eid, obstacle_template)

def still_obstacles_from_grid(cur_time : float; obstacle_template : string)
  query() <| $ [es(REQUIRE_NOT=(obstacle__still, human, obstacle__handle, moveable_obstacle),
                   REQUIRE=(grid_obj, unit__ref))] (eid : EntityId;
                                                    transform : float3x4;
                                                    grid_obj__hidden : int = 0;
                                                    grid_obj__gridType : string = "")
    if grid_obj__hidden == 0 && (empty(grid_obj__gridType) || (grid_obj__gridType == "vehicles"))
      add_obstacle_template(eid, transform, cur_time, obstacle_template)

  query() <| $ [es(REQUIRE=obstacle__still)] (eid : EntityId; grid_obj__hidden : int)
    if grid_obj__hidden != 0
      removeSubTemplate(eid, obstacle_template)

def still_obstacles_from_riextra(cur_time : float; obstacle_template : string)
  query() <| $ [es(REQUIRE_NOT=(obstacle__still, obstacle__handle, ri_extra__handle, moveable_obstacle, rallypoint, neverStillObstacle))] (eid : EntityId; transform : float3x4; ri_extra : RiExtraComponent)
    let riType = handle_to_ri_type(ri_extra.handle)
    if get_ri_gen_extra_collres(int(riType)) != null
      add_obstacle_template(eid, transform, cur_time, obstacle_template)

def still_obstacles_update(cur_time : float)
  query() <| $ [es(REQUIRE=obstacle__still,
                   REQUIRE_NOT=(neverStillObstacle))] (eid : EntityId;
                                                       obstacle__checkDelta : float;
                                                       obstacle__stillPosThreshold : float;
                                                       obstacle__stillAngCosThreshold : float;
                                                       obstacle__stillTimeout : float;
                                                       obstacle__initialStillTimeout : float;
                                                       obstacle__isFarDelayed : bool;
                                                       obstacle__padding : float = 0.0f;
                                                       obstacle__paddingSide : float = 0.0f;
                                                       obstacle__paddingCorr : float3 = float3();
                                                       var obstacle__stillCount : int&;
                                                       var obstacle__handle : int&;
                                                       var obstacle__lastCheckTime : float&;
                                                       var obstacle__lastStillTransform : float3x4&;
                                                       var obstacle__lastStillTime : float&;
                                                       transform : float3x4;
                                                       collres : CollisionResource const?;
                                                       unit__ref : UnitRef const?;
                                                       ri_extra : RiExtraComponent const?)
    if obstacle__isFarDelayed
      return
    if (cur_time < obstacle__lastCheckTime + obstacle__checkDelta)
      return
    obstacle__lastCheckTime = cur_time
    if ((length_sq(transform[3] - obstacle__lastStillTransform[3]) > square(obstacle__stillPosThreshold)) ||
      (transform[0] != obstacle__lastStillTransform[0] && dot(normalize(transform[0]), normalize(obstacle__lastStillTransform[0])) < obstacle__stillAngCosThreshold))
      obstacle__lastStillTime = cur_time
      obstacle__lastStillTransform = transform
      tilecache_obstacle_remove(obstacle__handle)
      obstacle__handle = 0
      return
    let timeout = (obstacle__stillCount > 0) ? obstacle__stillTimeout : obstacle__initialStillTimeout
    if (cur_time < obstacle__lastStillTime + timeout)
      return
    obstacle__lastStillTime = cur_time
    obstacle__lastStillTransform = transform
    if obstacle__handle == 0
      ++obstacle__stillCount
      var cr : CollisionResource const? = null
      if collres != null
        cr = collres
      elif unit__ref != null
        let unit = unit__ref.unit
        let visual = unit.visual
        if visual == null
          return
        cr = visual.collisionResource
      elif ri_extra != null
        let riType = handle_to_ri_type((*ri_extra).handle)
        cr = get_ri_gen_extra_collres(int(riType))
      if cr != null
        var blocking = false
        if ri_extra != null
          blocking = tilecache_is_blocking((*ri_extra).handle)
          if has(eid, "destroyable_wall")
            let desc = RendInstDesc((*ri_extra).handle)
            let riName = desc.isValid ? getRIGenResName(desc) : ""
            let isDmg = find(riName, "_dmg_") > -1
            if isDmg
              return
            blocking = true
        var box = BBox3((*cr).vFullBBox)
        box.boxMin -= float3(0.0f, obstacle__padding, 0.0f)
        bbox3_inflateXZ(box, obstacle__paddingSide)
        box.boxMin -= obstacle__paddingCorr
        box.boxMax += obstacle__paddingCorr
        obstacle__handle = tilecache_obstacle_add(transform, box, blocking)
      else
        logerr("No collision resource in still_obstacles_update: {eid} {getEntityTemplateName(eid)}")

[es(tag=server, no_order)]
def still_obstacles_check_es(info : UpdateStageInfoAct;
                             var still_obstacles__lastCheckTime : float&;
                             still_obstacles__checkDelta : float;
                             still_obstacles__obstacleTemplate : string)
  if !tilecache_is_loaded()
    return
  if (info.curTime < still_obstacles__lastCheckTime + still_obstacles__checkDelta)
    return
  still_obstacles__lastCheckTime = info.curTime
  still_obstacles_from_riextra(info.curTime, still_obstacles__obstacleTemplate)
  still_player_obstacles_from_grid(info.curTime, still_obstacles__obstacleTemplate)
  if rendinst_isRiExtraLoaded()
    still_obstacles_from_grid(info.curTime, still_obstacles__obstacleTemplate)
  still_obstacles_update(info.curTime)

[es(tag=server, on_appear, REQUIRE=(obstacle__still, farDelayedObstacle))]
def far_delayed_obstacle_appear_es(evt : Event;
                                   eid : EntityId;
                                   var obstacle__isFarDelayed : bool&)
  obstacle__isFarDelayed = true
  query() <| $ [es] (var still_obstacles__farDelayedList : EidList&;
                     var still_obstacles__farDelayedNumTotal : int&)
    still_obstacles__farDelayedList |> push(eid)
    ++still_obstacles__farDelayedNumTotal

[es(tag=server, on_disappear, REQUIRE=obstacle__still)]
def obstacle_disappear_es(evt : Event; var obstacle__handle : int&)
  tilecache_obstacle_remove(obstacle__handle)
  obstacle__handle = 0

[es(tag=server, before=still_obstacles_check_es)]
def far_delayed_obstacles_update_es(info : UpdateStageInfoAct;
                                    still_obstacles__checkFarDelayedTimeDelta : float;
                                    still_obstacles__checkFarDelayedRadius : float;
                                    var still_obstacles__farDelayedList : EidList&;
                                    var still_obstacles__currentFarDelayedIdx : int&;
                                    var still_obstacles__lastFarDelayedCheckTime : float&)
  if !tilecache_is_loaded() || empty(still_obstacles__farDelayedList)
    return
  if info.curTime < still_obstacles__lastFarDelayedCheckTime + still_obstacles__checkFarDelayedTimeDelta
    return
  still_obstacles__lastFarDelayedCheckTime = info.curTime
  let eid = still_obstacles__farDelayedList[still_obstacles__currentFarDelayedIdx]
  query(eid) <| $ [es(REQUIRE=obstacle__still)] (transform : float3x4;
                                                 var obstacle__isFarDelayed : bool&)
    for_each_entity_in_grid(ecs_hash("humans"), BSphere3(transform[3], still_obstacles__checkFarDelayedRadius), GridEntCheck.BOUNDING) <| $(agent_eid : EntityId)
      if !obstacle__isFarDelayed
        return
      query(agent_eid) <| $ [es(REQUIRE=human)] (beh_tree__enabled : bool; isAlive : bool; isDowned : bool)
        if !beh_tree__enabled || !isAlive || isDowned
          return
        obstacle__isFarDelayed = false
        still_obstacles__farDelayedList |> erase(still_obstacles__currentFarDelayedIdx)
        --still_obstacles__currentFarDelayedIdx

  let listLen = length(still_obstacles__farDelayedList)
  if listLen > 0
    still_obstacles__currentFarDelayedIdx = (still_obstacles__currentFarDelayedIdx + 1) % listLen
  else
    still_obstacles__currentFarDelayedIdx = 0
