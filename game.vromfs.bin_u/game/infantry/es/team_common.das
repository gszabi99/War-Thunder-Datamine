module team_common shared
require ecs
require app
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
    print("No team found")
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
  print("Found already existing team with id: {out_team_id}, eid: {out_team_eid}")


let
  TB_LIMITER_TACTICALPATH = 0
  TB_LIMITER_USING_RECONS = 1
  TB_LIMITER_FIND_COVER_A = 2
  TB_LIMITER_TRACE_COVERS = 3
  TB_LIMITER_LOCAL_ESCAPE = 4
  TB_LIMITERS_MAX = 5

def team_bots_limiter_find_kind(kind : string)
  if kind == "TACTICALPATH"
    return TB_LIMITER_TACTICALPATH
  if kind == "USING_RECONS"
    return TB_LIMITER_USING_RECONS
  if kind == "FIND_COVER_A"
    return TB_LIMITER_FIND_COVER_A
  if kind == "TRACE_COVERS"
    return TB_LIMITER_TRACE_COVERS
  if kind == "LOCAL_ESCAPE"
    return TB_LIMITER_LOCAL_ESCAPE
  return -1

def team_bots_tick_limiter_check(for_team : int; kind_idx : int; max_num : int)
  if kind_idx >= TB_LIMITERS_MAX
    return false
  var result = false
  find_query() <| $ [es] (team__id : int; var team_bots__limitersTime : FloatList&; var team_bots__limitersNum : IntList&)
    if for_team != team__id
      return false
    if kind_idx >= length(team_bots__limitersTime)
      team_bots__limitersTime |> resize(1 + kind_idx)
      team_bots__limitersNum |> resize(1 + kind_idx)
    let curTime = get_sync_time()
    assume lastTime = team_bots__limitersTime[kind_idx]
    assume lastNum = team_bots__limitersNum[kind_idx]
    if lastTime < curTime
      lastTime = curTime
      lastNum = 0
    if lastTime == curTime && lastNum < max_num
      lastNum += 1
      result = true
    return true
  return result

