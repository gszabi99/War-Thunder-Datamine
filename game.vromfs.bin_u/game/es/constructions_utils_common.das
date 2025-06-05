module constructions_utils_common shared
require math.base
require DagorMath
require DagorMathUtils
require Dacoll
require ecs
require Unit
require IGroundModel

def check_inclination_angles(normal : float3;
                             angle_limits : float2)
  let angle = 90.0 - rad_to_deg(dir_to_angles(normal).y)
  return angle > angle_limits.x && angle < angle_limits.y

def is_conflict_with_world(tm; collobj : CollisionObject; collobj_offset : float; base_collres : CollisionResource const? = null;
                           visible_list : BoolList&; position_offsets : Point3List&)
  if base_collres == null
    return false
  for visible, i in visible_list, range(0, length(visible_list))
    if visible
      var tmCopy = tm
      tmCopy[3] = tm * position_offsets[i]
      tmCopy[3] = tmCopy[3] + normalize(tmCopy[1]) * collobj_offset
      if test_collision_world(collobj, tmCopy, (*base_collres).boundingSphereRad)
        return true
  return false

def is_collide_with_unit(box : BBox3; hero_eid : EntityId; army : int)
  var res = false
  find_query() <| $ [es(REQUIRE=unit__ref)] (eid : EntityId)
    let unit = get_unit_by_eid(eid)
    if unit == null || unit.isDelayed || (unit.army == army && hero_eid != eid) || !unit.isTank
      return false
    let gm = unit |> as_gm()
    if gm == null
      return false
    if (unit.unitTm * gm.bodyBoundingBox) & box
      res = true
      return true
    return false
  return res