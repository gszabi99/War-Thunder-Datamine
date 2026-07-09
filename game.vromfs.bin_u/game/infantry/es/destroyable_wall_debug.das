options no_aot
require ecs
require app
require ecs.ecs_template
require RendInst
require DagorConsole
require DagorDebug3D
require %appGame.es.render.draw_debug_utils_common
require %appGame.wt_events


[ecs_template]
struct destroyable_wall_debug
  destroyableWallDebug : Tag
  closest_wall : EntityId

[console_cmd(name="destroyable_wall.debug")]
def destroyable_wall_debug_cmd()
  let found = find_query() <| $ [es(REQUIRE=destroyableWallDebug)] (eid : EntityId)
    destroyEntity(eid)
    return true
  if !found
    createEntity("destroyable_wall_debug")

[console_cmd(name="destroyable_wall.damage")]
def destroyable_wall_damage_cmd(damage : float = 100.f)
  query() <| $ [es(REQUIRE=destroyableWallDebug)] (closest_wall : EntityId)
    query(closest_wall) <| $ [es] (transform : float3x4; ri_extra : RiExtraComponent)
      sendEventImmediate(closest_wall, CmdRendinstDamage(handle = ri_extra.handle,
                                                         damage = damage,
                                                         pos = transform[3],
                                                         impulse = float3(0.f, 1.f, 0.f),
                                                         time = get_sync_time()))

def private dist_point_ray(ray_start : float3; ray_direction : float3; point : float3)
  let t = dot(ray_direction, point - ray_start) / dot(ray_direction, ray_direction)
  let d = length(point - (ray_start + t * ray_direction))
  return d

[es(tag=gameClient, no_order, REQUIRE=hero)]
def destroyable_wall_debug_es(evt : UpdateStageInfoAct; camera__lookDir : float3; camera__look_at : DPoint3)
  query() <| $ [es(REQUIRE=destroyableWallDebug)] (var closest_wall : EntityId&)
    let dir = camera__lookDir
    let from = float3(camera__look_at)
    closest_wall = INVALID_ENTITY_ID
    var closest_wall_dist = 100.f

    query() <| $ [es(REQUIRE=destroyable_wall)] (eid : EntityId; transform : float3x4)
      let wall_pos = transform[3]
      if dist_point_ray(from, dir, wall_pos) < 1.f
        if closest_wall == INVALID_ENTITY_ID
          closest_wall = eid
        else
          let dist = length(from - wall_pos)
          if dist < closest_wall_dist
            closest_wall = eid
            closest_wall_dist = dist

    query(closest_wall) <| $ [es] (transform : float3x4; ri_extra__destrFx : bool)
      draw_debug_sphere_buffered(transform[3], 0.1, E3DCOLOR(0xffff0000), 12, 10)
      draw_debug_text_mark_buffered(transform[3] + float3(0.f, 0.1f, 0.f), "eid={closest_wall}", 1, E3DCOLOR(0xFFFFFFFF))
      draw_debug_text_mark_buffered(transform[3] + float3(0.f, 0.2f, 0.f), "destrFx={ri_extra__destrFx}", 1, E3DCOLOR(0xFFFFFFFF))
