module battle_area_common shared
require Mission
require %appGame.infantry.es.team_common

def has_active_human_battle_area_at(pos : float3; team : int = int(TEAM_UNASSIGNED))
  return das_is_in_battle_area(pos, true, team, 0.0,  false,  false)

def has_active_enemy_human_battle_area_at(pos : float3; our_team : int)
  let oppositeTeam = our_team < 1 ? 0 : 3 - our_team
  return das_is_in_battle_area(pos, true, oppositeTeam, 0.0,  false,  false)
