options no_aot
require math.color
require ecs
require ecs.ecs_template
require math.base
require gameObject
require DagorConsole
require DagorDebug3D


[ecs_template]
struct game_objects_debug_draw
  game_objects__debugDrawDist : float = 50.


[console_cmd(name="game_object.debug_draw")]
def game_objects_debug_draw_cmd(dist = 50.)
  let tmpl = "game_objects_debug_draw"
  let exists = find_query() <| $ [es] (eid : EntityId; var game_objects__debugDrawDist : float&)
    if game_objects__debugDrawDist == dist
      destroyEntity(eid)
    else
      game_objects__debugDrawDist = dist
    return true

  if !exists
    createEntity(tmpl) <| $(init)
      init |> set("game_objects__debugDrawDist", dist)


[es(tag=render, tag=dev, no_order)]
def game_objects_debug_es(evt : UpdateStageInfoRenderDebug;
                          game_objects__debugDrawDist : float)
  find_query() <| $ [es] (camera__active : bool;
                          transform : float3x4)
    if !camera__active
      return false
    let box = BBox3(transform[3] - float3(game_objects__debugDrawDist), transform[3] + float3(game_objects__debugDrawDist))
    find_query() <| $ [es] (game_objects : GameObjects)
      begin_draw_cached_debug_lines(false, false, false)
      game_objects |> for_scene_game_object_types() <| $(object_type : string)
        let objectTypeHash = ecs_hash(object_type)
        let objectTypeColor = E3DCOLOR(Color4(hsv2rgb(float3(float(objectTypeHash % 360u), 1.0, 1.0)), 1.0))
        game_objects |> get_scene_game_objects_by_name(object_type) |> for_scene_game_objects(box) <| $ [unused_argument(ni)] (ni : uint; tm : float3x4#)
          set_cached_debug_lines_wtm(tm)
          draw_cached_debug_box(IDENT_BBOX, objectTypeColor)
          add_debug_text_mark(tm[3], object_type, -1, 0f, objectTypeColor)
      set_cached_debug_lines_wtm(IDENT_TM)
      end_draw_cached_debug_lines()
      return true
    return true

