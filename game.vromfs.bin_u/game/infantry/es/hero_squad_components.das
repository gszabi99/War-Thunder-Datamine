require ecs

[es(tag=gameClient, on_appear)]
def set_hero_squad_tag_on_soldier_created(evt : Event; eid : EntityId; squad_member__squad : EntityId)
  let squad = squad_member__squad
  query() <| $ [es(REQUIRE=(hero, heroSquad))] (squad_member__squad : EntityId)
    if squad_member__squad == squad && !!squad
      addSubTemplate(eid, "human_hero_squad_components")

[es(tag=gameClient, on_appear, REQUIRE=hero, REQUIRE_NOT=heroSquad)]
def init_hero_squad_components(evt : Event; squad_member__squad : EntityId)
  let hero_squad = squad_member__squad
  query() <| $ [es] (eid : EntityId; squad_member__squad : EntityId)
    if squad_member__squad == hero_squad
      addSubTemplate(eid, "human_hero_squad_components")
    else
      removeSubTemplate(eid, "human_hero_squad_components")

[es(tag=gameClient, on_appear, track=squad_member__squad)]
def set_watched_squad_tag_on_soldier_created(evt : Event; eid : EntityId; squad_member__squad : EntityId)
  let squad = squad_member__squad
  query() <| $ [es(REQUIRE=(watchedByPlr, watchedSquad))] (squad_member__squad : EntityId)
    if squad_member__squad == squad && !!squad
      addSubTemplate(eid, "human_watched_squad_components")

[es(tag=gameClient, on_appear, REQUIRE=watchedByPlr, track=squad_member__squad, REQUIRE_NOT=watchedSquad)]
def init_watched_squad_components(evt : Event; squad_member__squad : EntityId)
  let watched_squad = squad_member__squad
  if !!watched_squad
    query() <| $ [es] (eid : EntityId; squad_member__squad : EntityId)
      if squad_member__squad == watched_squad
        addSubTemplate(eid, "human_watched_squad_components")
      else
        removeSubTemplate(eid, "human_watched_squad_components")
