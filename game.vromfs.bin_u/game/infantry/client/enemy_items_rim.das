require ecs
require app
require %appGame.infantry.es.team_common


def private calc_item_rim_scale(owner_team, hero_team : int)
  let isEnemy = owner_team != TEAM_UNASSIGNED && hero_team != TEAM_UNASSIGNED && !is_teams_friendly(owner_team, hero_team)
  return isEnemy ? 1. : 0.


def private calc_item_rim_scale_for_owner(owner_eid : EntityId; hero_team : int)
  var scale = 0.
  query(owner_eid) <| $ [es(REQUIRE_NOT=deadEntity)] (team : int)
    scale = calc_item_rim_scale(team, hero_team)
  return scale


def private set_attaches_rim_scale(attach_eid : EntityId; scale : float)
  query(attach_eid) <| $ [es] (var character_rim__scale : float&;
                               attaches_list : EidList const?)
    character_rim__scale = scale
    if attaches_list != null
      for childEid in *attaches_list
        set_attaches_rim_scale(childEid, scale)


[es(tag=gameClient, on_appear, track=(item__ownerEid, slot_attach__inAttachedList), REQUIRE=slot_attach__inAttachedList)]
def enemy_item_rim_on_owner_change(evt : Event;
                                   item__ownerEid : EntityId;
                                   var character_rim__scale : float&)
  let heroTeam = get_int(get_local_player_eid(), "team") ?? TEAM_UNASSIGNED
  character_rim__scale = calc_item_rim_scale_for_owner(item__ownerEid, heroTeam)


[es(tag=gameClient, on_appear, track=team, REQUIRE=human, REQUIRE_NOT=deadEntity)]
def enemy_item_rim_on_owner_team(evt : Event;
                                 team : int;
                                 attaches_list : EidList)
  let heroTeam = get_int(get_local_player_eid(), "team") ?? TEAM_UNASSIGNED
  let scale = calc_item_rim_scale(team, heroTeam)
  for attachEid in attaches_list
    set_attaches_rim_scale(attachEid, scale)


[es(tag=gameClient, on_appear, track=team, REQUIRE=hero)]
def enemy_item_rim_on_hero_team(evt : Event;
                                team aka hero_team : int)
  query() <| $ [es] (item__ownerEid : EntityId;
                     var character_rim__scale : float&)
    character_rim__scale = calc_item_rim_scale_for_owner(item__ownerEid, hero_team)


[es(tag=gameClient, on_appear, REQUIRE=(human, deadEntity))]
def enemy_item_rim_on_owner_death(evt : Event;
                                  attaches_list : EidList)
  for attachEid in attaches_list
    set_attaches_rim_scale(attachEid, 0.)
