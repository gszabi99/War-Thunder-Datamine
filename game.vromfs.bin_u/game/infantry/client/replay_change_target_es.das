require ecs

[es(on_appear, tag=playingReplay, REQUIRE=watchedByPlr, REQUIRE_NOT=isReplayObserved)]
def possess_entity_appear(evt : Event;
                          eid : EntityId)
  addSubTemplate(eid, "replay_observed")


[es(on_disappear, tag=playingReplay, REQUIRE=watchedByPlr, REQUIRE=isReplayObserved)]
def possess_entity_disappear(evt : Event;
                             eid : EntityId)
  removeSubTemplate(eid, "replay_observed")
