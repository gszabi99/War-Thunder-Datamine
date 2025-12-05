require ecs
require ecs.safe
require AnimV20
require %game.events




[es(before=before_animchar_update_sync)]
def anim_state_es(info : ParallelUpdateFrameDelayed;
                  animchar__updatable : bool;
                  animchar__animState : Object;
                  var animchar : AnimcharBaseComponent;
                  var animchar__animStateDirty : bool&;
                  var animchar__appliedAnimSpeed : float&;
                  animchar__visible : bool = true;
                  animchar__actWhenInvisible : bool = false;
                  animchar__animSpeed : float = 0.f;
                  animchar__accumDt = -1.f;
                  animchar__dtThreshold = 0.f)
  if (!animchar__updatable ||
      (!animchar__visible && !animchar__actWhenInvisible &&
      (animchar__accumDt + info.dt) < animchar__dtThreshold))
    return
  
  let speedThresholdRatio = 0.1f
  let speedsAlmostEqual = abs(animchar__animSpeed - animchar__appliedAnimSpeed) <= animchar__appliedAnimSpeed * speedThresholdRatio
  if (!animchar__animStateDirty && speedsAlmostEqual)
    return

  var animGraph = animchar.animGraph
  if (animGraph != null)
    for state in animchar__animState
      let stateId = get_int(state.value) ?? 0
      if (animchar__animStateDirty)
        *animGraph |> anim_graph_enqueueState(*animchar.animState, stateId, -1.f, animchar__animSpeed)
      elif (!speedsAlmostEqual)
        *animGraph |> anim_graph_setStateSpeed(*animchar.animState, stateId, animchar__animSpeed)
    animchar__animStateDirty = false
    animchar__appliedAnimSpeed = animchar__animSpeed


[es(on_appear, REQUIRE=animchar__actOnCreate, before=update_animchar_on_create_es)]
def anim_states_init_on_create(evt : Event;
                               animchar__animState : Object;
                               animchar__animSpeed : float = 0.f;
                               var animchar : AnimcharBaseComponent;
                               var animchar__appliedAnimSpeed : float&)
  var animGraph = animchar.animGraph
  if (animGraph != null)
    for state in animchar__animState
      let stateId = state.value ?? 0
      *animGraph |> anim_graph_enqueueState(*animchar.animState, stateId, -1.f, animchar__animSpeed)
    animchar__appliedAnimSpeed = animchar__animSpeed
    
    
    
    animchar |> animchar_act(0.0, true)
