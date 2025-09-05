require app
require ecs
require net
require Unit
require DagorSystem
require %game.player_events


[es(track=ownedByPlr, on_appear, after=unit_init_completed_es)]
def track_players_es(evt : Event; eid : EntityId; unit__ref : UnitRef; ownedByPlr : EntityId; var replication : NetObject)
  let playerNo = get_int(ownedByPlr, "base_player_id") ?? -1
  if playerNo >= 0
    if !has(eid, "playerUnit")
      addSubTemplate(eid, "player_unit")
    if is_server()
      find_query() <| $ [es] (player_id : int; connId : int)
        if player_id == playerNo
          print("unit with uid:{unit__ref.unit.id} eid:{eid} is now controlled by player pid:{playerNo}/peid:{ownedByPlr} with connId:{connId} connection.")
          replication |> net_object_setControlledBy(connId)
          return true
        return false
    else
      let SERVER_CONN_ID = 0
      replication |> net_object_setControlledBy(SERVER_CONN_ID)
      print("unit with uid:{unit__ref.unit.id} eid:{eid} is now controlled by server pid:{playerNo}/peid:{ownedByPlr} connId:{SERVER_CONN_ID}")
  else
    if has(eid, "playerUnit")
      removeSubTemplate(eid, "player_unit")
    if replication |> net_object_getControlledBy() != INVALID_CONNECTION_ID
      print("unit with uid:{unit__ref.unit.id} eid:{eid} is no longer controlled by player (peid:{ownedByPlr})")
    replication |> net_object_setControlledBy(INVALID_CONNECTION_ID)


[es]
def unit_change_possessing_plr_from(evt : EventPlayerChangeControlFrom; var possessedByPlr : EntityId&)
  possessedByPlr = INVALID_ENTITY_ID

[es]
def unit_change_possessing_plr_to(evt : EventPlayerChangeControlTo; eid : EntityId; var possessedByPlr : EntityId&)
  possessedByPlr = evt.playerEid
  query(possessedByPlr) <| $ [es] (var possessed : EntityId&)
    possessed = eid
  if evt.playerEid == INVALID_ENTITY_ID
    logerr("player pid:{evt.playerId} sync eid is not set, when changing control to unit")

[es(tag=gameClient, on_appear)]
def track_sync_players_es(evt : Event; base_player_id : int; var is_local : bool&)
  if base_player_id == get_local_player_no()
    is_local = true

[es(tag=server, track=connId, on_appear)]
def track_conn_id_players_es(evt : Event; player_id : int; connId : int)
  find_query() <| $ [es] (base_player_id : int;
                          var connid : int&)
    if base_player_id == player_id
      connid = connId
      return true
    return false

[es(tag=server, on_appear)]
def appear_conn_id_players_es(evt : Event; base_player_id : int; var connid : int&)
  find_query() <| $ [es] (player_id : int;
                          connId : int)
    if player_id == base_player_id
      connid = connId
      return true
    return false