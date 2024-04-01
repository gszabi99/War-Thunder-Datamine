module net_utils shared

require ecs
require net
require WTNetUnit

def private get_controlled_by_connection(var out : array<IConnection?>&; eid : EntityId)
  query(eid) <| $ [es] (replication : NetObject)
    out |> push(replication |> net_object_getControlledBy() |> get_client_connection())

def target_entity_conn(target_entity : EntityId) : array<IConnection?>
  var recipients : array<IConnection?>
  get_controlled_by_connection(recipients, target_entity)
  return <- recipients