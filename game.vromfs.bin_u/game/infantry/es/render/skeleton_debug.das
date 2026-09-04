options no_aot
require ecs
require Unit
require DagorDebug3D
require AnimV20
require GeomNodeTree
require DagorConsole
require math.base
require strings
require WTCamera
require danetlibs.render_debug.render.draw_debug_common
require %appGame.infantry.es.render.skeleton_debug_common


[console_cmd(name="skeleton.debug", hint="Draw all animchar's skeleton nodes")]
def skeleton_draw_debug_cmd(draw_gizmo : bool = false; draw_distance : float = 6.0)
  toggle_skeleton_debug(draw_gizmo, draw_distance)

[console_cmd(name="skeleton_debug.set_filter", hint="Sets node name filter to be used. Comma separated, use '-' for exlcude")]
def skeleton_draw_set_filter_debug_cmd(filter : string)
  skeleton_debug_set_filter(filter)

[console_cmd(name="skeleton.debug_selected_entity", hint="Toggle: draw skeleton nodes only for the entity currently selected in daEditor")]
def skeleton_draw_debug_selected_only_cmd(draw_gizmo : bool = false; draw_distance : float = 6.0)
  skeleton_debug_toggle_selected_only(draw_gizmo, draw_distance)

def get_node_color(node_idx : int; children_count : int)
  if node_idx == 0
    return E3DCOLOR(0xFFC50101)
  if children_count == 0
    return E3DCOLOR(0xFF68D3C5)
  return E3DCOLOR(0xFFD0E44E)


def draw_skeleton_nodes_recursive(tree : GeomNodeTree; additional_tm : float3x4; node_idx : int; drawContext : SkeletonNodeDrawDebugContext)
  let childCount = tree |> geomtree_getChildCount(node_idx)
  var tm : float3x4
  tree |> geomtree_getNodeWtmScalar(node_idx, tm)
  tm = additional_tm * tm

  let color = get_node_color(node_idx, int(childCount))

  let nodeName = node_idx == 0 ? ":root" : tree |> geomtree_getNodeName(node_idx)
  var filterPassed = true

  if length(*drawContext.nodeNameFilterInclude) > 0
    filterPassed = false
    for filter in *drawContext.nodeNameFilterInclude
      let nodeNameContainsFilter = find(nodeName, "{filter}") != -1
      if nodeNameContainsFilter
        filterPassed = true
        break

  if length(*drawContext.nodeNameFilterExclude) > 0
    for filter in *drawContext.nodeNameFilterExclude
      let nodeNameContainsFilter = find(nodeName, "{filter}") != -1
      if nodeNameContainsFilter
        filterPassed = false
        break

  if filterPassed
    draw_cached_debug_sphere(tm[3], 0.01, color, 8)
    if drawContext.drawGizmos
      draw_cached_gizmo(tm, drawContext.gizmoAxisSize, drawContext.gizmoAxisSize / 6.0)
    add_debug_text_mark(tm[3], drawContext.drawNodeIndicies ? "({node_idx}) {nodeName}" : nodeName,  -1,  -0.5f, color)

  for i in 0u..childCount
    let childNodeIdx = tree |> geomtree_getChildNodeIdx(node_idx, i)
    var childTm : float3x4
    tree |> geomtree_getNodeWtmScalar(childNodeIdx, childTm)
    childTm = additional_tm * childTm

    draw_cached_debug_line(tm[3], childTm[3], color)

    draw_skeleton_nodes_recursive(tree, additional_tm, childNodeIdx, drawContext)


[es(no_order, REQUIRE=skeleton_debug_draw)]
def draw_skeleton_nodes(info : UpdateStageInfoRenderDebug;
                        skeleton_debug_draw__enabled : bool;
                        skeleton_debug_draw__drawGizmos : bool;
                        skeleton_debug_draw__drawNodeIndicies : bool;
                        skeleton_debug_draw__gizmoAxisSize : float;
                        skeleton_debug_draw__maxDistance : float;
                        skeleton_debug_draw__filterEditorSelectedEntityOnly : bool;
                        skeleton_debug_draw__filterByNodeNameInclude : StringList;
                        skeleton_debug_draw__filterByNodeNameExclude : StringList)
  if !skeleton_debug_draw__enabled
    return

  begin_draw_cached_debug_lines(false, false, false)

  var drawn = false

  
  query() <| $ [es] (animchar : AnimcharBaseComponent; daeditor__selected : ecs::Tag const?)
    if animchar.nodeTree == null
      return

    if skeleton_debug_draw__filterEditorSelectedEntityOnly && daeditor__selected == null
      return

    var tm : float3x4
    animchar |> animchar_get_tm(tm)
    if skeleton_debug_draw__maxDistance > 0.0 && distance_sq(tm[3], get_camera_pos()) > square(skeleton_debug_draw__maxDistance)
      return

    unsafe
      var drawContext : SkeletonNodeDrawDebugContext
      drawContext.drawGizmos = skeleton_debug_draw__drawGizmos
      drawContext.gizmoAxisSize = skeleton_debug_draw__gizmoAxisSize
      drawContext.drawNodeIndicies = skeleton_debug_draw__drawNodeIndicies
      drawContext.nodeNameFilterInclude = addr(skeleton_debug_draw__filterByNodeNameInclude)
      drawContext.nodeNameFilterExclude = addr(skeleton_debug_draw__filterByNodeNameExclude)

      draw_skeleton_nodes_recursive(*animchar.nodeTree, IDENT_TM, 0, drawContext)
      drawn = true

  if drawn
    return

  
  query() <| $ [es] (unit__ref : UnitRef; transform : float3x4; daeditor__selected : ecs::Tag const?)
    if skeleton_debug_draw__filterEditorSelectedEntityOnly && daeditor__selected == null
      return

    let nodeTree = get_entity_geom_node_tree(unit__ref, null)
    if nodeTree == null
      return

    assume tm = transform

    if skeleton_debug_draw__maxDistance > 0.0 && distance_sq(tm[3], get_camera_pos()) > square(skeleton_debug_draw__maxDistance)
      return

    unsafe
      var drawContext : SkeletonNodeDrawDebugContext
      drawContext.drawGizmos = skeleton_debug_draw__drawGizmos
      drawContext.gizmoAxisSize = skeleton_debug_draw__gizmoAxisSize
      drawContext.drawNodeIndicies = skeleton_debug_draw__drawNodeIndicies
      drawContext.nodeNameFilterInclude = addr(skeleton_debug_draw__filterByNodeNameInclude)
      drawContext.nodeNameFilterExclude = addr(skeleton_debug_draw__filterByNodeNameExclude)

      draw_skeleton_nodes_recursive(*nodeTree, tm, 0, drawContext)

  end_draw_cached_debug_lines()
