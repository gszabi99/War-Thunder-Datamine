require ecs
require app

require %appGame.wt_events


[es(tag=server, no_order, REQUIRE_NOT=shootingRangeDummy)]
def dead_cleanup_es(evt : EventEntityDied;
                    eid : EntityId;
                    bodyCleanupTime : float)
  sendEvent(eid, CmdBodyCleanup(time = bodyCleanupTime))

[es(tag=server, REQUIRE_NOT=playerUnit)]
def bodies_cleanup(evt : CmdBodyCleanup;
                   eid : EntityId;
                   var entity_destroyer__destroyAtTime : float?)
  let destroyAtTime = get_sync_time() + evt.time
  if entity_destroyer__destroyAtTime != null
    *entity_destroyer__destroyAtTime = destroyAtTime
  else
    addSubTemplate(eid, "item_time_destroyer") <| $(var init)
      init |> set("entity_destroyer__destroyAtTime", destroyAtTime)

[es(tag=server, on_appear, REQUIRE_NOT=playerUnit, REQUIRE_NOT=shootingRangeDummy, REQUIRE=deadEntity)] 
def destroy_dead_entity_timed(evt : Event;
                              eid : EntityId;
                              bodyCleanupTime : float)
  sendEvent(eid, CmdBodyCleanup(time = bodyCleanupTime))






