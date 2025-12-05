require ecs
require ecs.ecs_template
require %appGame.infantry.es.loc_squad_common

[ecs_template]
struct ai_switch_behavior
  ai_switch_behavior__agentEid : EntityId = INVALID_ENTITY_ID
  ai_switch_behavior__switchTo : string

[es(tag=server, on_appear, track=squad_member__squad)]
def squad_members_list_fill_es(evt : Event; eid : EntityId; squad_member__squad : EntityId)
  query(squad_member__squad) <| $ [es] (var squad__allMembers : EidList&)
    push(squad__allMembers, eid)

[es(tag=server, on_appear, track=squad_member__squad, REQUIRE=squad_member__squad)]
def squad_members_init_behavior(evt : Event; eid : EntityId)
  reset_squad_mate_behaviour(eid)
