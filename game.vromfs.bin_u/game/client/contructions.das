require ecs
require WTCamera
require Dacoll
require RendInst
require Unit
require HeroManager
require PhysMat
require %game.events
require net
require hud
require DagorDataBlock
require CollRes
require soundEvent
require Weapon
require %game.utils.utils_common
require %appGame.es.constructions_utils_common
require DagorMath
require app


[es(tag=gameClient, on_event=EventTryBuildObject, after=build_ability_update_transform_es)]
def try_build_object_es(evt : Event;
                        var buildingTimer : float&;
                        buildingTime : float;
                        buildingRadius : float;
                        avaliableAngles : float2;
                        transform : float3x4;
                        var builder_preview__owner : EntityId&;
                        builder_preview__collRes : CollisionResource const?;
                        builder_preview__collObj : CollisionObject;
                        builder_preview__collObjOffset : float;
                        simpleObject__visibleList : BoolList;
                        simpleObject__offsets : Point3List;
                        var simpleObject__transparentColor : float3&)
  if buildingTimer > 0.
    return

  var hero = get_controlled_hero()
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
  let outOfRange = length_sq(transform[3] - hero.pos) > buildingRadius * buildingRadius
  var boxForCheck = transform * builder_preview__collRes.boundingBox
  for i in range(1, 3)
    if length(simpleObject__visibleList) > i && simpleObject__visibleList[i]
      bbox3_add(boxForCheck, transform * simpleObject__offsets[i])
  let traceEnd = tracePos + traceDir * len
  let hasObstacles = (isAboveOtherBuilding ||
                     traceray_water_at_time(tracePos, traceEnd, float(get_app().usefulTotalTime), len) ||
                     !check_inclination_angles(norm, avaliableAngles) ||
                     is_collide_with_unit(boxForCheck, hero.eid, hero.army) ||
                     is_conflict_with_world(transform, builder_preview__collObj, builder_preview__collObjOffset, builder_preview__collRes,
                     simpleObject__visibleList, simpleObject__offsets))
  if outOfRange
    using() <| $(var eventData : DataBlock)
      hud_notify_script("hint:building_forbidden_range:show", eventData)
  elif hasObstacles
    using() <| $(var eventData : DataBlock)
      hud_notify_script("hint:building_forbidden_obstacles:show", eventData)
  else
    buildingTimer = buildingTime
    builder_preview__owner = hero.eid
    *hero |> toggleBuildingMode()
    simpleObject__transparentColor = float3(0.5, 0.5, 0.5)

[es(tag=gameClient, track=buildingTimer)]
def building_timer_track(evt : Event;
                         transform : float3x4;
                         buildingTimer : float;
                         builder_preview__soundName : string;
                         var builder_preview__soundEvent : SoundEvent&)
  if buildingTimer > 0.
    if !is_playing(builder_preview__soundEvent)
      builder_preview__soundEvent |> play(builder_preview__soundName, transform[3])
  elif is_playing(builder_preview__soundEvent)
    builder_preview__soundEvent |> abandon()

[es(tag=gameClient, no_order)]
def building_process_update_es(info : UpdateStageInfoAct;
                               var buildingTimer : float&;
                               var timeDirSign : int&;
                               transform : float3x4;
                               builder_preview__owner : EntityId;
                               var simpleObject__visibleList : BoolList&;
                               buildingTime : float;
                               var debuffUpdateTimer : float&;
                               buildingRadius : float;
                               buildingTemplates : StringList;
                               simpleObject__offsets : Point3List)
  var showTimer = true
  var hintTime = buildingTimer
  let prevTimerDirSign = timeDirSign
  timeDirSign = 0
  if buildingTimer > 0.
    let hero = get_unit_by_eid(builder_preview__owner)
    if hero != null && !hero.isDelayed
      let inArea = length_sq(transform[3] - hero.pos) < buildingRadius * buildingRadius
      if inArea
        if hero.speed < 1.
          buildingTimer -= info.dt
          timeDirSign = -1
          if buildingTimer <= 0.
            hintTime = 0.
            timeDirSign = 0
            if hero.isAlive && hero.eid != INVALID_ENTITY_ID
              for i in range(length(simpleObject__visibleList))
                if simpleObject__visibleList[i] && i < length(buildingTemplates)
                  let triggerGroup = i == 2 ? WeaponTriggerGroups.TRIGGER_GROUP_SPECIAL_GUN : (i == 1 ? WeaponTriggerGroups.TRIGGER_GROUP_SECONDARY : WeaponTriggerGroups.TRIGGER_GROUP_PRIMARY)
                  var tm = transform
                  tm[3] = transform * simpleObject__offsets[i]
                  send_net_event(hero.eid, CmdBuildObject(tm = tm, objectTemplate = string(buildingTemplates[i]), triggerGroup = triggerGroup))
            for visible in simpleObject__visibleList
              visible = false
            showTimer = false
      else
        buildingTimer += info.dt
        timeDirSign = 1
        if buildingTimer > buildingTime
          for visible in simpleObject__visibleList
            visible = false
          showTimer = false
          hintTime = buildingTime
          buildingTimer = -1.
      debuffUpdateTimer -= info.dt
      if debuffUpdateTimer < 0.f || buildingTimer <= 0. || timeDirSign != prevTimerDirSign
        debuffUpdateTimer = 1.
        using() <| $(var eventData : DataBlock)
          add(eventData, "timer", hintTime + 0.1)
          add(eventData, "totalTime", buildingTime)
          add(eventData, "backward", !inArea)
          add(eventData, "showTimer", showTimer)
          add(eventData, "pause", hero.speed >= 1. && inArea)
          hud_notify_script("TankDebuffs:Building", eventData)

[es(tag=gameClient)]
def building_preview_switch_es(evt : EventToggleBuildingPreview;
                               var preview_render__enabled : bool&;
                               buildingTimer : float;
                               builder_preview__triggerGrMask : uint8;
                               var simpleObject__visibleList : BoolList&)
  preview_render__enabled = evt.enable
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed || !hero.isAlive
    for visible in simpleObject__visibleList
      visible = false
    return
  for i in range(length(simpleObject__visibleList))
    simpleObject__visibleList[i] = false
    let bitNum = i == 2 ? 4 : i
    if (int(builder_preview__triggerGrMask) & (1 << bitNum)) == 0
      continue
    if evt.enable || buildingTimer > 0.
      let triggerGroup = i == 2 ? WeaponTriggerGroups.TRIGGER_GROUP_SPECIAL_GUN : (i == 1 ? WeaponTriggerGroups.TRIGGER_GROUP_SECONDARY : WeaponTriggerGroups.TRIGGER_GROUP_PRIMARY)
      var count = 0
      foreach_weapon_by_trigger_group(hero.weap.Weapons, triggerGroup) <| $(var weapon)
        let gun = weapon |> as_gun()
        let baseGun = weapon |> as_base_gun()
        if gun != null
          let gun_props = gun.properties
          for j in range(0, length(gun_props.bulletSets))
            assume bullet_set = gun_props.bulletSets[j]
            count += max(0, bullet_set.initialBulletsCount)
        elif baseGun != null
          count += max(0, weapon.prop.bullets)
      query(hero.eid) <| $ [es] (reloadedFromAmmoBoxCount : IntList)
        count -= i < length(reloadedFromAmmoBoxCount) ? reloadedFromAmmoBoxCount[i] : 0
      simpleObject__visibleList[i] = count > 0

  using() <| $(var eventData : DataBlock)
    hud_notify_script(evt.enable ? "hint:building_exit:show" : "hint:building_exit:hide", eventData)