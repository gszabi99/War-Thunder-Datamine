require ecs
require net
require Unit
require Mission
require %appGame.wt_events

[es(tag=server, REQUIRE = event_snowball__handle_hit)]
def event_snowball_on_player_hit(evt : EventOnPlayerHit)
  let offenderUnit = get_unit(evt.offenderUnitId)
  let victimUnit = get_unit(evt.victimUnitId)
  let ticketsForHit = -100
  change_mp_tickets_for_team(victimUnit.army, ticketsForHit)
  send_net_event(victimUnit.eid,
                 EventPlayEffect(name = "misc_decor_firework",
                                 pos = offenderUnit.pos))

[es(tag=render, REQUIRE = event_snowball__handle_hit)]
def event_snowball_play_firework(evt : EventPlayEffect)
  play_effect_at_pos(evt.name, evt.pos)
