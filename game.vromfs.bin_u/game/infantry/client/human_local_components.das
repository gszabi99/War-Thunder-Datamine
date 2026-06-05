require ecs
require %appGame.infantry.es.vehicle.vehicle_events


[es(tag=render, on_appear, REQUIRE=(human, watchedHero))]
def watched_player_init(evt : Event;
                        eid : EntityId)
  addSubTemplate(eid, "watched_human_components")

[es(tag=render, on_disappear, REQUIRE=(human, watchedHero))]
def watched_player_disappear(evt : Event;
                             eid : EntityId)
  removeSubTemplate(eid, "watched_human_components")

[es(tag=gameClient, on_appear, REQUIRE=(human, watchedHero))]
def controlled_hero_init(evt : Event;
                         eid : EntityId)
  addSubTemplate(eid, "human_hero_components")

[es(tag=gameClient, on_disappear, REQUIRE=(human, watchedHero))]
def controlled_hero_deinit(evt : Event;
                           eid : EntityId)
  removeSubTemplate(eid, "human_hero_components")

[es(tag=gameClient)]
def human_control_vehicle_tracker_es(evt : EventEnterVehicle; eid : EntityId)
  if eid != evt.incomer
    return
  if evt.enter
    addSubTemplate(eid, "human_control_vehicle")
  else
    removeSubTemplate(eid, "human_control_vehicle")
