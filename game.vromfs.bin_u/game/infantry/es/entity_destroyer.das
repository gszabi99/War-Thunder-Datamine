require ecs
require %game.events


[es(no_order, tag=server, REQUIRE=replication)]
def destroy_entity_on_timer_replicated(info : ParallelUpdateFrameDelayed;
                                       eid : EntityId;
                                       entity_destroyer__destroyAtTime : float)
  if entity_destroyer__destroyAtTime > 0. && info.curTime > entity_destroyer__destroyAtTime
    destroyEntity(eid)


[es(no_order, REQUIRE_NOT=replication)]
def destroy_entity_on_timer_non_replicated(info : ParallelUpdateFrameDelayed;
                                           eid : EntityId;
                                           entity_destroyer__destroyAtTime : float)
  if entity_destroyer__destroyAtTime > 0. && info.curTime > entity_destroyer__destroyAtTime
    destroyEntity(eid)
