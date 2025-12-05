require ecs
require AnimV20
require GeomNodeTree
require DagorSystem
require %game.events
require DagorMath


def is_gun_too_far_from_camera(gun_pos : vec4f; threshold_dist_sq : float)
  var result = true
  find_query() <| $ [es(REQUIRE=camera_view)] (transform : float3x4; camera__active : bool = true)
    if camera__active
      let camPos = transform[3]
      result = distance_sq(gun_pos.xyz, camPos) > threshold_dist_sq
      return true
    return false
  return result

def smoke_fx_on_shot_unmodded(eid : EntityId;
                              animchar : AnimcharBaseComponent;
                              gun_smoke_fx__incAmountPerShot : float;
                              gun_smoke_fx__nodeIds : IntList;
                              @shared_comp gun_smoke_fx__template : StringList;
                              @shared_comp gun_smoke_fx__scale : FloatList;
                              @shared_comp gun_smoke_fx__visibleAmountThreshold : FloatList;
                              var gun_smoke_fx__amount : float&;
                              var gun_smoke_fx__fxEids : EidList&;
                              gun_smoke_fx__fxOffsets : Point3List const? = null)
  gun_smoke_fx__amount = min(1.0, gun_smoke_fx__amount + gun_smoke_fx__incAmountPerShot)

  for counter, nodeId, fxTemplate, scale, fxEid, threshold in iter_range(gun_smoke_fx__nodeIds), gun_smoke_fx__nodeIds, gun_smoke_fx__template, gun_smoke_fx__scale, gun_smoke_fx__fxEids, gun_smoke_fx__visibleAmountThreshold
    if fxEid != INVALID_ENTITY_ID || gun_smoke_fx__amount < threshold || nodeId < 0
      continue

    var tm : float3x4
    geomtree_getNodeWtmScalar(*animchar.nodeTree, nodeId, tm)
    for i in 0..3
      tm[i] *= scale
    peek(fxTemplate) <| $(fxTemplateStr)
      fxEid = createEntity(fxTemplateStr) <| $(var init : ComponentsInitializer)
        init |> set("transform", tm)
        init |> set("gun_fx__ownerEid", eid)
        init |> set("gun_fx__nodeId", nodeId)
        if gun_smoke_fx__fxOffsets != null
          let offset = (*gun_smoke_fx__fxOffsets)[counter]
          init |> set("gun_fx__offset", offset)

def smoke_fx_on_shot_modded(gun_eid : EntityId;
                            animchar aka gun_animchar : AnimcharBaseComponent;
                            gun_smoke_fx__modEid : EntityId)
  query(gun_smoke_fx__modEid) <| $ [es] (animchar aka mod_animchar : AnimcharBaseComponent;
                                         gun_smoke_fx__incAmountPerShot : float;
                                         gun_smoke_fx__nodeIds : IntList;
                                         gun_smoke_fx__modNodeIds : IntList;
                                         @shared_comp gun_smoke_fx__template : StringList;
                                         @shared_comp gun_smoke_fx__scale : FloatList;
                                         @shared_comp gun_smoke_fx__visibleAmountThreshold : FloatList;
                                         var gun_smoke_fx__fxEids : EidList&;
                                         var gun_smoke_fx__amount : float&)
    gun_smoke_fx__amount = min(1.0, gun_smoke_fx__amount + gun_smoke_fx__incAmountPerShot)

    for gunNodeId, modNodeId, fxTemplate, scale, fxEid, threshold in gun_smoke_fx__nodeIds, gun_smoke_fx__modNodeIds, gun_smoke_fx__template, gun_smoke_fx__scale, gun_smoke_fx__fxEids, gun_smoke_fx__visibleAmountThreshold
      if fxEid != INVALID_ENTITY_ID || gun_smoke_fx__amount < threshold
        continue

      var tm : float3x4
      var eid : EntityId
      var nodeId = -1

      if gunNodeId >= 0
        nodeId = gunNodeId
        eid = gun_eid
        geomtree_getNodeWtmScalar(*gun_animchar.nodeTree, nodeId, tm)
      elif modNodeId >= 0
        nodeId = modNodeId
        eid = gun_smoke_fx__modEid
        geomtree_getNodeWtmScalar(*mod_animchar.nodeTree, nodeId, tm)
      else
        continue

      for i in 0..3
        tm[i] *= scale
      peek(fxTemplate) <| $(fxTemplateStr)
        fxEid = createEntity(fxTemplateStr) <| $(var init : ComponentsInitializer)
          init |> set("transform", tm)
          init |> set("gun_fx__ownerEid", eid)
          init |> set("gun_fx__nodeId", nodeId)

def smoke_update(dt : float;
                 animchar_render__root_pos : vec4f;
                 gun_smoke_fx__halfLife : float;
                 gun_smoke_fx__thresholdDistSq : float;
                 gun_smoke_fx__opacityMult : FloatList;
                 gun_smoke_fx__visibleAmountThreshold : FloatList;
                 var gun_smoke_fx__fxEids : EidList;
                 var gun_smoke_fx__amount : float&;
                 animchar__visible : bool = true)
  let visible = animchar__visible && !is_gun_too_far_from_camera(animchar_render__root_pos, gun_smoke_fx__thresholdDistSq)
  for fxEid, opacityMult, threshold in gun_smoke_fx__fxEids, gun_smoke_fx__opacityMult, gun_smoke_fx__visibleAmountThreshold
    if fxEid != INVALID_ENTITY_ID
      if !visible || gun_smoke_fx__amount < threshold
        destroyEntity(fxEid)
        fxEid = INVALID_ENTITY_ID
      else
        query(fxEid) <| $ [es] (var effect__colorMult : E3DCOLOR&)
          let opacity = uint(255.0 * min(1.0, opacityMult * gun_smoke_fx__amount))
          effect__colorMult = E3DCOLOR(uint4(opacity, opacity, opacity, 255u))

  if visible
    gun_smoke_fx__amount *= pow(0.5, safediv(dt, gun_smoke_fx__halfLife))
  else
    gun_smoke_fx__amount = 0.0

[es(tag=render, on_appear, REQUIRE=gun_smoke_fx_mod)]
def gun_smoke_fx_mod_init(evt : Event;
                          eid : EntityId;
                          animchar aka mod_animchar : AnimcharBaseComponent;
                          animchar_attach__attachedTo : EntityId;  
                          @shared_comp gun_smoke_fx__nodes : StringList;
                          @shared_comp gun_smoke_fx__template : StringList;
                          @shared_comp gun_smoke_fx__scale : FloatList;
                          @shared_comp gun_smoke_fx__opacityMult : FloatList;
                          @shared_comp gun_smoke_fx__visibleAmountThreshold : FloatList;
                          @shared_comp gun_smoke_fx__useModNodes : BoolList;
                          var gun_smoke_fx__nodeIds : IntList&;
                          var gun_smoke_fx__modNodeIds : IntList&;
                          var gun_smoke_fx__fxEids : EidList&)
  let numFx = length(gun_smoke_fx__nodes)
  gun_smoke_fx__nodeIds |> resize(numFx)
  gun_smoke_fx__modNodeIds |> resize(numFx)
  gun_smoke_fx__fxEids |> resize(numFx)

  if length(gun_smoke_fx__template) != numFx || length(gun_smoke_fx__scale) != numFx || length(gun_smoke_fx__opacityMult) != numFx || length(gun_smoke_fx__visibleAmountThreshold) != numFx || length(gun_smoke_fx__useModNodes) != numFx
    logerr("[{eid}] {getEntityTemplateName(eid)}: gun_smoke_fx has wrong number of elements in lists")
  query(animchar_attach__attachedTo) <| $ [es] (animchar aka gun_animchar : AnimcharBaseComponent;
                                                var gun_smoke_fx__modEid : EntityId&)
    gun_smoke_fx__modEid = eid
    for nodeId, modNodeId, node, useModNode in gun_smoke_fx__nodeIds, gun_smoke_fx__modNodeIds, gun_smoke_fx__nodes, gun_smoke_fx__useModNodes
      if useModNode
        nodeId = -1
        modNodeId = geomtree_findNodeIndex(*mod_animchar.nodeTree, string(node))
      else
        nodeId = geomtree_findNodeIndex(*gun_animchar.nodeTree, string(node))
        modNodeId = -1
      if nodeId < 0 && modNodeId < 0
        logerr("[{eid}] {getEntityTemplateName(eid)}: gun_smoke_fx node {node} not found")

[es(tag=render, on_appear, REQUIRE_NOT=gun_smoke_fx_mod)]
def gun_smoke_fx_init(evt : Event;
                      eid : EntityId;
                      animchar : AnimcharBaseComponent;
                      @shared_comp gun_smoke_fx__nodes : StringList;
                      @shared_comp gun_smoke_fx__template : StringList;
                      @shared_comp gun_smoke_fx__scale : FloatList;
                      @shared_comp gun_smoke_fx__opacityMult : FloatList;
                      @shared_comp gun_smoke_fx__visibleAmountThreshold : FloatList;
                      var gun_smoke_fx__nodeIds : IntList&;
                      var gun_smoke_fx__fxEids : EidList&)
  let numFx = length(gun_smoke_fx__nodes)
  gun_smoke_fx__nodeIds |> resize(numFx)
  gun_smoke_fx__fxEids |> resize(numFx)

  if length(gun_smoke_fx__template) != numFx || length(gun_smoke_fx__scale) != numFx || length(gun_smoke_fx__opacityMult) != numFx || length(gun_smoke_fx__visibleAmountThreshold) != numFx
    logerr("[{eid}] {getEntityTemplateName(eid)}: gun_smoke_fx has wrong number of elements in lists")

  for id, node in gun_smoke_fx__nodeIds, gun_smoke_fx__nodes
    id = geomtree_findNodeIndex(*animchar.nodeTree, string(node))
    if id < 0
      logerr("[{eid}] {getEntityTemplateName(eid)}: gun_smoke_fx node {node} not found")


[es(tag=render, on_event=(CmdNetShot, EventShot))]
def gun_smoke_fx_on_shot(evt : Event;
                         eid : EntityId;
                         animchar_render__root_pos : vec4f;
                         animchar : AnimcharBaseComponent;
                         gun_smoke_fx__nodeIds : IntList;
                         gun_smoke_fx__incAmountPerShot : float;
                         gun_smoke_fx__thresholdDistSq : float;
                         gun_smoke_fx__modEid : EntityId;
                         @shared_comp gun_smoke_fx__template : StringList;
                         @shared_comp gun_smoke_fx__scale : FloatList;
                         @shared_comp gun_smoke_fx__visibleAmountThreshold : FloatList;
                         var gun_smoke_fx__amount : float&;
                         var gun_smoke_fx__fxEids : EidList&;
                         animchar__visible : bool = true)
  if !animchar__visible || is_gun_too_far_from_camera(animchar_render__root_pos, gun_smoke_fx__thresholdDistSq)
    return
  if gun_smoke_fx__modEid == INVALID_ENTITY_ID
    smoke_fx_on_shot_unmodded(eid, animchar,
                              gun_smoke_fx__incAmountPerShot, gun_smoke_fx__nodeIds, gun_smoke_fx__template,
                              gun_smoke_fx__scale, gun_smoke_fx__visibleAmountThreshold,
                              gun_smoke_fx__amount, gun_smoke_fx__fxEids)
  else
    smoke_fx_on_shot_modded(eid, animchar, gun_smoke_fx__modEid)


[es(tag=render, after=after_animchar_update_sync, before=effect_attached_es)]
def gun_smoke_update(info : ParallelUpdateFrameDelayed;
                     animchar_render__root_pos : vec4f;
                     gun_smoke_fx__halfLife : float;
                     gun_smoke_fx__thresholdDistSq : float;
                     @shared_comp gun_smoke_fx__opacityMult : FloatList;
                     @shared_comp gun_smoke_fx__visibleAmountThreshold : FloatList;
                     var gun_smoke_fx__fxEids : EidList;
                     var gun_smoke_fx__amount : float&;
                     animchar__visible : bool = true)
  smoke_update(info.dt, animchar_render__root_pos,
               gun_smoke_fx__halfLife, gun_smoke_fx__thresholdDistSq,
               gun_smoke_fx__opacityMult, gun_smoke_fx__visibleAmountThreshold,
               gun_smoke_fx__fxEids, gun_smoke_fx__amount, animchar__visible)
