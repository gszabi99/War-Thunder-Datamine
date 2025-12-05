module action_common shared

require app
require ecs
require ecs.safe
require net
require Action
require DagorSystem

require %appGame.wt_events
require %appGame.infantry.es.team_common
require PropsManager


[cpp_event(broadcast)]
struct UpdateActionsEvent
  dt : float


let DEF_ACTION_RANGE = 200.

def run_action_by_id(eid : EntityId;
                     action_id : int;
                     override_props_id : PropsId;
                     interp_delay_ticks : int;
                     override_time : float;
                     override_at : float;
                     action_period : float;
                     progress : float = 0.0;
                     time_mult : float = 1.0)
  if action_id < 0
    return

  if is_server()
    send_net_event(eid,
                   RunActionCmd(id = action_id,
                                overridePropsId = props_pack_for_net(override_props_id),
                                overrideTime = override_time,
                                overrideAt = override_at,
                                actionPeriod = action_period,
                                progress = progress,
                                timeMult = time_mult))
  
  run_action_impl(eid, action_id, override_props_id, interp_delay_ticks, override_time, override_at, action_period, progress, time_mult)


def run_action_impl(eid : EntityId;
                    action_id : int;
                    override_props_id : PropsId = PropsId();
                    interp_delay_ticks : int = -1;
                    override_time : float = -1.;
                    override_at : float = -1.;
                    override_period : float = -1.;
                    progress : float = 0.0;
                    time_mult : float = 1.0)
  query(eid) <| $ [es] (actions__enabled : bool = false; actions__actions_enabled : Array; var actions : EntityActions)
    if !actions__enabled || uint(action_id) >= uint(length(actions.actions))
      return

    assume act = actions.actions[action_id]
    if act.timer > 0.
      return

    let isActionEnabled = actions__actions_enabled?[action_id]
    if isActionEnabled == null
      logerr("actions__actions_enabled doesn't have permission for aciton with id={action_id}")
    if !(isActionEnabled ?? false)
      return

    if act.classHash != uint(0) 
      for action in actions.actions
        if action.timer > 0. && action.classHash == act.classHash
          return

    act.actionTime = (override_time >= 0. ? override_time : act.actionDefTime) * time_mult
    act.timer = act.actionTime * (1.0 - progress)
    act.overridePropsId = override_props_id.spacked
    act.interpDelayTicks = interp_delay_ticks
    act.prevRel = 0.
    act.applyAt = (override_at >= 0. ? override_at : act.applyAtDef) * time_mult
    act.actionPeriod = override_period > 0. ? override_period * time_mult : -1.

    actions.anyActionRunning ||= act.timer > 0.


def get_action_id(eid : EntityId; name : string)
  var id = -1
  query(eid) <| $ [es] (actions : EntityActions)
    for i, act in iter_range(actions.actions), actions.actions
      if act.name == name
        id = i
        return
  return id


def run_action(eid : EntityId;
               action : string;
               override_props_id : PropsId = PropsId();
               interp_delay_ticks : int = -1;
               override_time : float = -1.0;
               override_at : float = -1.0;
               action_period : float = -1.0;
               progress : float = 0.0;
               time_mult : float = 1.0)
  let actionId = get_action_id(eid, action)
  run_action_by_id(eid, actionId, override_props_id, interp_delay_ticks, override_time, override_at, action_period, progress, time_mult)

def check_action_precondition(eid : EntityId; action : string)
  let actionId = get_action_id(eid, action)
  return actionId >= 0 && check_action_precondition(eid, actionId)
