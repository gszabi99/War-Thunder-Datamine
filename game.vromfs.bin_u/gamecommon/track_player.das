require ecs
require net
require Unit


[es(track=unit__playerNo, on_appear, after=unit_init_completed_es)]
def track_players_es(evt : Event; eid : EntityId; unit__ref : UnitRef; unit__playerNo : int; var replication : NetObject)
  let playerNo = unit__playerNo
  if playerNo >= 0
    if !has(eid, "playerUnit")
      addSubTemplate(eid, "player_unit")
    if is_server()
      find_query() <| $ [es] (player_id : int; connId : int)
        if player_id == playerNo
          print("unit with uid:{unit__ref.unit.id} eid:{eid} is now controlled by player pid:{playerNo} with connId:{connId} connection.")
          replication |> net_object_setControlledBy(connId)
          return true
        return false
    else
      let SERVER_CONN_ID = 0
      replication |> net_object_setControlledBy(SERVER_CONN_ID)
      print("unit with uid:{unit__ref.unit.id} eid:{eid} is now controlled by server pid:{playerNo} connId:{SERVER_CONN_ID}")
  else
    if has(eid, "playerUnit")
      removeSubTemplate(eid, "player_unit")
    if replication |> net_object_getControlledBy() != INVALID_CONNECTION_ID
      print("unit with uid:{unit__ref.unit.id} eid:{eid} is no longer controlled by player")
    replication |> net_object_setControlledBy(INVALID_CONNECTION_ID)
