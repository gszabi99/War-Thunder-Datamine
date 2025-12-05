require ecs
require AnimV20
require GeomNodeTree
require DagorSystem
require math.base
require %game.events

[es(tag=render, on_appear, REQUIRE=gun_flash_fx_mod)]
def gun_flash_fx_mod_init(evt : Event;
                          eid : EntityId;
                          animchar aka mod_animchar : AnimcharBaseComponent;
                          animchar_attach__attachedTo : EntityId;  
                          @shared_comp gun_flash_fx__nodes : StringList;
                          @shared_comp gun_flash_fx__template : StringList;
                          @shared_comp gun_flash_fx__scale : FloatList;
                          @shared_comp gun_flash_fx__useModNodes : BoolList;
                          var gun_flash_fx__nodeIds : IntList&;
                          var gun_flash_fx__modNodeIds : IntList&)
  let numFx = length(gun_flash_fx__nodes)
  gun_flash_fx__nodeIds |> resize(numFx)
  gun_flash_fx__modNodeIds |> resize(numFx)
  if length(gun_flash_fx__template) != numFx || length(gun_flash_fx__scale) != numFx || length(gun_flash_fx__useModNodes) != numFx
    logerr("[{eid}] {getEntityTemplateName(eid)}: gun_flash_fx has wrong number of elements in lists")
  query(animchar_attach__attachedTo) <| $ [es] (animchar aka gun_animchar : AnimcharBaseComponent;
                                                var gun_flash_fx__modEid : EntityId&)
    gun_flash_fx__modEid = eid
    for nodeId, modNodeId, node, useModNode in gun_flash_fx__nodeIds, gun_flash_fx__modNodeIds, gun_flash_fx__nodes, gun_flash_fx__useModNodes
      if useModNode
        nodeId = -1
        modNodeId = geomtree_findNodeIndex(*mod_animchar.nodeTree, string(node))
      else
        nodeId = geomtree_findNodeIndex(*gun_animchar.nodeTree, string(node))
        modNodeId = -1
      if nodeId < 0 && modNodeId < 0
        logerr("[{eid}] {getEntityTemplateName(eid)}: gun_flash_fx node {node} not found")

[es(tag=render, on_appear, REQUIRE_NOT=gun_flash_fx_mod)]
def gun_flash_fx_init(evt : Event;
                      eid : EntityId;
                      animchar : AnimcharBaseComponent;
                      @shared_comp gun_flash_fx__nodes : StringList;
                      @shared_comp gun_flash_fx__template : StringList;
                      @shared_comp gun_flash_fx__scale : FloatList;
                      var gun_flash_fx__nodeIds : IntList&)
  let numFx = length(gun_flash_fx__nodes)
  gun_flash_fx__nodeIds |> resize(numFx)
  if length(gun_flash_fx__template) != numFx || length(gun_flash_fx__scale) != numFx
    logerr("[{eid}] {getEntityTemplateName(eid)}: gun_flash_fx has wrong number of elements in lists")
  for id, node in gun_flash_fx__nodeIds, gun_flash_fx__nodes
    id = geomtree_findNodeIndex(*animchar.nodeTree, string(node))
    if id < 0
      logerr("[{eid}] {getEntityTemplateName(eid)}: gun_flash_fx node {node} not found")

[es(tag=render, on_appear)]
def gun_flash_fx_multiple_barrels_init(evt : Event;
                                       eid : EntityId;
                                       animchar : AnimcharBaseComponent;
                                       gun__barrelCount : int;
                                       @shared_comp gun_flash_fx__multipleBarrelsNodes : StringList;
                                       @shared_comp gun_flash_fx__multipleBarrelsTemplate : StringList;
                                       @shared_comp gun_flash_fx__multipleBarrelsScale : FloatList;
                                       var gun_flash_fx__multipleBarrelsNodeIds : IntList&)
  let numFx = length(gun_flash_fx__multipleBarrelsNodes)
  gun_flash_fx__multipleBarrelsNodeIds |> resize(numFx)
  if (numFx % gun__barrelCount) != 0 || length(gun_flash_fx__multipleBarrelsTemplate) != numFx || length(gun_flash_fx__multipleBarrelsScale) != numFx
    logerr("[{eid}] {getEntityTemplateName(eid)}: gun_flash_fx_multiple_barrels has wrong number of elements in multipleBarrels lists")
  for id, node in gun_flash_fx__multipleBarrelsNodeIds, gun_flash_fx__multipleBarrelsNodes
    id = geomtree_findNodeIndex(*animchar.nodeTree, string(node))
    if id < 0
      logerr("[{eid}] {getEntityTemplateName(eid)}: gun_flash_fx_multiple_barrels node {node} not found")

def flash_unmodded(gun_eid : EntityId;
                   animchar : AnimcharBaseComponent;
                   gun_flash_fx__nodeIds : IntList;
                   gun_flash_fx__template : StringList;
                   gun_flash_fx__scale : FloatList)
  for nodeId, fxTemplate, scale in gun_flash_fx__nodeIds, gun_flash_fx__template, gun_flash_fx__scale
    if nodeId < 0
      continue
    var tm : float3x4
    geomtree_getNodeWtmScalar(*animchar.nodeTree, nodeId, tm)
    for i in 0..3
      tm[i] *= scale
    createEntity(string(fxTemplate)) <| $(var init : ComponentsInitializer)
      init |> set("transform", tm)
      init |> set("gun_fx__ownerEid", gun_eid)
      init |> set("gun_fx__nodeId", nodeId)

def flash_modded(gun_eid : EntityId;
                 gun_animchar : AnimcharBaseComponent;
                 gun_flash_fx__modEid : EntityId)
  query(gun_flash_fx__modEid) <| $ [es] (animchar aka mod_animchar : AnimcharBaseComponent;
                                         gun_flash_fx__nodeIds : IntList;
                                         gun_flash_fx__modNodeIds : IntList;
                                         @shared_comp gun_flash_fx__template : StringList;
                                         @shared_comp gun_flash_fx__scale : FloatList)
    for gunNodeId, modNodeId, fxTemplate, scale in gun_flash_fx__nodeIds, gun_flash_fx__modNodeIds, gun_flash_fx__template, gun_flash_fx__scale
      var tm : float3x4
      var eid : EntityId
      var nodeId = -1

      if gunNodeId >= 0
        nodeId = gunNodeId
        eid = gun_eid
        geomtree_getNodeWtmScalar(*gun_animchar.nodeTree, nodeId, tm)
      elif modNodeId >= 0
        nodeId = modNodeId
        eid = gun_flash_fx__modEid
        geomtree_getNodeWtmScalar(*mod_animchar.nodeTree, nodeId, tm)
      else
        continue

      for i in 0..3
        tm[i] *= scale
      createEntity(string(fxTemplate)) <| $(var init : ComponentsInitializer)
        init |> set("transform", tm)
        init |> set("gun_fx__ownerEid", eid)
        init |> set("gun_fx__nodeId", nodeId)

[es(tag=render, on_event=(CmdNetShot, EventShot))]
def gun_flash_fx_on_shot(evt : Event;
                         eid : EntityId;
                         animchar : AnimcharBaseComponent;
                         gun_flash_fx__nodeIds : IntList;
                         gun_flash_fx__modEid : EntityId;
                         @shared_comp gun_flash_fx__template : StringList;
                         @shared_comp gun_flash_fx__scale : FloatList;
                         animchar__visible : bool = true;
                         auto_gun_controller__enabled : bool = false)
  if !animchar__visible && !auto_gun_controller__enabled
    return
  if gun_flash_fx__modEid == INVALID_ENTITY_ID
    flash_unmodded(eid, animchar, gun_flash_fx__nodeIds, gun_flash_fx__template, gun_flash_fx__scale)
  else
    flash_modded(eid, animchar, gun_flash_fx__modEid)

[es(tag=render, on_event=(CmdNetShot, EventShot), after=gun_barrel_index_update)]
def gun_flash_fx_multiple_barrels_on_shot(evt : Event;
                                          eid : EntityId;
                                          animchar : AnimcharBaseComponent;
                                          gun__barrelCount : int;
                                          gun__barrelIndex : int;
                                          animchar__visible : bool = true;
                                          auto_gun_controller__enabled : bool = false;
                                          @shared_comp gun_flash_fx__multipleBarrelsTemplate : StringList;
                                          @shared_comp gun_flash_fx__multipleBarrelsScale : FloatList;
                                          gun_flash_fx__multipleBarrelsNodeIds : IntList)
  if !animchar__visible && !auto_gun_controller__enabled
    return
  let numFxForboltAction = length(gun_flash_fx__multipleBarrelsNodeIds) / gun__barrelCount
  let begin = numFxForboltAction * (gun__barrelIndex - 1)
  let end = begin + numFxForboltAction
  for i in range(begin, end)
    assume nodeId = gun_flash_fx__multipleBarrelsNodeIds[i]
    assume fxTemplate = gun_flash_fx__multipleBarrelsTemplate[i]
    assume scale = gun_flash_fx__multipleBarrelsScale[i]
    if nodeId < 0
      continue
    var tm : float3x4
    geomtree_getNodeWtmScalar(*animchar.nodeTree, nodeId, tm)
    for j in 0..3
      tm[j] *= scale
    createEntity(string(fxTemplate)) <| $(var init : ComponentsInitializer)
      init |> set("transform", tm)
      init |> set("gun_fx__ownerEid", eid)
      init |> set("gun_fx__nodeId", nodeId)

[es(on_appear, tag=render, REQUIRE=effect__name)]
def gun_flash_fx_init_es(evt : Event;
                         var transform : float3x4&;
                         gun_flash_fx__scaleMultiplier : float)
  transform = transform * scale_tm(gun_flash_fx__scaleMultiplier)

[es(tag=render, no_order)]
def gun_flash_fx_check_destruction_time(info : ParallelUpdateFrameDelayed; eid : EntityId; var gun_flash_fx__timeToDestroy : float&)
  gun_flash_fx__timeToDestroy -= info.dt
  if gun_flash_fx__timeToDestroy <= 0.
    destroyEntity(eid)