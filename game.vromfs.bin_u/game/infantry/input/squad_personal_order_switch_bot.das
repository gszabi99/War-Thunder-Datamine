require ecs
require WTInput
require %game.input.input_events
require %game.events
require %appGame.infantry.es.squad_personal_order_common


def private init_what_bot_to_order(eid : EntityId; squad__allMembers : EidList; var currentBotEid : EntityId&)
  for memberEid in squad__allMembers
    if is_bot_valid_for_personal_order(eid, memberEid)
      currentBotEid = memberEid
      break

[es(tag=input, on_appear, after=squad_members_list_fill_es)]
def squad_personal_bot_order_switch_bot_init_es(evt : Event;
                                                eid : EntityId;
                                                squad_member__squad : EntityId;
                                                var personal_bot_order__currentBotEid : EntityId&)
  query(squad_member__squad) <| $ [es] (squad__allMembers : EidList)
    init_what_bot_to_order(eid, squad__allMembers, personal_bot_order__currentBotEid)

[es(tag=gameClient, on_appear, REQUIRE=heroSquad)]
def squad_bot_spawner_on_bot_appear(evt : Event;
                                    eid aka bot_eid : EntityId;
                                    squad_member__squad : EntityId)
  query(squad_member__squad) <| $ [es] (squad__leader : EntityId)
    if squad__leader == bot_eid
      return
    query(squad__leader) <| $ [es] (var personal_bot_order__currentBotEid : EntityId&)
      if !is_bot_valid_for_personal_order(squad__leader, personal_bot_order__currentBotEid)
        personal_bot_order__currentBotEid = bot_eid

[es(tag=gameClient, track=squad__numAliveMembers, REQUIRE=squad__numAliveMembers)]
def squad_personal_bot_order_init_on_new_squad_members_appear(evt : Event; eid aka squad_eid : EntityId;
                                                              squad__allMembers : EidList)
  query() <| $ [es(REQUIRE=hero)] (eid aka hero_eid : EntityId; squad_member__squad : EntityId; var personal_bot_order__currentBotEid : EntityId&)
    if squad_member__squad == squad_eid
      if !is_bot_valid_for_personal_order(eid, personal_bot_order__currentBotEid)
        init_what_bot_to_order(hero_eid, squad__allMembers, personal_bot_order__currentBotEid)

[es(tag=input, on_appear, REQUIRE=(heroSquad, deadEntity))]
def squad_personal_bot_order_switch_bot_on_bot_death(evt : Event; eid aka died_eid : EntityId; squad_member__squad : EntityId)
  query() <| $ [es] (eid aka hero_eid : EntityId; var personal_bot_order__currentBotEid : EntityId&)
    if personal_bot_order__currentBotEid == died_eid && !!died_eid
      personal_bot_order__currentBotEid = find_next_bot_for_personal_order(hero_eid, squad_member__squad, personal_bot_order__currentBotEid)

[es(tag=input, REQUIRE=controlledHero)]
def squad_personal_bot_order_switch_bot_input(evt : EventOnKeyDown;
                                              eid : EntityId;
                                              squad_member__squad : EntityId;
                                              input__enabled : bool = true;
                                              squad_member__isPersonalContextCommandMode : bool;
                                              var personal_bot_order__currentBotEid : EntityId&)
  if !input__enabled || !squad_member__isPersonalContextCommandMode
    return

  if int(evt.eventId) == int(ShortcutEventId.ID_HUMAN_SELECT_NEXT_SOLDIER)
    personal_bot_order__currentBotEid = find_next_bot_for_personal_order(eid, squad_member__squad, personal_bot_order__currentBotEid)