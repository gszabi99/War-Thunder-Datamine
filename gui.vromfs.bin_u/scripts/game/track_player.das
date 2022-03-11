require ecs
require net

[es (track=playerNo, on_event=(EventEntityCreated, EventComponentsAppear))]
def track_players_es(evt: Event; eid: EntityId; playerNo: int)
  if playerNo >= 0 && !has(eid, "playerUnit")
    addSubTemplate(eid, "player_unit")
  elif playerNo < 0 && has(eid, "playerUnit")
    removeSubTemplate(eid, "player_unit")

[es (tag=server, on_appear, REQUIRE=playerUnit)]
def unit_set_controlled_by_es(evt: Event;
                              uid: int;
                              playerNo: int;
                              var replication: NetObject)
  find_query() <| $[es](player_id : int; connId : int)
    if player_id == playerNo
      print("[ECS]: Unit with id {uid} controls replication for player {playerNo} with {connId} connection.")
      replication |> net_object_setControlledBy(connId)
      return true
    return false

[es (tag=netClient, on_appear, REQUIRE=playerUnit)]
def unit_set_controlled_by_on_client_es(evt: Event;
                                        uid: int;
                                        var replication: NetObject)
  let SERVER_CONN_ID = 0
  replication |> net_object_setControlledBy(SERVER_CONN_ID)
  print("[ECS] set SERVER_CONN_ID for unit {uid}")