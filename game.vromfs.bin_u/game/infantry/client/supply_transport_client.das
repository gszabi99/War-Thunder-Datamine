require ecs
require math.base
require Dacoll
require AnimV20
require GeomNodeTree
require DagorDataBlock
require Unit
require hud
require %game.events
require %appGame.infantry.es.fortification_action_common
require %appGame.infantry.es.supply_transport_common
require %appGame.wt_events

[es(tag=gameClient, REQUIRE=hero, REQUIRE_NOT=deadEntity,
    after=(hero_human_pre_use_object_es, hero_human_use_current_vehicle_object_es, hero_human_use_stationary_gun_object_es,
           hero_human_use_door_object_es, hero_human_use_human_object_es, hero_human_use_downed_human_object_es, find_bilding_action_target),
    before=human_use_action_es)]
def hero_human_use_supply_laptop_es(info : ParallelUpdateFrameDelayed;
                                    transform aka hero_transform : float3x4;
                                    team aka hero_team : int;
                                    bindedCamera : EntityId;
                                    animchar : AnimcharBaseComponent;
                                    human_use_object__useDist : float;
                                    human_supply_laptop__checkInterval : float;
                                    human_use_object__nodeId : int = 0;
                                    isInVehicle : bool = false;
                                    human_binocular__mode : bool = false;
                                    human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                                    var human_supply_laptop__nextCheckTime : float&;
                                    var human_supply_laptop__lastSelected : EntityId&;
                                    var human_use_object__selectedObject : EntityId&;
                                    var human_use_object__lookAtSelected : bool&)
  if human_use_object__selectedObject != INVALID_ENTITY_ID
    return
  if isInVehicle || human_binocular__mode || human_attached_gun__attachedGunEid != INVALID_ENTITY_ID
    human_supply_laptop__lastSelected = INVALID_ENTITY_ID
    return
  if info.curTime < human_supply_laptop__nextCheckTime
    if human_supply_laptop__lastSelected != INVALID_ENTITY_ID && doesEntityExist(human_supply_laptop__lastSelected)
      human_use_object__selectedObject = human_supply_laptop__lastSelected
      human_use_object__lookAtSelected = true
    return
  human_supply_laptop__nextCheckTime = info.curTime + human_supply_laptop__checkInterval
  human_supply_laptop__lastSelected = INVALID_ENTITY_ID

  let camTmRef = get_TMatrix(bindedCamera, "transform")
  if camTmRef == null
    return
  let camTm = *camTmRef
  let traceDir = camTm[2]
  let tracePos = (human_use_object__nodeId > 0 ? geomtree_getNodeWpos(*animchar.nodeTree, human_use_object__nodeId) : camTm[3])
  let heroPos = hero_transform[3]

  find_query() <| $ [es(REQUIRE=supplyLaptop)] (eid aka laptop_eid : EntityId;
                                                transform : float3x4;
                                                supply_laptop__team : int;
                                                supply_laptop__useDist : float;
                                                supply_laptop__approxRadius : float)
    let laptopPos = transform[3]
    if length_sq(laptopPos - heroPos) > square(supply_laptop__useDist)
      return false
    if supply_laptop__team != hero_team
      return false
    let traceLen = max(human_use_object__useDist, supply_laptop__useDist)
    if !test_segment_sphere_intersection_nonblocking(tracePos, tracePos + traceDir * traceLen, laptopPos, square(supply_laptop__approxRadius))
      return false
    let checkDist = max(length(laptopPos - tracePos) - supply_laptop__approxRadius - 0.1, 0.0)
    let checkDir = normalize(laptopPos - tracePos)
    if checkDist > 0.0 && rayhit_normalized(tracePos, checkDir, checkDist, ETF_DEFAULT, -1)
      return false
    human_use_object__selectedObject = laptop_eid
    human_use_object__lookAtSelected = true
    human_supply_laptop__lastSelected = laptop_eid
    return true

[es(tag=gameClient, REQUIRE=hero, REQUIRE_NOT=isReplayObserved, on_appear, track=human_use_object__selectedObject)]
def human_supply_laptop_hint_es(evt : Event;
                                human_use_object__selectedObject : EntityId)
  let nodeEid = get_Eid(human_use_object__selectedObject, "supply_laptop__nodeEid") ?? INVALID_ENTITY_ID
  using() <| $(var eventData : DataBlock)
    hud_notify_script(nodeEid == INVALID_ENTITY_ID ? "hint:supply_buy_transport:hide" : "hint:supply_buy_transport:show", eventData)

[es(tag=gameClient, on_disappear, REQUIRE=(hero, human_use_object__selectedObject), REQUIRE_NOT=isReplayObserved)]
def human_supply_laptop_hint_hide_es(evt : Event)
  using() <| $(var eventData : DataBlock)
    hud_notify_script("hint:supply_buy_transport:hide", eventData)

[es(tag=gameClient, REQUIRE=heroVehicle, REQUIRE_NOT=isReplayObserved)]
def supply_transport_hint_es(evt : EventSupplyTransportHint;
                             supply_transport__points : float)
  using() <| $(var eventData : DataBlock)
    if evt.hint == int(SupplyTransportHint.LOADED)
      hud_notify_script("hint:supply/loaded", eventData)
    elif evt.hint == int(SupplyTransportHint.UNLOADED)
      hud_notify_script("hint:supply/unloaded", eventData)
    elif evt.hint == int(SupplyTransportHint.UNDER_FIGHT)
      hud_notify_script("hint:supply/under_fight", eventData)
    elif evt.hint == int(SupplyTransportHint.NODE_FULL)
      set(eventData, "points", int(supply_transport__points))
      hud_notify_script("hint:supply/node_full", eventData)

[es(tag=gameClient, REQUIRE=watchedByPlr, REQUIRE_NOT=isReplayObserved)]
def supply_reward_hint_es(evt : EventSupplyReward)
  using() <| $(var eventData : DataBlock)
    set(eventData, "score", evt.score)
    if evt.kind == int(SupplyRewardKind.UNLOAD)
      hud_notify_script("hint:supply/reward_unload", eventData)
    elif evt.kind == int(SupplyRewardKind.RETURN)
      hud_notify_script("hint:supply/reward_return", eventData)
    elif evt.kind == int(SupplyRewardKind.DESTROY)
      hud_notify_script("hint:supply/reward_destroy", eventData)
    elif evt.kind == int(SupplyRewardKind.ESCORT)
      hud_notify_script("hint:supply/reward_escort", eventData)

[es(tag=gameClient, REQUIRE=(heroVehicle, supplyTransport), REQUIRE_NOT=isReplayObserved)]
def supply_transport_zone_track_es(info : ParallelUpdateFrameDelayed;
                                   unit__ref : UnitRef;
                                   supply_transport__standStillSpeed : float;
                                   supply_transport__clientZoneCheckPeriod : float;
                                   supply_transport__points : float;
                                   supply_transport__pointsCapacity : float;
                                   var supply_transport__nextZoneCheckAt : float&;
                                   var supply_transport__canLoad : bool&;
                                   var supply_transport__canUnload : bool&)
  let unit = unit__ref.unit
  if unit == null || unit.speed >= supply_transport__standStillSpeed
    supply_transport__canLoad = false
    supply_transport__canUnload = false
    supply_transport__nextZoneCheckAt = 0.0
    return
  if info.curTime < supply_transport__nextZoneCheckAt
    return
  supply_transport__nextZoneCheckAt = info.curTime + supply_transport__clientZoneCheckPeriod
  supply_transport__canLoad = false
  supply_transport__canUnload = false
  let team = int(unit.army)
  let pos = unit.pos.xz
  find_query() <| $ [es] (capzone__owningTeam : int;
                          supply_node__supplyTransportArea : string;
                          supply_node__points : float;
                          supply_node__maxPoints : float)
    if capzone__owningTeam != team || !in_area(supply_node__supplyTransportArea, pos)
      return false
    supply_transport__canLoad = supply_transport__points < supply_transport__pointsCapacity && supply_node__points > 0.0
    supply_transport__canUnload = supply_transport__points > 0.0 && supply_node__points < supply_node__maxPoints
    return true
