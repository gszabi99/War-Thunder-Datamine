require ecs
require AnimV20
require %game.events


[es(tag=gameClient, on_appear)]
def motion_matching_init_procedural_steps(evt : Event;
                                          animchar : AnimcharBaseComponent;
                                          motion_matching__allowProceduralStepParam : string;
                                          var motion_matching__allowProceduralStepParamId : int&)
  motion_matching__allowProceduralStepParamId = *animchar.animGraph |> anim_graph_getParamId(
      motion_matching__allowProceduralStepParam, int(PT_ScalarParamInt))

[es(tag=gameClient, before=animchar_es)]
def motion_matching_update_procedural_steps(act : ParallelUpdateFrameDelayed;
                                            motion_matching__allowProceduralStepParamId : int;
                                            var animchar : AnimcharBaseComponent;
                                            var motion_matching__allowProceduralStepTimer : float&)
  if motion_matching__allowProceduralStepParamId < 0
    return
  motion_matching__allowProceduralStepTimer -= act.dt
  *animchar.animState |> anim_state_holder_setParamInt(motion_matching__allowProceduralStepParamId,
      motion_matching__allowProceduralStepTimer > 0f ? 1 : 0)

[es(tag=gameClient, track=human_anim__isFpv)]
def motion_matching_enable_procedural_steps_on_tps_toggle(evt : Event;
                                                          human_anim__isFpv : bool;
                                                          var motion_matching__allowProceduralStepTimer : float&)
  if !human_anim__isFpv
    motion_matching__allowProceduralStepTimer = 2.0f
