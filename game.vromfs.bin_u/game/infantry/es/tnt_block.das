require ecs
require ecs.common

require %appGame.wt_events
require %appGame.infantry.es.tnt_common


[es(tag=server, REQUIRE=tnt_block, on_appear)]
def tnt_block_appear(evt : Event;
                     eid : EntityId;
                     throwable_item__owner : EntityId;
                     var tnt_block__owner : EntityId&)
  tnt_block__owner = throwable_item__owner
  find_query() <| $ [es(REQUIRE=tnt_exploder)] (gun__owner : EntityId;
                                                var tnt_exploder__tntBlocks : EidList&)
    if gun__owner != tnt_block__owner
      return false

    tnt_exploder__tntBlocks |> push(eid)
    return true

[es(tag=server, REQUIRE=tnt_block, on_disappear)]
def tnt_block_disappear(evt : Event;
                        eid : EntityId;
                        tnt_block__owner : EntityId)
  find_query() <| $ [es(REQUIRE=tnt_exploder)] (gun__owner : EntityId;
                                                var tnt_exploder__tntBlocks : EidList&)
    if gun__owner != tnt_block__owner
      return false

    let idxInExploder = find_index(tnt_exploder__tntBlocks, eid)
    if idxInExploder != -1
      tnt_exploder__tntBlocks |> erase(idxInExploder)
    return true

[es(tag=server, REQUIRE=tnt_block)]
def tnt_block_explode_on_die_es(evt : EventEntityDied;
                                eid : EntityId)
  detonate_tnt_block(eid)

[es(tag=server, REQUIRE=vehicle)]
def tnt_block_attached_to_vehicle_on_vehicle_die(evt : EventEntityDied;
                                                 eid aka vehicle_eid : EntityId)
  query() <| $ [es(REQUIRE=tnt_block)] (eid : EntityId;
                                        node_attached__entity : EntityId)
    if node_attached__entity == vehicle_eid
      detonate_tnt_block(eid)
