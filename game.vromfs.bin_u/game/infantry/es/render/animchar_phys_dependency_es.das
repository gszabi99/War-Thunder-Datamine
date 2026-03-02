require ecs
require %game.events
require AnimV20

[es(tag=render, REQUIRE=animchar__physSymDependence, before=(start_async_phys_sim_es, motion_matching_start_search_job), parallel_for=1)]
def animchar_phys_dependency_es(info : ParallelUpdateFrameDelayed;
                                transform : float3x4;
                                animchar__updatable : bool;
                                var animchar : AnimcharBaseComponent;
                                var animchar_node_wtm : AnimcharNodesMat44;
                                var animchar_render__root_pos : vec4f&;
                                var animchar__accumDt : float&;
                                animchar__dtThreshold : float;
                                animchar__turnDir = false)
  if !animchar__updatable
    return

  var resultTm = transform
  if animchar__turnDir
    resultTm[0] = transform[2]
    resultTm[2] = -transform[0]

  animchar_set_tm(animchar, resultTm, true)

  animchar__accumDt += info.dt
  if animchar__accumDt >= animchar__dtThreshold
    animchar_act(animchar, animchar__accumDt, true)
    animchar__accumDt = 0.f
  else
    animchar |> animchar_recalc_wtm()
  animchar_copy_nodes(animchar, animchar_node_wtm, animchar_render__root_pos)
