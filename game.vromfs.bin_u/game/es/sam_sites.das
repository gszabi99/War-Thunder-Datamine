require ecs
require ecs.common
require ecs.safe
require Unit
require math.base
require DagorMath
require DagorSystem
require Mission
require strings
require Weapon

def private create_sam_unit(settings_obj : Object const?;
                            transform : float3x4;
                            team : int;
                            owner_eid : EntityId;
                            attackers_group_idx : int;
                            max_attackers_per_target : int) : EntityId
  let unitName = settings_obj?.name ?? ""
  if unitName.empty()
    logerr("sam_sites: empty unit name in sam_site__unitSettings")
    return INVALID_ENTITY_ID
  var templateName = settings_obj?.templateName ?? "tank+sam_site_unit"
  templateName += "+unit_init_params"
  return createEntity(templateName) <| $(init)
    init |> set("unit__className", unitName)
    init |> set("transform", transform)
    init |> set("team", team)
    init |> set("unit__ownsUnitId", true)
    init |> set("sam_site__owner", owner_eid)
    init |> set("setting__toGround", true)
    init |> set("setting__dontCreateChar", settings_obj?.dontCreateChar ?? false)
    let mods = get_ecs_StringList(settings_obj, "mods")
    if mods != null
      init |> set("unit_params__modList", *mods)
    let bulletNameList = get_ecs_StringList(settings_obj, "bulletNames")
    if bulletNameList != null
      init |> set("setting__bullets", *bulletNameList)
    let bulletsCountList = get_ecs_IntList(settings_obj, "bulletsCount")
    if bulletsCountList != null
      init |> set("setting__bulletsCount", *bulletsCountList)
    init |> set("on_death_substract_team_tickets_num", 5)
    init |> set("aimer_custom_setting__maxNumAttackersPerTargetGroupIdx", attackers_group_idx)
    init |> set("aimer_custom_setting__maxNumAttackersPerTarget", max_attackers_per_target)


[es(tag=server, on_appear)]
def sam_site_spawn_es(evt : Event;
                      eid : EntityId;
                      team : int;
                      transform : float3x4;
                      units_spawn_on_init__positions : TMatrixList;
                      units_spawn_on_init__positionNames : StringList;
                      sam_site__unitSettings : Array;
                      sam_site__attackers_group_idx : int;
                      sam_site__max_attackers_per_target : int;
                      var sam_site__launchers : EidList&;
                      var sam_site__trackers : EidList&;
                      var sam_site__detectors : EidList&;
                      var sam_site__units_pending : int&;
                      var units_spawn_on_init__units : EidList&)
  var nextNameIdx : table<string; int>
  for unitVal in sam_site__unitSettings
    let obj = unitVal as Object
    if obj == null
      continue
    let spawnName = obj?.spawnName ?? ""
    for _ in range(obj?.count ?? 1)
      var tm = IDENT_TM
      let startIdx = nextNameIdx?[spawnName] ?? 0
      if !spawnName.empty()
        for j in range(startIdx, length(units_spawn_on_init__positionNames))
          if units_spawn_on_init__positionNames[j] == spawnName
            tm = units_spawn_on_init__positions[j]
            nextNameIdx[spawnName] = j + 1
            break
      let isLauncher = spawnName == "launcher"
      let unitEid = create_sam_unit(obj, transform * tm, team, eid,
                                    isLauncher ? sam_site__attackers_group_idx : 0,
                                    isLauncher ? sam_site__max_attackers_per_target : 0)
      if unitEid == INVALID_ENTITY_ID
        continue
      units_spawn_on_init__units |> push(unitEid)
      if isLauncher
        sam_site__launchers |> push(unitEid)
      elif spawnName == "tracker_radar"
        sam_site__trackers |> push(unitEid)
      elif spawnName == "detector_radar"
        sam_site__detectors |> push(unitEid)

  sam_site__units_pending = length(units_spawn_on_init__units)


[es(tag=server, on_appear)]
def sam_site_unit_ready_es(evt : Event;
                           sam_site__owner : EntityId;
                           team aka sam_site__team : int)
  query(sam_site__owner) <| $ [es] (var sam_site__units_pending : int&)
    sam_site__units_pending -= 1
    if sam_site__units_pending != 0
      return

    
    
    using() <| $(var allDetectors : EidList)
      query() <| $ [es] (team aka q_team : int;
                         sam_site__detectors : EidList)
        if q_team == sam_site__team
          for eid in sam_site__detectors
            allDetectors |> push(eid)
      query() <| $ [es] (team aka q_team : int;
                         sam_site__launchers : EidList;
                         sam_site__trackers : EidList;
                         sam_site__missile_channels_max : int;
                         sam_site__target_channels_max : int)
        let shouldClearDetectors = false
        if q_team == sam_site__team
          if length(sam_site__trackers) > 1
            let launcherPerTrackerCount = ceili(float(length(sam_site__launchers)) / float(length(sam_site__trackers)))
            var usedLauncherIdx = 0
            for trackerIdx in range(0, length(sam_site__trackers))
              using() <| $(var trackerEid : EidList)
                trackerEid |> push(sam_site__trackers[trackerIdx])
                using() <| $(var launchersForTracker : EidList)
                  for launcherIdx in range(usedLauncherIdx, length(sam_site__launchers))
                    launchersForTracker |> push(sam_site__launchers[launcherIdx])
                    if length(launchersForTracker) >= launcherPerTrackerCount
                      usedLauncherIdx += length(launchersForTracker)
                      break
                  set_sam_site(launchersForTracker, trackerEid, allDetectors, sam_site__missile_channels_max, sam_site__target_channels_max, shouldClearDetectors)
          else
            set_sam_site(sam_site__launchers, sam_site__trackers, allDetectors, sam_site__missile_channels_max, sam_site__target_channels_max, shouldClearDetectors)
