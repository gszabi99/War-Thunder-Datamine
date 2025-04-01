require ecs
require app


[es(tag=server, on_appear, REQUIRE=deadEntity)]
def destroy_dead_entity_timed(evt : Event;
                              destroy_dead_entity__delay : float;
                              var entity_destroyer__destroyAtTime : float&)
  entity_destroyer__destroyAtTime = get_sync_time() + destroy_dead_entity__delay
