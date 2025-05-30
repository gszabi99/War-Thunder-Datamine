require ecs
require Unit
require HeroManager

def reset_controlled_hero()
  query() <| $ [es(REQUIRE=controlledHero)] (eid : EntityId)
    removeSubTemplate(eid, "controlled_hero")

def reset_watched_hero()
  query() <| $ [es(REQUIRE=watchedHero)] (eid : EntityId)
    removeSubTemplate(eid, "watched_hero")

def track_controlled_hero()
  let hero = get_controlled_hero()
  if hero != null && hero.eid != INVALID_ENTITY_ID
    query() <| $ [es(REQUIRE=controlledHero)] (eid : EntityId)
      if eid != hero.eid
        removeSubTemplate(eid, "controlled_hero")

    if !has(hero.eid, "controlledHero")
      addSubTemplate(hero.eid, "controlled_hero")
  else
    reset_controlled_hero()

def track_watched_hero()
  let hero = get_watched_hero()
  if hero != null && hero.eid != INVALID_ENTITY_ID
    query() <| $ [es(REQUIRE=watchedHero)] (eid : EntityId)
      if eid != hero.eid
        removeSubTemplate(eid, "watched_hero")

    if !has(hero.eid, "watchedHero")
      addSubTemplate(hero.eid, "watched_hero")
  else
    reset_watched_hero()

[es(tag=gameClient, REQUIRE=unit__ref, on_event=(EventEntityCreated, EventComponentsAppear))]
def track_hero_on_create_es(evt : Event)
  track_controlled_hero()
  track_watched_hero()

[es(tag=gameClient, no_order)]
def track_hero_es(info : UpdateStageInfoAct)
  track_controlled_hero()
  track_watched_hero()