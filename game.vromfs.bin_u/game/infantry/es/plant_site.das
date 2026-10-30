require ecs
require ecs.common
require app
require math.base
require DagorMath
require DagorSystem
require RendInst
require Grid
require %game.events
require %appGame.wt_events
require %appGame.infantry.es.team_common


def private start_planting(requester_eid : EntityId;
                           total_time : float;
                           var bomb_site__operator : EntityId&;
                           var bomb_site__plantProgressDeltaPerSec : float&)
  bomb_site__operator = requester_eid
  bomb_site__plantProgressDeltaPerSec = safeinv(total_time)


def private stop_operator(var bomb_site__operator : EntityId&;
                          var bomb_site__plantProgressDeltaPerSec : float&;
                          var bomb_site__defuseProgressDeltaPerSec : float&;
                          var bomb_site__plantProgress : float&;
                          var bomb_site__defuseProgress : float&)
  bomb_site__operator = INVALID_ENTITY_ID
  bomb_site__plantProgressDeltaPerSec = 0.0
  bomb_site__defuseProgressDeltaPerSec = 0.0
  bomb_site__plantProgress = 0.0
  bomb_site__defuseProgress = 0.0


def private activate_bomb(bomb_site__timeToExplosion : float;
                          var plant_site__planterEid : EntityId&;
                          var bomb_site__operator : EntityId&;
                          var bomb_site__isBombPlanted : bool&;
                          var bomb_site__plantProgressDeltaPerSec : float&;
                          var bomb_site__timeToExplosionLeft : float&)
  bomb_site__plantProgressDeltaPerSec = 0.0
  plant_site__planterEid = bomb_site__operator
  bomb_site__operator = INVALID_ENTITY_ID
  bomb_site__isBombPlanted = true
  bomb_site__timeToExplosionLeft = bomb_site__timeToExplosion


def private defuse_bomb(var bomb_site__isBombPlanted : bool&;
                        var bomb_site__defuseProgress : float&;
                        var bomb_site__defuseProgressPausedAt : float&;
                        var bomb_site__defuseProgressDeltaPerSec : float&;
                        var bomb_site__timeToExplosionLeft : float&;
                        var plant_site__planterEid : EntityId&;
                        var bomb_site__operator : EntityId&;
                        var bomb_site__plantProgress : float&;
                        var bomb_site__plantProgressPausedAt : float&;
                        var bomb_site__plantProgressDeltaPerSec : float&)
  bomb_site__isBombPlanted = false
  bomb_site__defuseProgress = 0.0
  bomb_site__defuseProgressPausedAt = 0.0
  bomb_site__defuseProgressDeltaPerSec = 0.0
  bomb_site__timeToExplosionLeft = -1.0
  plant_site__planterEid = INVALID_ENTITY_ID
  bomb_site__operator = INVALID_ENTITY_ID
  bomb_site__plantProgress = 0.0
  bomb_site__plantProgressPausedAt = 0.0
  bomb_site__plantProgressDeltaPerSec = 0.0


def private detonate_bomb(transform : float3x4;
                          bomb_site__shellActivatorTemplate : string;
                          bomb_site__shellOffset : float3;
                          plant_site__planterEid : EntityId;
                          var plant_site__riEid : EntityId&;
                          var plant_site__destroyed : bool&;
                          var active : bool&)
  plant_site__destroyed = true
  active = false

  createEntity(bomb_site__shellActivatorTemplate) <| $(var init : ComponentsInitializer)
    var tm = transform
    tm[3] += bomb_site__shellOffset
    set(init, "transform", tm)
    set(init, "ownerEid", plant_site__planterEid)

  destroyEntity(plant_site__riEid)
  plant_site__riEid = INVALID_ENTITY_ID


def private set_operator_mirror(operator_eid : EntityId;
                                site_eid : EntityId;
                                end_time : float;
                                duration : float;
                                is_defusing : bool)
  query(operator_eid) <| $ [es] (var human_plant_site__siteEid : EntityId&;
                                 var human_plant_site__actionEndTime : float&;
                                 var human_plant_site__actionDuration : float&;
                                 var human_plant_site__isDefusing : bool&)
    human_plant_site__siteEid = site_eid
    human_plant_site__actionEndTime = end_time
    human_plant_site__actionDuration = duration
    human_plant_site__isDefusing = is_defusing


def private clear_operator_mirror(operator_eid : EntityId; site_eid : EntityId)
  query(operator_eid) <| $ [es] (var human_plant_site__siteEid : EntityId&;
                                 var human_plant_site__actionEndTime : float&;
                                 var human_plant_site__actionDuration : float&)
    if human_plant_site__siteEid == site_eid
      human_plant_site__siteEid = INVALID_ENTITY_ID
      human_plant_site__actionEndTime = -1.0
      human_plant_site__actionDuration = 0.0


[es(tag=server, on_event=EventMissionUnload, REQUIRE=plantSite)]
def plant_site_mission_unload(evt : Event; eid : EntityId)
  destroyEntity(eid)


[es(tag=server, on_appear)]
def plant_site_check_duplicate_name(evt : Event;
                                    eid : EntityId;
                                    plant_site__name : string)
  let isDuplicate = find_query() <| $ [es(REQUIRE=plantSite)] (eid aka other_eid : EntityId;
                                                               plant_site__name aka other_plant_site__name : string)
    return other_eid != eid && other_plant_site__name == plant_site__name && uint(other_eid) < uint(eid)
  if isDuplicate
    logerr("plant_site {uint(eid)}: site '{plant_site__name}' is created more than once, check the mission triggers")


[es(tag=server, on_appear)]
def plant_site_assign_icon_idx(evt : Event;
                               eid : EntityId;
                               var plant_site__iconIdx : int&)
  if plant_site__iconIdx >= 0
    return
  let selfEid = eid
  var maxIdx = -1
  query() <| $ [es(REQUIRE=plantSite)] (eid aka other_eid : EntityId;
                                        plant_site__iconIdx aka other_plant_site__iconIdx : int)
    if other_eid != selfEid
      maxIdx = max(maxIdx, other_plant_site__iconIdx)
  plant_site__iconIdx = maxIdx + 1


[es(tag=server, on_appear)]
def plant_site_spawn_rendinst(evt : Event;
                              eid : EntityId;
                              transform : float3x4;
                              plant_site__riName : string;
                              plant_site__riTemplate : string;
                              var plant_site__riEid : EntityId&)
  if !!plant_site__riEid || empty(plant_site__riName)
    return
  plant_site__riEid = createEntity(plant_site__riTemplate) <| $(var init : ComponentsInitializer)
    set(init, "transform", transform)
    set(init, "ri_extra__name", plant_site__riName)
    set(init, "plant_site_rendinst__siteEid", eid)


[es(tag=server, on_appear, after=riextra_spawn_ri_es, REQUIRE=plantSiteRendinst)]
def plant_site_rendinst_init_use_dist(evt : Event;
                                      ri_extra : RiExtraComponent;
                                      plant_site_rendinst__siteEid : EntityId)
  if ri_extra.handle == RIEX_HANDLE_NULL
    return
  let riCollres = get_ri_gen_extra_collres(int(handle_to_ri_type(ri_extra.handle)))
  if riCollres == null
    return
  let halfSize = length(riCollres.vFullBBox.bmax.xz - riCollres.vFullBBox.bmin.xz) * 0.5
  query(plant_site_rendinst__siteEid) <| $ [es] (var bomb_site__maxDist : float&)
    bomb_site__maxDist += halfSize


[es(tag=server)]
def on_plant_site_use(evt : CmdUse;
                      active : bool;
                      plant_site__destroyed : bool;
                      bomb_site__plantingTeam : int;
                      bomb_site__timeToPlant : float;
                      bomb_site__isBombPlanted : bool;
                      var bomb_site__operator : EntityId&;
                      var bomb_site__plantProgressDeltaPerSec : float&)
  if !active || plant_site__destroyed || !!bomb_site__operator || bomb_site__isBombPlanted
    return
  query(evt.requesterEid) <| $ [es] (team : int;
                                     isAlive : bool = true;
                                     isDowned : bool = false;
                                     isInVehicle : bool = false)
    if isAlive && !isDowned && !isInVehicle && is_teams_friendly(team, bomb_site__plantingTeam)
      start_planting(evt.requesterEid, bomb_site__timeToPlant, bomb_site__operator, bomb_site__plantProgressDeltaPerSec)


[es(tag=server)]
def on_planted_plant_site_use(evt : CmdUse;
                              active : bool;
                              plant_site__destroyed : bool;
                              bomb_site__plantingTeam : int;
                              bomb_site__timeToDefuse : float;
                              bomb_site__isBombPlanted : bool;
                              var bomb_site__operator : EntityId&;
                              var bomb_site__defuseProgressDeltaPerSec : float&)
  if !active || plant_site__destroyed || !!bomb_site__operator || !bomb_site__isBombPlanted
    return
  query(evt.requesterEid) <| $ [es] (team : int;
                                     isAlive : bool = true;
                                     isDowned : bool = false;
                                     isInVehicle : bool = false)
    let isDefuseTeam = team != bomb_site__plantingTeam && team != TEAM_UNASSIGNED && bomb_site__plantingTeam != TEAM_UNASSIGNED
    if isAlive && !isDowned && !isInVehicle && isDefuseTeam
      bomb_site__operator = evt.requesterEid
      bomb_site__defuseProgressDeltaPerSec = safeinv(bomb_site__timeToDefuse)


[es(tag=server, REQUIRE=human_plant_site__siteEid)]
def plant_site_stop_interact(evt : CmdStopInteractPlantSite;
                             eid aka human_eid : EntityId)
  query() <| $ [es(REQUIRE=plantSite)] (var bomb_site__operator : EntityId&;
                                        var bomb_site__plantProgressDeltaPerSec : float&;
                                        var bomb_site__defuseProgressDeltaPerSec : float&;
                                        var bomb_site__plantProgress : float&;
                                        var bomb_site__defuseProgress : float&)
    if bomb_site__operator == human_eid
      stop_operator(bomb_site__operator, bomb_site__plantProgressDeltaPerSec, bomb_site__defuseProgressDeltaPerSec,
                    bomb_site__plantProgress, bomb_site__defuseProgress)


[es(tag=server, no_order)]
def plant_site_check_operator(info : UpdateStageInfoAct;
                              transform : float3x4;
                              bomb_site__maxDist : float;
                              var bomb_site__operator : EntityId&;
                              var bomb_site__plantProgressDeltaPerSec : float&;
                              var bomb_site__defuseProgressDeltaPerSec : float&;
                              var bomb_site__plantProgress : float&;
                              var bomb_site__defuseProgress : float&)
  if !bomb_site__operator
    return
  let sitePos = transform[3]
  var isOperatorValid = false
  query(bomb_site__operator) <| $ [es] (isAlive : bool;
                                        isDowned : bool;
                                        isInVehicle : bool = false;
                                        transform aka operator_transform : float3x4)
    isOperatorValid = isAlive && !isDowned && !isInVehicle && length_sq(operator_transform[3] - sitePos) < square(bomb_site__maxDist)
  if !isOperatorValid
    stop_operator(bomb_site__operator, bomb_site__plantProgressDeltaPerSec, bomb_site__defuseProgressDeltaPerSec,
                  bomb_site__plantProgress, bomb_site__defuseProgress)


[es(tag=server, after=plant_site_check_operator, track=(active, bomb_site__operator, bomb_site__isBombPlanted, bomb_site__timeToExplosionLeft))]
def plant_site_track_bomb_ticking(evt : Event;
                                  active : bool;
                                  bomb_site__stopTimerWhenDefusing : bool;
                                  bomb_site__operator : EntityId;
                                  bomb_site__isBombPlanted : bool;
                                  bomb_site__timeToExplosionLeft : float;
                                  var bomb_site__isBombTicking : bool&)
  bomb_site__isBombTicking = active && bomb_site__isBombPlanted && bomb_site__timeToExplosionLeft >= 0.0 && (!bomb_site__stopTimerWhenDefusing || !bomb_site__operator)


[es(tag=server, after=plant_site_track_bomb_ticking)]
def plant_site_ticking(info : UpdateStageInfoAct;
                       transform : float3x4;
                       bomb_site__isBombTicking : bool;
                       bomb_site__isBombPlanted : bool;
                       bomb_site__shellActivatorTemplate : string;
                       bomb_site__shellOffset : float3;
                       plant_site__planterEid : EntityId;
                       var plant_site__riEid : EntityId&;
                       var bomb_site__timeToExplosionLeft : float&;
                       var plant_site__destroyed : bool&;
                       var active : bool&)
  if !bomb_site__isBombTicking || !bomb_site__isBombPlanted
    return
  bomb_site__timeToExplosionLeft -= info.dt
  if bomb_site__timeToExplosionLeft < 0.0
    detonate_bomb(transform, bomb_site__shellActivatorTemplate, bomb_site__shellOffset, plant_site__planterEid,
                  plant_site__riEid, plant_site__destroyed, active)


[es(tag=server, track=bomb_site__isBombTicking)]
def plant_site_save_bomb_ticking_timings_for_clients(evt : Event;
                                                     bomb_site__isBombTicking : bool;
                                                     bomb_site__timeToExplosionLeft : float;
                                                     var bomb_site__explosionTimeEnd : float&;
                                                     var bomb_site__explosionTimerPausedAtTime : float&)
  if bomb_site__isBombTicking
    bomb_site__explosionTimerPausedAtTime = -1.0
    bomb_site__explosionTimeEnd = get_sync_time() + bomb_site__timeToExplosionLeft
  else
    bomb_site__explosionTimerPausedAtTime = bomb_site__timeToExplosionLeft
    bomb_site__explosionTimeEnd = -1.0


[es(tag=server, after=plant_site_check_operator, track=(active, bomb_site__operator, bomb_site__isBombPlanted))]
def plant_site_track_planting_progress_allowed(evt : Event;
                                               active : bool;
                                               bomb_site__operator : EntityId;
                                               bomb_site__isBombPlanted : bool;
                                               var bomb_site__isPlantingOrReseting : bool&)
  bomb_site__isPlantingOrReseting = active && !bomb_site__isBombPlanted && !!bomb_site__operator


[es(tag=server, after=plant_site_track_planting_progress_allowed)]
def plant_site_planting(info : UpdateStageInfoAct;
                        bomb_site__isPlantingOrReseting : bool;
                        bomb_site__timeToExplosion : float;
                        var bomb_site__isBombPlanted : bool&;
                        var bomb_site__plantProgressDeltaPerSec : float&;
                        var plant_site__planterEid : EntityId&;
                        var bomb_site__operator : EntityId&;
                        var bomb_site__plantProgress : float&;
                        var bomb_site__timeToExplosionLeft : float&)
  if !bomb_site__isPlantingOrReseting
    return
  bomb_site__plantProgress += bomb_site__plantProgressDeltaPerSec > 0.0 ? bomb_site__plantProgressDeltaPerSec * info.dt : 1.0
  if bomb_site__plantProgress >= 1.0
    activate_bomb(bomb_site__timeToExplosion, plant_site__planterEid, bomb_site__operator, bomb_site__isBombPlanted,
                  bomb_site__plantProgressDeltaPerSec, bomb_site__timeToExplosionLeft)
  bomb_site__plantProgress = clamp(bomb_site__plantProgress, 0.0, 1.0)


[es(tag=server, track=bomb_site__isPlantingOrReseting)]
def plant_site_save_planting_timings_for_clients(evt : Event;
                                                 bomb_site__isPlantingOrReseting : bool;
                                                 bomb_site__plantProgress : float;
                                                 bomb_site__timeToPlant : float;
                                                 var bomb_site__plantedTimeEnd : float&;
                                                 var bomb_site__plantProgressPausedAt : float&)
  if bomb_site__isPlantingOrReseting
    bomb_site__plantProgressPausedAt = -1.0
    bomb_site__plantedTimeEnd = get_sync_time() + bomb_site__timeToPlant * (1.0 - bomb_site__plantProgress)
  else
    bomb_site__plantProgressPausedAt = bomb_site__plantProgress
    bomb_site__plantedTimeEnd = -1.0


[es(tag=server, after=plant_site_check_operator, track=(active, bomb_site__operator, bomb_site__isBombPlanted, bomb_site__defuseProgress))]
def plant_site_track_defusing_progress_allowed(evt : Event;
                                               active : bool;
                                               bomb_site__defuseProgress : float;
                                               bomb_site__operator : EntityId;
                                               bomb_site__isBombPlanted : bool;
                                               var bomb_site__isDefusing : bool&)
  bomb_site__isDefusing = active && bomb_site__isBombPlanted && !!bomb_site__operator && bomb_site__defuseProgress < 1.0


[es(tag=server, after=plant_site_track_defusing_progress_allowed, before=plant_site_ticking)]
def plant_site_defusing(info : UpdateStageInfoAct;
                        bomb_site__isDefusing : bool;
                        var bomb_site__defuseProgressDeltaPerSec : float&;
                        var bomb_site__timeToExplosionLeft : float&;
                        var bomb_site__isBombPlanted : bool&;
                        var bomb_site__operator : EntityId&;
                        var bomb_site__plantProgressDeltaPerSec : float&;
                        var bomb_site__plantProgress : float&;
                        var bomb_site__plantProgressPausedAt : float&;
                        var bomb_site__defuseProgress : float&;
                        var bomb_site__defuseProgressPausedAt : float&;
                        var plant_site__planterEid : EntityId&)
  if !bomb_site__isDefusing
    return
  bomb_site__defuseProgress += bomb_site__defuseProgressDeltaPerSec > 0.0 ? bomb_site__defuseProgressDeltaPerSec * info.dt : 1.0
  if bomb_site__defuseProgress >= 1.0
    defuse_bomb(bomb_site__isBombPlanted, bomb_site__defuseProgress, bomb_site__defuseProgressPausedAt, bomb_site__defuseProgressDeltaPerSec,
                bomb_site__timeToExplosionLeft, plant_site__planterEid, bomb_site__operator, bomb_site__plantProgress,
                bomb_site__plantProgressPausedAt, bomb_site__plantProgressDeltaPerSec)
  bomb_site__defuseProgress = clamp(bomb_site__defuseProgress, 0.0, 1.0)


[es(tag=server, track=bomb_site__isDefusing)]
def plant_site_save_defuse_timings_for_clients(evt : Event;
                                               bomb_site__isDefusing : bool;
                                               bomb_site__defuseProgress : float;
                                               bomb_site__timeToDefuse : float;
                                               var bomb_site__defusedTimeEnd : float&;
                                               var bomb_site__defuseProgressPausedAt : float&)
  if bomb_site__isDefusing
    bomb_site__defuseProgressPausedAt = -1.0
    bomb_site__defusedTimeEnd = get_sync_time() + bomb_site__timeToDefuse * (1.0 - bomb_site__defuseProgress)
  else
    bomb_site__defuseProgressPausedAt = bomb_site__defuseProgress
    bomb_site__defusedTimeEnd = -1.0


[es(tag=server, track=(bomb_site__operator, bomb_site__isDefusing, bomb_site__plantedTimeEnd, bomb_site__defusedTimeEnd))]
def plant_site_update_operator_mirror(evt : Event;
                                      eid : EntityId;
                                      bomb_site__operator : EntityId;
                                      bomb_site__isDefusing : bool;
                                      bomb_site__plantedTimeEnd : float;
                                      bomb_site__defusedTimeEnd : float;
                                      bomb_site__timeToPlant : float;
                                      bomb_site__timeToDefuse : float;
                                      var plant_site__mirrorOperator : EntityId&)
  if plant_site__mirrorOperator != bomb_site__operator
    clear_operator_mirror(plant_site__mirrorOperator, eid)
    plant_site__mirrorOperator = bomb_site__operator
  if !bomb_site__operator
    return
  let endTime = bomb_site__isDefusing ? bomb_site__defusedTimeEnd : bomb_site__plantedTimeEnd
  let duration = bomb_site__isDefusing ? bomb_site__timeToDefuse : bomb_site__timeToPlant
  set_operator_mirror(bomb_site__operator, eid, endTime, duration, bomb_site__isDefusing)


[es(tag=server, no_order)]
def plant_site_deactivate_on_rendinst_destroyed(info : UpdateStageInfoAct;
                                                plant_site__riEid : EntityId;
                                                plant_site__destroyed : bool;
                                                var active : bool&;
                                                var bomb_site__operator : EntityId&;
                                                var bomb_site__plantProgressDeltaPerSec : float&;
                                                var bomb_site__defuseProgressDeltaPerSec : float&;
                                                var bomb_site__plantProgress : float&;
                                                var bomb_site__defuseProgress : float&)
  if !active || plant_site__destroyed
    return
  query(plant_site__riEid) <| $ [es] (ri_extra__destroyed : bool)
    if ri_extra__destroyed
      active = false
      stop_operator(bomb_site__operator, bomb_site__plantProgressDeltaPerSec, bomb_site__defuseProgressDeltaPerSec,
                    bomb_site__plantProgress, bomb_site__defuseProgress)


[es(tag=server, on_disappear)]
def plant_site_on_disappear(evt : Event;
                            eid : EntityId;
                            plant_site__riEid : EntityId;
                            plant_site__aiZoneEid : EntityId;
                            plant_site__mirrorOperator : EntityId)
  destroyEntity(plant_site__aiZoneEid)
  destroyEntity(plant_site__riEid)
  clear_operator_mirror(plant_site__mirrorOperator, eid)


def private defending_team(planting_team : int) : int
  return planting_team == 1 ? 2 : planting_team == 2 ? 1 : TEAM_UNASSIGNED


[es(tag=server, on_appear)]
def plant_site_spawn_ai_zone(evt : Event;
                             eid : EntityId;
                             transform : float3x4;
                             plant_site__name : string;
                             plant_site__zoneRadius : float;
                             active : bool;
                             plant_site__destroyed : bool;
                             bomb_site__isBombPlanted : bool;
                             bomb_site__plantingTeam : int;
                             var plant_site__aiZoneEid : EntityId&)
  if !!plant_site__aiZoneEid
    return
  plant_site__aiZoneEid = createEntity("plant_site_ai_zone") <| $(var init : ComponentsInitializer)
    set(init, "transform", transform)
    set(init, "capture_zone__name", plant_site__name)
    set(init, "sphere_zone__radius", plant_site__zoneRadius)
    set(init, "plant_site_ai_zone__siteEid", eid)
    set(init, "active", active && !plant_site__destroyed)
    set(init, "capzone__owningTeam", bomb_site__isBombPlanted ? bomb_site__plantingTeam : defending_team(bomb_site__plantingTeam))


[es(tag=server, REQUIRE=plantSite, track=(active, plant_site__destroyed, bomb_site__isBombPlanted))]
def plant_site_update_ai_zone(evt : Event;
                              active : bool;
                              plant_site__destroyed : bool;
                              bomb_site__isBombPlanted : bool;
                              bomb_site__plantingTeam : int;
                              plant_site__aiZoneEid : EntityId)
  let isZoneActive = active && !plant_site__destroyed
  let owningTeam = bomb_site__isBombPlanted ? bomb_site__plantingTeam : defending_team(bomb_site__plantingTeam)
  query(plant_site__aiZoneEid) <| $ [es] (var active aka zone_active : bool&;
                                          var capzone__owningTeam : int&;
                                          var capzone__capTeam : int&)
    zone_active = isZoneActive
    capzone__owningTeam = owningTeam
    capzone__capTeam = TEAM_UNASSIGNED


[es(tag=server, no_order, REQUIRE=plantSiteAiZone)]
def plant_site_ai_zone_presence(info : UpdateStageInfoAct;
                                transform : float3x4;
                                active : bool;
                                sphere_zone__radius : float;
                                plant_site_ai_zone__updatePeriod : float;
                                var plant_site_ai_zone__nextUpdateAt : float&;
                                var teamPresence : Object&)
  if !active || info.curTime < plant_site_ai_zone__nextUpdateAt
    return
  plant_site_ai_zone__nextUpdateAt = info.curTime + plant_site_ai_zone__updatePeriod
  let zonePos = transform[3]
  let radiusSq = square(sphere_zone__radius)
  var teamHumans : array<array<EntityId>>
  teamHumans |> resize(2)
  for_each_entity_in_grid(ecs_hash("humans"), BSphere3(zonePos, sphere_zone__radius), GridEntCheck.BOUNDING) <| $(visitorEid : EntityId)
    query(visitorEid) <| $ [es(REQUIRE=human)] (transform aka human_transform : float3x4;
                                                team : int;
                                                isAlive : bool = true)
      if isAlive && (team == 1 || team == 2) && length_sq(human_transform[3] - zonePos) <= radiusSq
        push(teamHumans[team - 1], visitorEid)
  for zoneTeam in range(1, 3)
    teamPresence |> push_to_object("{zoneTeam}") <| $(var arr : Array)
      for humanEid in teamHumans[zoneTeam - 1]
        push(arr, humanEid)
