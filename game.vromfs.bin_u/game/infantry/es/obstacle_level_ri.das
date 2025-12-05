require ecs
require pathfinder
require RendInst
require Dacoll
require DagorSystem
require DagorMath

[es(tag=server, on_event=EventLevelLoaded)]
def obstacle_level_ri_loaded_es(evt : Event;
                                level_ri_obstacles__resNames : StringList;
                                level_ri_obstacles__padding : float = 0.0f;
                                level_ri_obstacles__paddingSide : float = 0.0f)
  for resName in level_ri_obstacles__resNames
    let resIdx = get_rigen_extra_res_idx(string(resName))
    if resIdx < 0
      continue
    let bb = riex_get_lbb(resIdx)
    let bb3 = BBox3(bb.bmin.xyz, bb.bmax.xyz)
    get_ri_gen_extra_instances(resIdx) <| $(handles : array<riex_handle_t>#)
      for handle in handles
        var tm : float3x4
        get_rigen_extra_matrix(handle, tm)
        let aabb = tm * bb3
        let aabbMin = aabb.boxMin
        let aabbMax = aabb.boxMax
        var aabbCenter = (aabbMin + aabbMax) * 0.5f
        let ext = aabbMax - aabbMin
        if project_to_nearest_navmesh_point(aabbCenter, max(ext.x, ext.z))
          var oobbInflate = BBox3(float3(0.0f, -level_ri_obstacles__padding, 0.0f), float3(0.0f, 0.0f, 0.0f))
          bbox3_inflateXZ(oobbInflate, level_ri_obstacles__paddingSide)
          if !tilecache_ri_obstacle_add(handle, oobbInflate)
            logerr("cannot create ri obstacle for {handle}, resName = {resName}, obstacle was probably already created as stationary ri obstacle")
  
  
  
  
  
  
  tilecache_sync()
