module walker_nodes_common shared

require ecs
require app
require math.base
require %appGame.infantry.es.battle_area_common
require RendInst
require DagorMath
require DagorMathUtils
require inventory
require DngWalkerai
require pathfinder
require %appGame.infantry.es.human_reload_common
require %appGame.infantry.es.loc_squad_common
require Grid


def is_point_safe(pos : float3; member_team : int)
  if !has_active_human_battle_area_at(pos, member_team)
    return false

  let isDangerArea = find_query() <| $ [es] (team__id : int;
                                             walker_custom_nav : CustomNav;
                                             team_dangers__dangerMinWeight : float = 500.0)
    if team__id == member_team
      let weight = walker_custom_nav_getWeight(walker_custom_nav, pos)
      if weight >= team_dangers__dangerMinWeight
        return true
    return false
  if isDangerArea
    return false

  let danger = find_query() <| $ [es] (transform : float3x4; sphere_zone__radius : float;
                                       dmgzone__damage, dmgzone__fireAffect : float)
    if length_sq(inverse(transform) * pos) <= square(sphere_zone__radius)
      if dmgzone__damage > 0. || dmgzone__fireAffect > 0.
        return true
    return false
  return !danger

def check_human_reload(eid : EntityId; need_reload_ratio : float = 0.0)
  var reload = 0
  query(eid) <| $ [es] (human_weap__reloadAtTime : float; human_weap__isReloading : bool; human_weap__currentGunEid : EntityId)
    let atTime = get_sync_time()
    if atTime < human_weap__reloadAtTime || human_weap__isReloading
      reload = 1 
    else
      query(human_weap__currentGunEid) <| $ [es] (gun__ammo : int;
                                                  gun__totalAmmo : int;
                                                  gun__reloadable : bool = false;
                                                  gun__wishAmmoItemType : int = INVALID_ITEM_ID;
                                                  gun__maxAmmo : int = 0)
        if !gun__reloadable || gun__totalAmmo <= 0
          return
        if gun__maxAmmo <= 0
          if gun__ammo <= 0
            reload = -1 
        elif float(gun__ammo) / float(gun__maxAmmo) <= need_reload_ratio
          query(eid) <| $ [es] (itemContainer : EidList)
            let ammoForGun = find_ammo_for_gun(human_weap__currentGunEid, itemContainer, gun__wishAmmoItemType, 0)
            if ammoForGun.itemIndex >= 0 && ammoForGun.ammoCount > gun__ammo
              reload = -1 
  return reload

def check_hostile_humans_nearby(agent_eid : EntityId; radius : float; dh : float2)
  var pos = float3()
  var team = -1
  query(agent_eid) <| $ [es] (transform : float3x4; squad_member__playerEid : EntityId)
    pos = transform[3]
    query(squad_member__playerEid) <| $ [es] (team aka player__team : int)
      team = player__team
  if team < 0
    return false

  var box = BBox3()
  let r = radius
  box |> bbox3_add(pos + float3(-r, dh.x, -r))
  box |> bbox3_add(pos + float3(r, dh.y, r))
  let maxDistSq = square(r)

  var found = false
  find_entity_in_grid(ecs_hash("humans"), box, GridEntCheck.BOUNDING) <| $(eid aka human_eid : EntityId)
    query(human_eid) <| $ [es(REQUIRE=human, REQUIRE_NOT=deadEntity)] (isAlive : bool;
                                                                       isDowned : bool;
                                                                       human_net_phys__isSwimming : bool = false;
                                                                       transform : float3x4;
                                                                       squad_member__playerEid : EntityId)
      if isAlive && !isDowned && !human_net_phys__isSwimming
        let delta = x0z(transform[3] - pos)
        if length_sq(delta) <= maxDistSq
          query(squad_member__playerEid) <| $ [es] (team aka player__team : int)
            if player__team != team
              found = true
    return found
  return found
