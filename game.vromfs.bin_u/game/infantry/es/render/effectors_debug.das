options no_aot
require ecs
require ecs.ecs_template
require DagorDebug3D
require EffectorData
require DagorConsole
require GeomNodeTree
require danetlibs.render_debug.render.draw_debug_common


[ecs_template]
struct effectors_debug_draw
  effectorsDebug : Tag


[console_cmd(name="effectors.show", hint="Show animchar effectors")]
def effectors_debug_cmd()
  let exist = find_query() <| $ [es(REQUIRE=effectorsDebug)] (eid : EntityId)
    destroyEntity(eid)
    return true
  if !exist
    createEntity("effectors_debug_draw")
  console_print("effectors debug {exist ? "disabled" : "enabled"}")


[es(tag=render, no_order, REQUIRE=effectorsDebug)]
def draw_effectors(info : UpdateStageInfoRenderDebug)
  query() <| $ [es] (transform : float3x4;
                     animchar_effectors__effectorsState : Object)
    begin_draw_cached_debug_lines(false, false, false)

    let wofs = geomtree_calc_optimal_wofs(transform[3])
    for effector in animchar_effectors__effectorsState
      let effectorData = getNullable_EffectorData(animchar_effectors__effectorsState, effector.key)
      if effectorData == null || effectorData.weight <= 0.0
        continue

      var tm = effectorData.wtm
      tm[3] = effectorData.wtm[3] + wofs

      draw_cached_gizmo(tm, 0.1, 0.02)
      add_debug_text_mark(tm[3], "{effector.key} w: {effectorData.weight}", -1, 3.5f, E3DCOLOR(0x00000000))

    end_draw_cached_debug_lines()
