require ecs
require %game.events
require %appGame.infantry.es.action_common

require %appGame.wt_events
require PropsManager
require Action


[es(tag=netClient, REQUIRE=actions)]
def actions_run_es(evt : RunActionCmd; eid : EntityId)
  run_action_by_id(eid, evt.id, PropsId(evt.overridePropsId), -1, evt.overrideTime,
    evt.overrideAt, evt.actionPeriod, evt.progress, evt.timeMult)


[es(before=start_async_phys_sim_es, after=human_anim_weap_es, before=anim_state_es)]
def actions_es(info : ParallelUpdateFrameDelayed)
  broadcastEventImmediate(UpdateActionsEvent(dt = info.dt))

[es(no_order)]
def track_active_action_es(info : ParallelUpdateFrameDelayed;
                           actions : EntityActions;
                           var action__running : bool&)

  action__running = actions.anyActionRunning
