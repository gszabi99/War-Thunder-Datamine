require ecs

[es(no_order)]
def unit_showcase_update_es(act : UpdateStageInfoAct; unit_showcase_mission_name : string; var unit_showcase_eid : EntityId&)
  if (unit_showcase_eid == INVALID_ENTITY_ID)
    find_query() <| $ [es] (unit__missionName : string; eid : EntityId)
      let found = unit__missionName == unit_showcase_mission_name
      if (found)
        print("unit_showcase mission unit found")
        unit_showcase_eid = eid
      return found

  query(unit_showcase_eid) <| $ [es] (var physical_tracks_force_update : bool&)
    physical_tracks_force_update = true

