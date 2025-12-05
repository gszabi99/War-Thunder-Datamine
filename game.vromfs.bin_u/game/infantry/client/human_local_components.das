require ecs


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
