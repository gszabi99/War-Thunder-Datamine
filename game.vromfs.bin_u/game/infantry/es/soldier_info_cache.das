require ecs

def save_to_cache(soldier_eid : EntityId; player : EntityId; guid : string)
  query() <| $ [es] (var soldierInfoCache : Object)
    using() <| $(var cur_soldier : Object)
      cur_soldier |> set("player", int(uint(player)))
      cur_soldier |> set("guid", guid)
      soldierInfoCache |> set("{soldier_eid}", cur_soldier)

[es(on_appear, tag=server)]
def soldier_info_cache_on_soldier_spawn(evt : Event;
                                        eid : EntityId;
                                        squad_member__playerEid : EntityId;
                                        guid : string)
  save_to_cache(eid, squad_member__playerEid, guid)

[es(on_event=EventLevelLoaded)]
def soldier_info_cache_init(evt : Event)
  createEntity("soldier_info_cache")
