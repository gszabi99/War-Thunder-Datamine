module team_common shared
require ecs

require DagorSystem
require DagorRandom

let TEAM_UNASSIGNED = -1

def is_teams_friendly(lhs, rhs : int)
  return lhs == rhs && lhs != TEAM_UNASSIGNED && rhs != TEAM_UNASSIGNED





def have_active_teammates(owner_eid : EntityId; our_team : int; include_bots = false)
  return find_query() <| $ [es(REQUIRE=human)] (eid : EntityId;
                                                team : int;
                                                countAsAlive, isAlive, isDowned : bool;
                                                beh_tree__enabled = false;
                                                isSpectatable = true)
    return (
         eid != owner_eid
      && countAsAlive && isAlive && isSpectatable
      && !isDowned
      && is_teams_friendly(team, our_team)
      && (include_bots ? true : !beh_tree__enabled)
    )


def assign_team(var out_team_id : int&; var out_team_eid : EntityId&)
  var availableTeams : array<EntityId>
  var minTeamMembers = 1 << 30
  query() <| $ [es] (eid : EntityId;
                     team__memberEids : EidList;
                     team__memberCount : float;
                     team__capacity : int = -1;
                     team__locked : bool = false)
    if (team__capacity >= 0 && team__memberEids |> length() >= team__capacity) || team__locked
      return
    minTeamMembers = min(minTeamMembers, int(team__memberCount))
    availableTeams |> push(eid)

  if minTeamMembers == 1 << 30 
    debug("No team found")
    out_team_id = TEAM_UNASSIGNED
    out_team_eid = INVALID_ENTITY_ID
    return

  var filteredTeams : array<EntityId>
  for eid in availableTeams
    let team__memberCount = get_float(eid, "team__memberCount") ?? 0.
    if int(team__memberCount) == minTeamMembers
      filteredTeams |> push(eid)

  out_team_eid = filteredTeams[rnd_int(0, filteredTeams |> length() - 1)]
  out_team_id = get_int(out_team_eid, "team__id") ?? int(TEAM_UNASSIGNED)
  debug("Found already existing team with id: {out_team_id}, eid: {out_team_eid}")
