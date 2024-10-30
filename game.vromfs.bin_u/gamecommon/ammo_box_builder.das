require ecs
require app
require WTCamera
require Dacoll
require RendInst
require Unit
require HeroManager
require PhysMat
require %game.events
require net
require CollRes
require %game.utils.utils_common
require Weapon
require %game.constructions_utils
require DagorSystem
require DagorMath
require app

[es(on_appear)]
def building_preview_collobj_init_es(evt : Event;
                                     builder_preview__collRes : CollisionResource const?;
                                     builder_preview__physBlk : string;
                                     var builder_preview__collObj : CollisionObject)
  if builder_preview__collRes != null
    add_dynamic_collision_from_coll_resource(builder_preview__collObj, *builder_preview__collRes, builder_preview__physBlk)

[es(on_disappear)]
def building_preview_collobj_cleanup_es(evt : Event; var builder_preview__collObj : CollisionObject)
  destroy_dynamic_collision(builder_preview__collObj)

[es(tag=gameClient, no_order)]
def build_ability_update_transform_es(info : UpdateStageInfoAct;
                                      preview_render__enabled : bool;
                                      buildingTimer : float;
                                      buildingRadius : float;
                                      avaliableAngles : float2;
                                      checkGridObjectsTimeInterval : float;
                                      var transform : float3x4;
                                      var nextCheckGridObjectsTime : float&;
                                      builder_preview__collRes : CollisionResource const?;
                                      builder_preview__collObj : CollisionObject;
                                      builder_preview__collObjOffset : float;
                                      simpleObject__visibleList : BoolList;
                                      simpleObject__offsets : Point3List;
                                      var simpleObject__transparentColor : float3&)
  if !preview_render__enabled || buildingTimer > 0.
    return
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed || !hero.isAlive
    return

  var riDesc = RendInstDesc()
  var len = 100.
  var riMatId = PHYSMAT_INVALID
  let rayMatId = PHYSMAT_INVALID
  var norm : float3
  let tracePos = get_camera_orig_pos()
  let traceDir = get_turret_aim_vector()
  var isAboveOtherBuilding = false
  traceray_normalized(tracePos, traceDir, len, riMatId, norm, ETF_ALL | ETF_RI_PHYS, riDesc, rayMatId)
  if riDesc.riExtraHandle != RIEX_HANDLE_NULL
    isAboveOtherBuilding = true
  let traceEnd = tracePos + traceDir * len
  if traceray_water_at_time(tracePos, traceEnd, float(get_app().usefulTotalTime), len)
    isAboveOtherBuilding = true
    norm = float3(0., 1., 0.)
  let inArea = length_sq(transform[3] - hero.pos) < buildingRadius * buildingRadius
  let isAngleValid = check_inclination_angles(norm, avaliableAngles)
  if isAngleValid
    transform[1] = norm
  transform[2] = normalize(cross(transform[1], -traceDir))
  transform[0] = normalize(cross(transform[1], transform[2]))
  transform[3] = tracePos + traceDir * len
  if info.curTime > nextCheckGridObjectsTime
    var boxForCheck = transform * builder_preview__collRes.boundingBox
    for i in range(1, 3)
      if length(simpleObject__visibleList) > i && simpleObject__visibleList[i]
        bbox3_add(boxForCheck, transform * simpleObject__offsets[i])
    let isValid = (inArea &&
                   isAngleValid &&
                   !isAboveOtherBuilding &&
                   !is_collide_with_unit(boxForCheck, hero.eid, hero.army) &&
                   !is_conflict_with_world(transform, builder_preview__collObj, builder_preview__collObjOffset, builder_preview__collRes,
                    simpleObject__visibleList, simpleObject__offsets))
    if isValid
      simpleObject__transparentColor = float3(0., 1., 0.)
    else
      simpleObject__transparentColor = float3(1., 0., 0.)
    nextCheckGridObjectsTime = info.curTime + checkGridObjectsTimeInterval

[es(tag=server)]
def build_object_es(evt : CmdBuildObject;
                    eid aka unit_eid : EntityId;
                    var unit__ref : UnitRef;
                    reloadedFromAmmoBoxCount : IntList)
  var unit = unit__ref.unit
  if unit.isDelayed
    return
  var count = 0
  foreach_weapon_by_trigger_group(unit.weap.Weapons, evt.triggerGroup) <| $(var weapon)
    let gun = weapon |> as_gun()
    let baseGun = weapon |> as_base_gun()
    if gun != null
      let gun_props = gun.properties
      for i in range(0, length(gun_props.bulletSets))
        assume bullet_set = gun_props.bulletSets[i]
        count += max(0, bullet_set.initialBulletsCount)
    elif baseGun != null
      count += max(0, weapon.prop.bullets)
  if count > 0
    let idx = evt.triggerGroup == WeaponTriggerGroups TRIGGER_GROUP_SPECIAL_GUN ? 2 : (evt.triggerGroup == WeaponTriggerGroups TRIGGER_GROUP_SECONDARY ? 1 : 0)
    count -= reloadedFromAmmoBoxCount[idx]
    if count > 0
      query() <| $ [es] (eid aka box_eid : EntityId; ammo_box__owner : EntityId; ammo_box__triggerGroupNo : int)
        if ammo_box__owner == unit_eid && ammo_box__triggerGroupNo == int(evt.triggerGroup)
          destroyEntity(box_eid)
      createEntity(evt.objectTemplate) <| $(init)
        init |> set("transform", evt.tm)
        init |> set("ammo_box__owner", unit_eid)
        init |> set("ammo_box__bulletCount", count)
        init |> set("ri_extra__owner", unit_eid)
        init |> set("ri_extra__armyId", unit.army)

[es(tag=server, REQUIRE = uid, on_disappear, on_event = EventOnUnitDead)]
def destroy_boxes_of_dead_unit_es(evt : Event;
                                  eid aka unit_eid : EntityId;
                                  var reloadedFromAmmoBoxCount : IntList&)
  for count in reloadedFromAmmoBoxCount
    count = 0
  query() <| $ [es] (eid aka box_eid : EntityId; ammo_box__owner : EntityId)
    if ammo_box__owner == unit_eid
      destroyEntity(box_eid)

[es(tag=server, on_disappear)]
def on_ammo_box_destroy(evt : Event;
                        ammo_box__owner : EntityId;
                        ammo_box__bulletCount : int)
  if ammo_box__bulletCount > 0
    return
  query(ammo_box__owner) <| $ [es] (reloadedFromAmmoBoxCount : IntList)
    let hero = get_unit_by_eid(ammo_box__owner)
    if hero == null || hero.isDelayed
      return
    var count = 0
    for i in range(0, 2)
      let triggerGroup = i == 2 ? WeaponTriggerGroups TRIGGER_GROUP_SPECIAL_GUN : (i == 1 ? WeaponTriggerGroups TRIGGER_GROUP_SECONDARY : WeaponTriggerGroups TRIGGER_GROUP_PRIMARY)
      foreach_weapon_by_trigger_group(hero.weap.Weapons, triggerGroup) <| $(var weapon)
        let gun = weapon |> as_gun()
        if gun != null
          let gun_props = gun.properties
          for j in range(0, length(gun_props.bulletSets))
            assume bullet_set = gun_props.bulletSets[j]
            count += max(0, bullet_set.initialBulletsCount)
      count -= reloadedFromAmmoBoxCount[i]
      if count > 0
        break
    if count <= 0
      sendEvent(ammo_box__owner, [[EventCantReloadingFromBox]])