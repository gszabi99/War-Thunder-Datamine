require ecs
require math.base
require Dacoll
require CollRes
require RendInst
require AnimV20
require GeomNodeTree
require DagorDataBlock
require hud
require %game.events
require %appGame.infantry.es.fortification_action_common
require %appGame.infantry.es.plant_site_common


def private trace_plant_site_rendinst(ri_eid : EntityId;
                                      trace_pos : float3;
                                      trace_dir : float3;
                                      trace_len : float;
                                      var out_hit_dist : float&) : bool
  var isHit = false
  query(ri_eid) <| $ [es] (ri_extra : RiExtraComponent; transform : float3x4)
    if ri_extra.handle == RIEX_HANDLE_NULL
      return
    let riCollres = get_ri_gen_extra_collres(int(handle_to_ri_type(ri_extra.handle)))
    if riCollres == null
      return
    var t = trace_len
    var norm : float3
    var matId : int
    if collres_traceray(*riCollres, transform, trace_pos, trace_dir, t, norm, matId)
      isHit = true
      out_hit_dist = t
  return isHit


[es(tag=gameClient, REQUIRE=hero, REQUIRE_NOT=deadEntity,
    after=(hero_human_pre_use_object_es, hero_human_use_current_vehicle_object_es, hero_human_use_stationary_gun_object_es,
           hero_human_use_door_object_es, hero_human_use_human_object_es, hero_human_use_downed_human_object_es, find_bilding_action_target),
    before=human_use_action_es)]
def hero_human_use_plant_site_es(info : ParallelUpdateFrameDelayed;
                                 eid aka hero_eid : EntityId;
                                 transform aka hero_transform : float3x4;
                                 bindedCamera : EntityId;
                                 animchar : AnimcharBaseComponent;
                                 human_use_object__useDist : float;
                                 human_plant_site__checkInterval : float;
                                 human_use_object__nodeId : int = 0;
                                 isInVehicle : bool = false;
                                 human_binocular__mode : bool = false;
                                 human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                                 var human_plant_site__nextCheckTime : float&;
                                 var human_plant_site__lastSelected : EntityId&;
                                 var human_use_object__selectedObject : EntityId&;
                                 var human_use_object__lookAtSelected : bool&)
  if human_use_object__selectedObject != INVALID_ENTITY_ID
    return
  if isInVehicle || human_binocular__mode || human_attached_gun__attachedGunEid != INVALID_ENTITY_ID
    human_plant_site__lastSelected = INVALID_ENTITY_ID
    return
  if info.curTime < human_plant_site__nextCheckTime
    if human_plant_site__lastSelected != INVALID_ENTITY_ID && doesEntityExist(human_plant_site__lastSelected)
      human_use_object__selectedObject = human_plant_site__lastSelected
      human_use_object__lookAtSelected = true
    return
  human_plant_site__nextCheckTime = info.curTime + human_plant_site__checkInterval
  human_plant_site__lastSelected = INVALID_ENTITY_ID

  let camTmRef = get_TMatrix(bindedCamera, "transform")
  if camTmRef == null
    return
  let camTm = *camTmRef
  let traceDir = camTm[2]
  let tracePos = (human_use_object__nodeId > 0 ? geomtree_getNodeWpos(*animchar.nodeTree, human_use_object__nodeId) : camTm[3])
  let heroPos = hero_transform[3]

  find_query() <| $ [es(REQUIRE=plantSite)] (eid : EntityId;
                                             transform : float3x4;
                                             plant_site__riEid : EntityId;
                                             bomb_site__maxDist : float;
                                             bomb_site__approxRadius : float)
    let sitePos = transform[3]
    if length_sq(sitePos - heroPos) > square(bomb_site__maxDist)
      return false
    if !can_plant_bomb(eid, hero_eid) && !can_defuse_bomb(eid, hero_eid)
      return false
    let traceLen = max(human_use_object__useDist, bomb_site__maxDist)
    var hitDist = 0.0
    var checkDir = traceDir
    var isHit = trace_plant_site_rendinst(plant_site__riEid, tracePos, traceDir, traceLen, hitDist)
    if !isHit && test_segment_sphere_intersection_nonblocking(tracePos, tracePos + traceDir * traceLen, sitePos, square(bomb_site__approxRadius))
      isHit = true
      checkDir = normalize(sitePos - tracePos)
      hitDist = length(sitePos - tracePos) - bomb_site__approxRadius
    if !isHit
      return false
    let checkDist = max(hitDist - 0.1, 0.0)
    if checkDist > 0.0 && rayhit_normalized(tracePos, checkDir, checkDist, ETF_DEFAULT, -1)
      return false
    human_use_object__selectedObject = eid
    human_use_object__lookAtSelected = true
    human_plant_site__lastSelected = eid
    return true


[es(tag=(render, gameClient), on_appear, track=human_use_object__selectedObject, REQUIRE=watchedByPlr, REQUIRE_NOT=isReplayObserved)]
def plant_site_hint_es(evt : Event;
                       eid aka hero_eid : EntityId;
                       human_use_object__selectedObject : EntityId)
  using() <| $(var eventData : DataBlock)
    hud_notify_script("hint:plant_site_plant:hide", eventData)
    hud_notify_script("hint:plant_site_defuse:hide", eventData)
    if !has(human_use_object__selectedObject, "plantSite")
      return
    if can_plant_bomb(human_use_object__selectedObject, hero_eid)
      hud_notify_script("hint:plant_site_plant:show", eventData)
    elif can_defuse_bomb(human_use_object__selectedObject, hero_eid)
      hud_notify_script("hint:plant_site_defuse:show", eventData)

[es(tag=(render, gameClient), on_disappear, REQUIRE=(watchedByPlr, human_use_object__selectedObject), REQUIRE_NOT=isReplayObserved)]
def plant_site_hint_hide_es(evt : Event)
  using() <| $(var eventData : DataBlock)
    hud_notify_script("hint:plant_site_plant:hide", eventData)
    hud_notify_script("hint:plant_site_defuse:hide", eventData)
