require ecs
require ecs.common
require math
require math.base
require DagorSystem
require DagorMath
require AnimV20
require GeomNodeTree
require strings
require CollRes
require %game.events

[export]
enum partType
  HULL = 0
  ENGINE = 1
  RADIATOR = 2
  TRACK = 3
  WHEEL = 4
  TANK_GUN_MAIN = 5
  TANK_GUN_MAIN_OVERHEATED = 6
  TANK_MG = 7
  HUMAN_HEAD = 8
  HUMAN_TORSO = 9
  HUMAN_LEG = 10
  HUMAN_HAND = 11
  HUMAN_GUN = 12

def updateHeatSourceTm(carTransform : float3x4;
                       collres : CollisionResource;
                       animchar : AnimcharBaseComponent;
                       collisionNodeId : int;
                       heatEid : EntityId)
  if heatEid == INVALID_ENTITY_ID
    return
  let node = collres_get_node(collres, collisionNodeId)
  if node != null
    var tm : float3x4
    collres_get_collision_node_tm(collres, collisionNodeId, carTransform, animchar.nodeTree, tm)
    let partModelBBox = (*node).modelBBox
    let pos = tm * partModelBBox.center
    query(heatEid) <| $ [es] (var transform : float3x4&;
                              heat_source__type : int)
      if (heat_source__type == int(partType.WHEEL))
        transform = carTransform
      else
        transform = tm
      transform[3] = pos

def destroyHeatSources(var listEId : EidList)
  for heatEid in listEId
    if heatEid == INVALID_ENTITY_ID
      continue
    destroyEntity(heatEid)

[es(tag=render)]
def update_heat_sources_pos_es(info : ParallelUpdateFrameDelayed;
                               heat_source__basicScale : float3;
                               heat_source__resultOffset : float3;
                               heat_source__prevCurrVelocityMixCoeff : float;
                               heat_source__inflateCoefMinMax : float2;
                               heat_source__velocityThresholdSq : float;
                               heat_source__shouldInflate : bool;
                               heat_source__inflateSpeed : float;
                               heat_source__temperature : float4;
                               var transform : float3x4&;
                               var heat_source__prevPos : float3&;
                               var heat_source__prevVel : float3&;
                               var heat_source__scale : float3&;
                               var heat_source__inflateCoef : float&)
  var velocityVector = clamp(((transform[3] - heat_source__prevPos) * safeinv(info.dt)), float3(-100.0f), float3(100.0f))
  velocityVector = heat_source__prevCurrVelocityMixCoeff * velocityVector + (1.0 - heat_source__prevCurrVelocityMixCoeff) * heat_source__prevVel
  if heat_source__shouldInflate
    if (length_sq(velocityVector) > heat_source__velocityThresholdSq)
      heat_source__inflateCoef = clamp(heat_source__inflateCoef + heat_source__inflateSpeed * info.dt, heat_source__inflateCoefMinMax.x, heat_source__inflateCoefMinMax.y)
    elif heat_source__temperature.y <= 0.001 
      heat_source__inflateCoef = clamp(heat_source__inflateCoef - heat_source__inflateSpeed * info.dt, heat_source__inflateCoefMinMax.x, heat_source__inflateCoefMinMax.y)
    heat_source__scale.x = heat_source__basicScale.x
    heat_source__scale.y = heat_source__basicScale.y * heat_source__inflateCoef
    heat_source__scale.z = heat_source__basicScale.z * heat_source__inflateCoef
  else
    heat_source__scale = heat_source__basicScale
  heat_source__prevVel = velocityVector
  heat_source__prevPos = transform[3]
  transform[3] += (velocityVector * info.dt)
  transform[3] += rotate(transform, heat_source__resultOffset)

[es(tag=render, on_appear, REQUIRE=attachedToParent, REQUIRE=human_gun_attached, after=human_gun_es)]
def human_gun_heat_source_init_es(evt : Event;
                                  item__weapType : string;
                                  animchar : AnimcharBaseComponent;
                                  var heat_source__humanGunEid : EntityId&;
                                  var heat_source__human_gun_offset : float3&;
                                  var heat_source__human_gun_size : float3&;
                                  var heat_source__human_gun_heating : float3&)
  if item__weapType == "melee" || item__weapType == "building_tool"
    return
  let nodeIndex = geomtree_findNodeIndex(*animchar.nodeTree, "gunFx_main")
  var heatEid = INVALID_ENTITY_ID
  if nodeIndex > 0
    var nodeWtm : float3x4
    geomtree_getNodeWtmScalar(*animchar.nodeTree, nodeIndex, nodeWtm)
    let partTemperature = float4(1, 0, 1, 0)
    let heatingTemp = getTemplateByName("weapon_heating_params_{item__weapType}")
    if heatingTemp != null
      heat_source__human_gun_offset = get_Point3(getTemplateComponent(*heatingTemp, "heat_source__human_gun_offset")) ?? heat_source__human_gun_offset
      heat_source__human_gun_size = get_Point3(getTemplateComponent(*heatingTemp, "heat_source__human_gun_size")) ?? heat_source__human_gun_size
      heat_source__human_gun_heating = get_Point3(getTemplateComponent(*heatingTemp, "heat_source__human_gun_heating")) ?? heat_source__human_gun_heating
    let rad = float3(1.0f)
    heatEid = createEntity("heat_source_item") <| $(var init : ComponentsInitializer)
      set(init, "transform", nodeWtm)
      set(init, "heat_source__basicRad", rad)
      set(init, "heat_source__basicScale", heat_source__human_gun_size)
      set(init, "heat_source__scale", heat_source__human_gun_size)
      set(init, "heat_source__rad", rad * heat_source__human_gun_size)
      set(init, "heat_source__offset", heat_source__human_gun_offset)
      set(init, "heat_source__temperature", partTemperature)
      set(init, "heat_source__type", int(partType.HUMAN_GUN))
  heat_source__humanGunEid = heatEid


[es(tag=render, on_disappear, REQUIRE=attachedToParent)]
def human_gun_heat_source_on_destroy_es(evt : Event;
                                        heat_source__humanGunEid : EntityId)
  destroyEntity(heat_source__humanGunEid)

[es(tag=render, REQUIRE=attachedToParent, after=human_gun_heat_source_init_es, before=update_heat_sources_pos_es)]
def human_gun_heat_source_update_es(info : ParallelUpdateFrameDelayed;
                                    animchar : AnimcharBaseComponent;
                                    heat_source__humanGunEid : EntityId;
                                    heat_source__human_gun_heating : float3)

  if heat_source__humanGunEid == INVALID_ENTITY_ID
    return
  var nodeWtm : float3x4
  geomtree_getNodeWtmScalar(*animchar.nodeTree, geomtree_findNodeIndex(*animchar.nodeTree, "gunFx_main"), nodeWtm)

  query(heat_source__humanGunEid) <| $ [es] (var transform : float3x4&;
                                             var heat_source__temperature : float4&)
    transform =  nodeWtm
    heat_source__temperature.y = max(0.f, heat_source__temperature.y + heat_source__human_gun_heating.z * 4.0 * info.dt)

[es(tag=render, on_appear, before=human_heat_source_init_es, after=dm_parts_es)]
def human_heat_source_prepare_init_es(evt : Event;
                                      human_heat_parts : Array;
                                      dm_parts__parts : Object;
                                      
                                      
                                      var heat_source__bodyCollisonNodeIds : IntList&;
                                      var heat_source__partTypes : IntList&)

  for partName in human_heat_parts
    let partStr = get_string(partName, "")
    let partInfo = get_ecs_object(dm_parts__parts[partStr])
    if partInfo != null
      let collisionNodeId = get_int(partInfo, "collNodeId") ?? -1
      let nodeType = get_string(partInfo, "type", "")

      var partT = partType.HULL
      if (nodeType == "head")
        partT = partType.HUMAN_HEAD
      elif (nodeType == "torso")
        partT = partType.HUMAN_TORSO
      elif (nodeType == "l_leg" || nodeType == "r_leg")
        partT = partType.HUMAN_LEG
      elif (nodeType == "l_hand" || nodeType == "r_hand")
        partT = partType.HUMAN_HAND

      push(heat_source__bodyCollisonNodeIds, collisionNodeId)
      push(heat_source__partTypes, int(partT))

[es(tag=render, on_appear, after=human_heat_source_prepare_init_es)]
def human_heat_source_init_es(evt : Event;
                              transform : float3x4;
                              collres : CollisionResource;
                              animchar : AnimcharBaseComponent;
                              heat_source__head_base_temp : float2;
                              heat_source__torso_base_temp : float2;
                              heat_source__hand_base_temp : float2;
                              heat_source__leg_base_temp : float2;
                              heat_source__bodyCollisonNodeIds : IntList;
                              heat_source__partTypes : IntList;
                              var heat_source__bodyEid : EidList&;
                              heat_source__head_size : float3;
                              heat_source__head_offset : float3;
                              heat_source__torso_size : float3;
                              heat_source__torso_offset : float3;
                              heat_source__leg_size : float3;
                              heat_source__leg_offset : float3;
                              heat_source__hand_size : float3;
                              heat_source__hand_offset : float3)
  for collisionNodeId,  partT in heat_source__bodyCollisonNodeIds, heat_source__partTypes
    let node = collres_get_node(collres, collisionNodeId)
    if node != null
      var tm : float3x4
      collres_get_collision_node_tm(collres, collisionNodeId, transform, animchar.nodeTree, tm)
      let partModelBBox = (*node).modelBBox
      var partTemperature = float2(3.0f, 36.0f) 
      let basicRad = partModelBBox.width
      var scale = float3(1.0f, 1.0f, 1.0f)
      var offset = float3(0.0f)
      if (partT == int(partType.HUMAN_HEAD))
        scale = heat_source__head_size
        offset = heat_source__head_offset
        partTemperature = heat_source__head_base_temp
      elif (partT == int(partType.HUMAN_TORSO))
        scale = heat_source__torso_size
        offset = heat_source__torso_offset
        partTemperature = heat_source__torso_base_temp
      elif (partT == int(partType.HUMAN_LEG))
        scale = heat_source__leg_size
        offset = heat_source__leg_offset
        partTemperature = heat_source__leg_base_temp
      elif (partT == int(partType.HUMAN_HAND))
        scale = heat_source__hand_size
        offset = heat_source__hand_offset
        partTemperature = heat_source__hand_base_temp
      var heatEid = INVALID_ENTITY_ID
      heatEid = createEntity("heat_source_item") <| $(var init : ComponentsInitializer)
        set(init, "transform", tm)
        set(init, "heat_source__basicRad", basicRad)
        set(init, "heat_source__rad", basicRad * scale)
        set(init, "heat_source__basicScale", scale)
        set(init, "heat_source__scale", scale)
        set(init, "heat_source__offset", offset)
        set(init, "heat_source__temperature", float4(partTemperature, partTemperature))
        set(init, "heat_source__type", partT)
      push(heat_source__bodyEid, heatEid)


[es(tag=render, REQUIRE=human, after=human_heat_source_init_es, before=update_heat_sources_pos_es)]
def human_heat_source_update_es(info : ParallelUpdateFrameDelayed;
                                transform : float3x4;
                                collres : CollisionResource;
                                animchar : AnimcharBaseComponent;
                                heat_source__bodyCollisonNodeIds : IntList;
                                heat_source__bodyEid : EidList)
  if empty(heat_source__bodyEid) || empty(heat_source__bodyCollisonNodeIds)
    return

  for collisionNodeId, heatEid in heat_source__bodyCollisonNodeIds, heat_source__bodyEid
    if heatEid == INVALID_ENTITY_ID
      continue
    updateHeatSourceTm(transform, collres, animchar, collisionNodeId, heatEid)

[es(tag=render, REQUIRE=human, before=human_heat_source_update_es)]
def human_temperature_update_es(info : ParallelUpdateFrameDelayed;
                                isAlive : bool;
                                heat_source__bodyEid : EidList;
                                heat_source__human_cooling_speed : float;
                                heat_source__head_base_temp : float2;
                                heat_source__torso_base_temp : float2;
                                heat_source__hand_base_temp : float2;
                                heat_source__leg_base_temp : float2)
  if !isAlive
    for heatEid in heat_source__bodyEid
      var basePartTemp = float2(3.0f, 36.6f) 
      query(heatEid) <| $ [es] (var heat_source__temperature : float4&;
                                heat_source__type : int)
        if (heat_source__type == int(partType.HUMAN_HEAD))
          basePartTemp = heat_source__head_base_temp
        elif (heat_source__type == int(partType.HUMAN_TORSO))
          basePartTemp = heat_source__torso_base_temp
        elif (heat_source__type == int(partType.HUMAN_HAND))
          basePartTemp = heat_source__hand_base_temp
        elif (heat_source__type == int(partType.HUMAN_LEG))
          basePartTemp = heat_source__leg_base_temp
        let resultPartTemp = clamp(heat_source__temperature.y - heat_source__human_cooling_speed * info.dt, 0.0f, basePartTemp.y)
        heat_source__temperature.x = basePartTemp.x
        heat_source__temperature.y = resultPartTemp
        heat_source__temperature.z = basePartTemp.x
        heat_source__temperature.w = resultPartTemp

[es(tag=render, on_disappear)]
def human_gun_heat_source_destroy_es(evt : Event;
                                     heat_source__humanGunEid : EntityId)
  destroyEntity(heat_source__humanGunEid)

[es(tag=render, on_disappear)]
def human_heat_source_destroy_es(evt : Event;
                                 var heat_source__bodyEid : EidList)
  destroyHeatSources(heat_source__bodyEid)

























[es(tag=render, track=isAlive)]
def human_heat_source_on_death_es(evt : Event;
                                  heat_source__bodyEid : EidList;
                                  isAlive : bool;
                                  heat_source__human_cooling_speed : float)
  for eid in heat_source__bodyEid
    query(eid) <| $ [es] (var heat_source__fadeout : bool&;
                          var heat_source__fadeoutTime : float&;
                          heat_source__temperature : float4)
      heat_source__fadeout = !isAlive
      heat_source__fadeoutTime = heat_source__temperature.y / heat_source__human_cooling_speed

[es(tag=render, on_event=(CmdNetShot, EventShot))]
def human_gun_set_temp_on_shot(evt : Event;
                               heat_source__humanGunEid : EntityId;
                               heat_source__human_gun_heating : float3)
  query(heat_source__humanGunEid) <| $ [es] (var heat_source__temperature : float4&)
    heat_source__temperature.y = min(heat_source__human_gun_heating.x / 2.0f, heat_source__temperature.y + heat_source__human_gun_heating.y / 2.0f)

[es(tag=render)]
def heat_source_fade_out_es(info : ParallelUpdateFrameDelayed;
                            eid : EntityId;
                            heat_source__fadeout : bool;
                            heat_source__fadeoutTime : float;
                            var heat_source__fadeoutEndTime : float&)
  if !heat_source__fadeout
    return
  if heat_source__fadeoutTime > 0.f && heat_source__fadeoutEndTime <= 0.f
    heat_source__fadeoutEndTime = info.curTime + heat_source__fadeoutTime;
  if info.curTime >= heat_source__fadeoutEndTime && heat_source__fadeoutEndTime > 0.f
    destroyEntity(eid);
