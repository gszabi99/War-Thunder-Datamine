require ecs

[es (on_event=EventMissionUnload)]
def unload_mission_entities(evt : Event)
  ecs::query() <| $ [es(REQUIRE=missionObject)] (eid : EntityId)
    destroyEntity(eid)