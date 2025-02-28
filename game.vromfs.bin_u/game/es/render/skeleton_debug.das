options no_aot
require ecs
require DagorDebug3D
require AnimV20
require GeomNodeTree
require DagorConsole
require math.base
require danetlibs.render_debug.render.draw_debug_common
require %game.utils.utils_common

// require ecs.ecs_template
// [ecs_template]
// struct skeleton_draw_debug
//   skeletonDrawDebug : Tag
//   drawGizmos : bool = false


[console_cmd(name="skeleton.debug", hint="Draw all animchar's skeleton nodes")]
def skeleton_draw_debug_cmd(draw_gizmo : bool = false)
  let exist = find_query() <| $ [es(REQUIRE=skeletonDrawDebug)] (eid : EntityId)
    destroyEntity(eid)
    return true
  if !exist
    createEntity("skeleton_draw_debug") <| $(init)
      init |> set("drawGizmos", draw_gizmo)
  console_print("skeleton debug {exist ? "disabled" : "enabled"}")


def get_node_color(node_idx : int; children_count : int)
  if node_idx == 0
    return E3DCOLOR(0xFFC50101)
  if children_count == 0
    return E3DCOLOR(0xFF68D3C5)
  return E3DCOLOR(0xFFD0E44E)


def draw_skeleton_nodes_recursive(tree : GeomNodeTree; node_idx : int; drawGizmos : bool)
  let childCount = tree |> geomtree_getChildCount(node_idx)
  var  tm : float3x4
  tree |> geomtree_getNodeWtmScalar(node_idx, tm)
  let color = get_node_color(node_idx, int(childCount))

  draw_cached_debug_sphere(tm[3], 0.01, color, 8)
  if drawGizmos
    draw_cached_gizmo(tm, 0.1, 0.05)
  add_debug_text_mark(tm[3], tree |> geomtree_getNodeName(node_idx), /*max len*/ -1, /*vertical text offset*/ -0.5f, color);

  for i in 0u..childCount
    let childNodeIdx = tree |> geomtree_getChildNodeIdx(node_idx, i)
    var childTm : float3x4
    tree |> geomtree_getNodeWtmScalar(childNodeIdx, childTm)

    draw_cached_debug_line(tm[3], childTm[3], color)

    draw_skeleton_nodes_recursive(tree, childNodeIdx, drawGizmos)


[es(no_order, REQUIRE=skeletonDrawDebug)]
def draw_skeleton_nodes(evt : UpdateStageInfoRenderDebug; drawGizmos : bool)
  begin_draw_cached_debug_lines(false, false, false)
  query() <| $ [es] (animchar : AnimcharBaseComponent)
    if animchar.nodeTree == null
      return

    draw_skeleton_nodes_recursive(*animchar.nodeTree, 0, drawGizmos)
  end_draw_cached_debug_lines()
