require ecs
require ecs.common
require ecs.safe
require math.base
require app
require net
require RendInst
require DagorMath
require %game.events

require %appGame.wt_events
require %appGame.infantry.es.riextra_damage_common
require Grid
require CollRes

def is_conflict_with_objects_in_grid(tm, box; exclude_eid : EntityId = INVALID_ENTITY_ID; base_collres : CollisionResource const? = null)
  var objectFound = false
  let buildingWorldBox = BBox3(tm[3], length(box.width))
  find_entity_in_grid(fixed_array(ecs_hash("humans"), ecs_hash("vehicles")), buildingWorldBox, GridEntCheck.BOUNDING) <| $(foundEid : EntityId)
    if foundEid == exclude_eid
      return false
    query(foundEid) <| $ [es] (collres : CollisionResource&;
                               transform : float3x4;
                               isAlive = false)
      if has(foundEid, "human") && !isAlive
        return
      let colBox = collres.vFullBBox
      let colBoxMin = colBox.bmin.xyz
      let colBoxMax = colBox.bmax.xyz
      let colBbox3 = BBox3(colBoxMin, colBoxMax)
      objectFound = check_bbox3_intersection(box, tm, colBbox3, transform)
      if objectFound && base_collres != null && !has(foundEid, "building__simplifiedCollisionCheck")
        var intersectPoint : float3
        objectFound = test_collres_intersection(collres, transform, *base_collres, tm, intersectPoint, intersectPoint, true)
    return objectFound
  return objectFound


[es(tag=server, track=itemContainer)]
def mining_wall_track_bombs_in_inventory(evt : Event;
                                         eid : EntityId;
                                         itemContainer : EidList;
                                         human_mining_wall__autospawnBombTemplate : string;
                                         var human_mining_wall__bombEid : EntityId&)
  human_mining_wall__bombEid = INVALID_ENTITY_ID
  for itemEid in itemContainer
    if has(itemEid, "wallBomb")
      human_mining_wall__bombEid = itemEid
      return

  
  human_mining_wall__bombEid = createEntity(human_mining_wall__autospawnBombTemplate) <| $(var init : ComponentsInitializer)
    set(init, "item__lastOwner", eid)
    set(init, "item__ownerEid", eid)


[es(tag=gameClient, track=human_mining_wall__isContinuePlantingAvailable)]
def mining_wall_stop_planting(evt : Event;
                              eid : EntityId;
                              human_mining_wall__isContinuePlantingAvailable : bool)
  if !human_mining_wall__isContinuePlantingAvailable
    send_net_event(eid, CmdStopPlantingMineOnWall())


[es]
def mining_wall_on_start_plant_client(evt : CmdStartPlantingMineOnWall;
                                      isDowned : bool;
                                      human_mining_wall__plantingDuration : float;
                                      var human_mining_wall__plantingStartTime : float&;
                                      var human_mining_wall__plantingEndTime : float&)
  if isDowned
    return

  human_mining_wall__plantingStartTime = get_sync_time()
  human_mining_wall__plantingEndTime = human_mining_wall__plantingStartTime + human_mining_wall__plantingDuration


[es(tag=server)]
def mining_wall_on_start_plant_server(evt : CmdStartPlantingMineOnWall;
                                      isDowned : bool;
                                      var human_mining_wall__reqPlantingPos : float3&;
                                      var human_mining_wall__reqPlantingNorm : float3&;
                                      var human_mining_wall__wallEid : EntityId&)
  if isDowned
    return

  human_mining_wall__reqPlantingPos = evt.pos
  human_mining_wall__reqPlantingNorm = evt.norm
  human_mining_wall__wallEid = evt.wallEid


[es(on_disappear, REQUIRE=destroyable_wall)]
def stop_acting_on_destoyed_wall(evt : Event; eid aka wall_eid : EntityId)
  query() <| $ [es] (human_mining_wall__wallEid : EntityId;
                     var human_mining_wall__plantingStartTime : float&;
                     var human_mining_wall__plantingEndTime : float&;
                     var human_mining_wall__reassemblingStartTime : float&;
                     var human_mining_wall__reassemblingEndTime : float&)
    if wall_eid == human_mining_wall__wallEid
      
      human_mining_wall__plantingStartTime = -1.0
      human_mining_wall__plantingEndTime = -1.0
      human_mining_wall__reassemblingStartTime = -1.0
      human_mining_wall__reassemblingEndTime = -1.0


def private stop_mining_wall_planting(var human_mining_wall__plantingStartTime : float&;
                                      var human_mining_wall__plantingEndTime : float&)
  human_mining_wall__plantingStartTime = -1.0
  human_mining_wall__plantingEndTime = -1.0


[es]
def mining_wall_on_stop_plant(evt : CmdStopPlantingMineOnWall;
                              var human_mining_wall__plantingStartTime : float&;
                              var human_mining_wall__plantingEndTime : float&)
  stop_mining_wall_planting(human_mining_wall__plantingStartTime, human_mining_wall__plantingEndTime)


[es(tag=netClient, no_order)]
def mining_wall_stop_planting_on_timer_client(info : UpdateStageInfoAct;
                                              var human_mining_wall__plantingStartTime : float&;
                                              var human_mining_wall__plantingEndTime : float&;
                                              human_mining_wall__bombEid : EntityId)
  if human_mining_wall__plantingStartTime < 0.0 || !human_mining_wall__bombEid
    return
  if info.curTime < human_mining_wall__plantingEndTime
    return

  stop_mining_wall_planting(human_mining_wall__plantingStartTime, human_mining_wall__plantingEndTime)


[es(tag=server, no_order)]
def mining_wall_planting_on_update(info : UpdateStageInfoAct;
                                   eid : EntityId;
                                   human__aimTm : float3x4;
                                   human_mining_wall__plantingMaxDist : float;
                                   human_mining_wall__bufferDistance : float;
                                   human_mining_wall__bombEid : EntityId;
                                   human_mining_wall__wallEid : EntityId;
                                   human_mining_wall__plantingStartTime : float;
                                   human_mining_wall__plantingEndTime : float;
                                   human_mining_wall__reqPlantingPos : float3;
                                   human_mining_wall__reqPlantingNorm : float3;
                                   var itemContainer : EidList)
  if human_mining_wall__plantingStartTime < 0.0 || !human_mining_wall__bombEid
    return

  if info.curTime < human_mining_wall__plantingEndTime
    return

  send_net_event(eid, CmdStopPlantingMineOnWall())

  if distance_sq(human__aimTm[3], human_mining_wall__reqPlantingPos) >= square(human_mining_wall__plantingMaxDist + human_mining_wall__bufferDistance)
    return

  query(human_mining_wall__bombEid) <| $ [es] (wall_bomb__placeableTemplate : string; wall_bomb__explosionDelay : float)
    let bombIdx = find_index(itemContainer, human_mining_wall__bombEid)
    if bombIdx >= 0
      erase(itemContainer, bombIdx)
    destroyEntity(human_mining_wall__bombEid)

    createEntity(wall_bomb__placeableTemplate) <| $(init)
      var tm = IDENT_TM
      if length_sq(human_mining_wall__reqPlantingNorm) > FLT_EPSILON
        make_tm(dir_to_quat(human_mining_wall__reqPlantingNorm), tm)
      tm[3] = human_mining_wall__reqPlantingPos

      set(init, "transform", tm)
      set(init, "wall_bomb_planted__ownerEid", eid)
      set(init, "wall_bomb_planted__explosionAtTime", get_sync_time() + wall_bomb__explosionDelay)
      set(init, "wall_bomb__wallEid", human_mining_wall__wallEid)

[es(tag=server, on_appear)]
def mining_wall_bomb_planted_ai_reaction(evt : Event;
                                         wall_bomb_planted__ownerEid : EntityId)
  let planterEid = wall_bomb_planted__ownerEid
  query(planterEid) <| $ [es] (squad_member__squad aka planter_squad_member__squad : EntityId)
    query() <| $ [es] (eid aka other_eid : EntityId; squad_member__squad aka other_squad_member__squad : EntityId; beh_tree__enabled : bool)
      if beh_tree__enabled && other_eid != planterEid && planter_squad_member__squad == other_squad_member__squad
        query(other_eid) <| $ [es] (var squad_member__makeReaction : das_string&)
          squad_member__makeReaction := "leader_redirect"


[es(tag=gameClient, track=human_mining_wall__plantingStartTime)]
def mining_wall_update_plant_animation(evt : Event;
                                       eid : EntityId;
                                       human_mining_wall__plantingStartTime : float;
                                       human_mining_wall__plantAnimTemplate : string;
                                       var human_mining_wall__plantAnimAffectEid : EntityId&)
  destroyEntity(human_mining_wall__plantAnimAffectEid)

  if human_mining_wall__plantingStartTime > 0.0
    human_mining_wall__plantAnimAffectEid = createEntity(human_mining_wall__plantAnimTemplate) <| $(var init : ComponentsInitializer)
      set(init, "game_effect__attachedTo", eid)


[es(tag=server, no_order)]
def wall_bomb_update_explosion_timer(info : UpdateStageInfoAct;
                                     eid : EntityId;
                                     transform aka wall_transform : float3x4;
                                     wall_bomb__shellActivator : string;
                                     wall_bomb__explosionImpulseMult : float;
                                     wall_bomb__wallEid : EntityId;
                                     wall_bomb_planted__ownerEid : EntityId;
                                     wall_bomb_planted__explosionAtTime : float)
  if info.curTime >= wall_bomb_planted__explosionAtTime
    query(wall_bomb__wallEid) <| $ [es] (transform aka bomb_transform : float3x4;
                                         ri_extra : RiExtraComponent;
                                         var destr_ri__nextTemplate : das_string&)
      let templ = getTemplateByName(string(destr_ri__nextTemplate))
      if templ != null
        let nextTemplate = getTemplateComponent(*templ, "destr_ri__nextTemplate") ?? ""
        if nextTemplate != ""
          destr_ri__nextTemplate := nextTemplate
      var impulse = bomb_transform[3] - wall_transform[3]
      impulse.y = 0.f
      damage_ri_on_server(ri_extra.handle, FLT_MAX, wall_transform[3], wall_bomb__explosionImpulseMult * normalize(impulse), get_sync_time(), eid)

    destroyEntity(eid)
    createEntity(wall_bomb__shellActivator) <| $(init)
      set(init, "transform", transform)
      set(init, "ownerEid", wall_bomb_planted__ownerEid)

[es(tag=server, on_disappear, REQUIRE=destroyable_wall)]
def on_destroyable_wall_destroy_es(evt : Event;
                                   eid aka wall_eid : EntityId)
  query() <| $ [es(REQUIRE=wallBomb)] (eid aka bomb_eid : EntityId;
                                       transform : float3x4;
                                       wall_bomb__wallEid : EntityId;
                                       wall_bomb__shellActivator : string)
    if wall_bomb__wallEid == wall_eid
      destroyEntity(bomb_eid)
      createEntity(wall_bomb__shellActivator) <| $(init)
        set(init, "transform", transform)

[es(tag=gameClient, on_appear)]
def planted_wall_bomb_on_appear(evt : Event;
                                wall_bomb__explosionDelay : float;
                                wall_bomb_planted__ownerEid : EntityId;
                                wall_bomb_planted__explosionAtTime : float)
  query(wall_bomb_planted__ownerEid) <| $ [es] (var human_mining_wall__curPlantedExplosionAtTime : float&;
                                                var human_mining_wall__curPlantedExplosionDelay : float&)
    human_mining_wall__curPlantedExplosionAtTime = wall_bomb_planted__explosionAtTime
    human_mining_wall__curPlantedExplosionDelay = wall_bomb__explosionDelay


[es(tag=gameClient, on_disappear)]
def planted_wall_bomb_on_disappear(evt : Event;
                                   wall_bomb_planted__ownerEid : EntityId)
  query(wall_bomb_planted__ownerEid) <| $ [es] (var human_mining_wall__curPlantedExplosionAtTime : float&;
                                                var human_mining_wall__curPlantedExplosionDelay : float&)
    human_mining_wall__curPlantedExplosionAtTime = -1.0
    human_mining_wall__curPlantedExplosionDelay = -1.0


[es(tag=gameClient, track=human_mining_wall__isContinueReassemblingAvailable)]
def mining_wall_stop_reassembling(evt : Event;
                                  eid : EntityId;
                                  human_mining_wall__isContinueReassemblingAvailable : bool)
  if !human_mining_wall__isContinueReassemblingAvailable
    send_net_event(eid, CmdStopReassemblingWall(reassembled = false))










[es]
def mining_wall_on_start_reassembling(evt : CmdStartReassemblingWall;
                                      isDowned : bool;
                                      human_mining_wall__reassemblingDuration : float;
                                      var human_mining_wall__reassemblingStartTime : float&;
                                      var human_mining_wall__reassemblingEndTime : float&;
                                      var human_mining_wall__reassemblingEntityId : EntityId&;
                                      var human_mining_wall__reassemblingPosition : float3&)
  if isDowned
    return

  human_mining_wall__reassemblingStartTime = get_sync_time()
  human_mining_wall__reassemblingEndTime = human_mining_wall__reassemblingStartTime + human_mining_wall__reassemblingDuration
  human_mining_wall__reassemblingEntityId = evt.wallEid
  human_mining_wall__reassemblingPosition = evt.position
  query(evt.wallEid) <| $ [es] (var ri_extra__destrFx : bool&)
    ri_extra__destrFx = false


def private stop_mining_wall_reassembling(reassembled : bool;
                                          human_mining_wall__reassemblingEntityId : EntityId;
                                          var human_mining_wall__reassemblingStartTime : float&;
                                          var human_mining_wall__reassemblingEndTime : float&)
  human_mining_wall__reassemblingStartTime = -1.0
  human_mining_wall__reassemblingEndTime = -1.0
  if !reassembled
    query(human_mining_wall__reassemblingEntityId) <| $ [es] (var ri_extra__destrFx : bool&)
      ri_extra__destrFx = true


[es]
def mining_wall_on_stop_reassembling(evt : CmdStopReassemblingWall;
                                     human_mining_wall__reassemblingEntityId : EntityId;
                                     var human_mining_wall__reassemblingStartTime : float&;
                                     var human_mining_wall__reassemblingEndTime : float&)
  stop_mining_wall_reassembling(evt.reassembled, human_mining_wall__reassemblingEntityId, human_mining_wall__reassemblingStartTime, human_mining_wall__reassemblingEndTime)


[es(tag=netClient, no_order)]
def mining_wall_stop_reassembling_on_timer_client(info : UpdateStageInfoAct;
                                                  human_mining_wall__reassemblingEntityId : EntityId;
                                                  var human_mining_wall__reassemblingStartTime : float&;
                                                  var human_mining_wall__reassemblingEndTime : float&)
  if human_mining_wall__reassemblingStartTime < 0.0 || info.curTime < human_mining_wall__reassemblingEndTime
    return

  stop_mining_wall_reassembling(true, human_mining_wall__reassemblingEntityId, human_mining_wall__reassemblingStartTime, human_mining_wall__reassemblingEndTime)


def private make_reassembling_wall_check_bbox(bboxMin, bboxMax : float3; multiplier, additive : float2)
  let width = bboxMax.z - bboxMin.z
  let depth = bboxMax.x - bboxMin.x
  let height = 2.0

  let min = float3(-depth * multiplier.x - additive.x, 0.0, -width * multiplier.y - additive.y)
  let max = float3(depth * multiplier.x + additive.x, height, width * multiplier.y + additive.y)

  return BBox3(min, max)

[es(tag=server, no_order)]
def mining_wall_reassembling_on_update(info : UpdateStageInfoAct;
                                       eid : EntityId;
                                       human__aimTm : float3x4;
                                       human_mining_wall__reassemblingStartTime : float;
                                       human_mining_wall__reassemblingEndTime : float;
                                       human_mining_wall__reassemblingPosition : float3;
                                       human_mining_wall__plantingMaxDist : float;
                                       human_mining_wall__bufferDistance : float;
                                       var human_mining_wall__reassemblingEntityId : EntityId&)
  if human_mining_wall__reassemblingStartTime < 0.0 || info.curTime < human_mining_wall__reassemblingEndTime
    return

  if distance_sq(human__aimTm[3], human_mining_wall__reassemblingPosition) > square(human_mining_wall__plantingMaxDist + human_mining_wall__bufferDistance)
    return

  query(human_mining_wall__reassemblingEntityId) <| $ [es] (transform : float3x4;
                                                            destr_ri__prevTemplate : string;
                                                            ri_extra__bboxMin : float3;
                                                            ri_extra__bboxMax : float3;
                                                            var destr_ri__nextTemplate : das_string?)
    let bbox = make_reassembling_wall_check_bbox(ri_extra__bboxMin, ri_extra__bboxMax, float2(0.1, 0.2), float2(0.0))

    let occupied = is_conflict_with_objects_in_grid(transform, bbox)
    if occupied
      send_net_event(eid, CmdHeroLogEvent(event = "reassembling_wall", text = "reassemblingWallBlocked"))
      return

    send_net_event(eid, CmdStopReassemblingWall(reassembled = true))

    if destr_ri__nextTemplate != null
      *destr_ri__nextTemplate := ""
    destroyEntity(human_mining_wall__reassemblingEntityId)
    createEntity(destr_ri__prevTemplate) <| $(init)
      set(init, "transform", transform)
  human_mining_wall__reassemblingEntityId = INVALID_ENTITY_ID






[es(tag=netClient, before=mining_wall_stop_planting_on_timer_client)]
def create_fake_mining_wall(info : UpdateStageInfoAct;
                            human__aimTm : float3x4;
                            human_mining_wall__reassemblingStartTime : float;
                            human_mining_wall__reassemblingEndTime : float;
                            human_mining_wall__reassemblingPosition : float3;
                            human_mining_wall__plantingMaxDist : float;
                            human_mining_wall__bufferDistance : float;
                            var human_mining_wall__reassemblingEntityId : EntityId&)
  if human_mining_wall__reassemblingStartTime < 0.0 || info.curTime < human_mining_wall__reassemblingEndTime
    return

  if distance_sq(human__aimTm[3], human_mining_wall__reassemblingPosition) > square(human_mining_wall__plantingMaxDist + human_mining_wall__bufferDistance)
    return

  query(human_mining_wall__reassemblingEntityId) <| $ [es] (transform : float3x4;
                                                            destr_ri__prevTemplate : string;
                                                            ri_extra__bboxMin : float3;
                                                            ri_extra__bboxMax : float3)
    let bbox = make_reassembling_wall_check_bbox(ri_extra__bboxMin, ri_extra__bboxMax, float2(0.15, 0.25), float2(0.2, 0.2))

    let occupied = is_conflict_with_objects_in_grid(transform, bbox)
    if occupied
      return
    let templ = getTemplateByName(destr_ri__prevTemplate)
    if templ != null
      let riName = getTemplateComponent(*templ, "ri_extra__name") ?? ""
      if riName != ""
        createEntity("fake_destroyable_wall") <| $(init)
          set(init, "transform", transform)
          set(init, "ri_extra__name", riName)
          set(init, "fake_destroyable_wall__createdAtTime", info.curTime)
        human_mining_wall__reassemblingEntityId = INVALID_ENTITY_ID


[es(tag=netClient, on_appear, REQUIRE=destroyable_wall)]
def destroy_fake_mining_wall(evt : Event; transform aka new_transform : float3x4)
  query() <| $ [es(REQUIRE=fake_destroyable_wall)] (eid : EntityId; transform aka fake_transform : float3x4)
    if length(fake_transform[3] - new_transform[3]) < 0.01
      destroyEntity(eid)


[es(tag=netClient, no_order)]
def destroy_fake_mining_wall_after_time(info : ParallelUpdateFrameDelayed;
                                        eid : EntityId;
                                        fake_destroyable_wall__createdAtTime : float;
                                        fake_destroyable_wall__destroyTimeout : float)
  if info.curTime > fake_destroyable_wall__createdAtTime + fake_destroyable_wall__destroyTimeout
    destroyEntity(eid)
