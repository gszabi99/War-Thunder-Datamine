options no_global_variables = false
require ecs
require app
require math.base
require math.random
require walkerai
require DngWalkerai
require BehNodes


require %appGame.es.walker_common

require %appGame.es.team_common
require Dacoll
require DagorDataBlock

require DagorMath

require CollRes

var 
  ER_REGULAR_CHECK : int
  TRACEABLE_DANGER_REACTION_ID : int
  
  

[register_beh_nodes]
def register_nodes()
  ER_REGULAR_CHECK = register_reaction("regularCheck")
  TRACEABLE_DANGER_REACTION_ID = walkerai::register_reaction("onTraceableDanger")
  
  


[es(on_appear)]
def beh_tree_reaction_init_es(evt : Event; beh_tree__regularCheckRange : float2; var beh_tree__regularCheckAt : float&)
  beh_tree__regularCheckAt = get_sync_time() + rnd_float(beh_tree__regularCheckRange)


[es(REQUIRE_NOT=deadEntity, before=beh_tree_update_es, after=walker_agent_es)]
def beh_tree_reaction_es(info : UpdateStageInfoAct;
                         beh_tree__enabled : bool;
                         beh_tree__regularCheckRange : float2;
                         var beh_tree__regularCheckAt : float&;
                         var beh_tree : BehaviourTree)
  if !beh_tree__enabled || beh_tree__regularCheckAt >= info.curTime
    return
  beh_tree |> beh_tree_react(ER_REGULAR_CHECK, info.dt)
  beh_tree__regularCheckAt = info.curTime + rnd_float(beh_tree__regularCheckRange)


def has_traceable_danger(dangers; threshold : float)
  for danger in dangers
    if danger.traceable && danger.dangerMeter >= threshold
      return true
  return false


[es(tag=server, no_order)]
def update_traceable_dangers(act : UpdateStageInfoAct; agent_dangers : AgentDangers; var beh_tree : BehaviourTree;
                             var agent_dangers__hasTraceableDangers : bool&; agent_dangers__hasTraceableDangerThreshold = 1f)
  if length(agent_dangers.dangers) == 0
    agent_dangers__hasTraceableDangers = false
    return
  let hasTraceableDangers = has_traceable_danger(agent_dangers.dangers, agent_dangers__hasTraceableDangerThreshold)
  if hasTraceableDangers && hasTraceableDangers != agent_dangers__hasTraceableDangers && TRACEABLE_DANGER_REACTION_ID > -1
    beh_tree |> beh_tree_react(TRACEABLE_DANGER_REACTION_ID, 0f)
  agent_dangers__hasTraceableDangers = hasTraceableDangers




























































