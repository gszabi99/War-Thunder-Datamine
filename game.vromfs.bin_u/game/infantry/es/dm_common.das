module dm_common shared
require ecs
require DagorMath


def calc_dist_damage(dist : float, depth : float, dmg_dist_exp : float, penetration : float2, radius_min_max : float2, damage_near_far : float2)

  var t = cvt(dist, radius_min_max.x, radius_min_max.y, 0.f, 1.f)
  t = 1.f - pow(1.f - t, dmg_dist_exp);
  var damage = lerp(damage_near_far.x, damage_near_far.y, t)

  let p = cvt(dist, radius_min_max.x, radius_min_max.y, penetration.x, penetration.y)
  damage *= cvt(depth, 0.f, p, 1.f, 0.f)
  return damage
