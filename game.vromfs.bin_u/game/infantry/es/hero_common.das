module hero_common shared
require ecs


def get_controlled_hero_eid()
  var heroEid = INVALID_ENTITY_ID
  query() <| $ [es(REQUIRE=controlledHero)] (eid : EntityId)
    heroEid = eid
  return heroEid








