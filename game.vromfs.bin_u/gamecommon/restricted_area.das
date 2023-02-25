require ecs
require Unit
require DagorMath
require %game.utils_common

def is_point_in_box_zone(pos : float3; transform : float3x4)
  var zonePos : float3 = inverse(transform) * float3(pos.x, 0.0, pos.z)
  zonePos.y = 0.5
  return BBox3(float3(-0.5, 0.0, -0.5), float3(0.5, 1.0, 0.5)) & zonePos

[es(tag=server, no_order)]
def restricted_area_unit_update_es(act : UpdateStageInfoAct;
                                   var restricted_area_timer : float&;
                                   uid : int)
  get_unit_for_edit(uid) <| $(var unit)
    if unit != null && !unit.isDelayed && unit.isAlive && unit.myPlayer != null
      var found = false
      find_query() <| $ [es] (transform : float3x4; eid : EntityId; restricted_area__away_time : float)
        let isBox = has(eid, "box_area")
        let isSphere = has(eid, "sphere_area")
        let isCylinder = has(eid, "cylinder_area")
        let pos = unit.pos
        if isBox
          if is_point_in_box_zone(pos, transform)
            found = true
            if restricted_area_timer < 0.0
              restricted_area_timer = restricted_area__away_time
            return true
        elif isSphere
          let radSq = max(length_sq(transform[0]), max(length_sq(transform[1]), length_sq(transform[2])))
          if length_sq(transform[3] - pos) < radSq
            found = true
            if restricted_area_timer < 0.0
              restricted_area_timer = restricted_area__away_time
            return true
        return false
      if !found
        restricted_area_timer = -1.0
      if restricted_area_timer > 0.0
        restricted_area_timer -= act.dt
        if restricted_area_timer <= 0.0
          restricted_area_timer = -1.0
          *unit |> kickFromRestrictedArea()