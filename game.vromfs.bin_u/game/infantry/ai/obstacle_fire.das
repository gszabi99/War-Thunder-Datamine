require ecs
require %game.events
require pathfinder
require DagorRandom
require DagorMath

[es(tag=server, on_appear, on_event=EventLevelLoaded)]
def obstacle_fire_created_es(evt : Event;
                             var obstacle__handle : int&;
                             transform : float3x4;
                             sphere_zone__radius : float;
                             dmgzone__maxRadius : float = 0.0f;
                             obstacle__padding : float = 0.0f)
  if obstacle__handle != 0
    return
  if !tilecache_is_loaded()
    return
  let radius = dmgzone__maxRadius > 0.0 ? dmgzone__maxRadius : sphere_zone__radius
  let ext = float3(radius + obstacle__padding, radius, radius + obstacle__padding)
  var tm : float3x4
  rotyTM(rnd_float(0.0f, PI * 2.0f), tm)
  obstacle__handle = tilecache_obstacle_add(transform * tm, BBox3(-ext, ext))
