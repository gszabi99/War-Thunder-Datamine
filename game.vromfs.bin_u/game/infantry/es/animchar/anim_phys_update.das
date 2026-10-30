require ecs
require AnimV20
require PhysVars
require AnimatedPhys
require %game.events
require %appGame.infantry.es.animchar.anim_phys_update_common

[es(before=plane_anim_es, after=force_anim_state_es, REQUIRE_NOT=(animchar__lockAnimStateChange, animchar__actOnDemand), parallel_for=10)]
def anim_phys_updater_es(info : ParallelUpdateFrameDelayed;
                         animchar__updatable : bool;
                         var anim_phys : AnimatedPhys;
                         var animchar : AnimcharBaseComponent;
                         var phys_vars : PhysVars;
                         animchar__accumDt : float;
                         animchar__dtThreshold : float;
                         phys_vars__skipVisibilityCheck : Tag const?;
                         animchar__visible : bool = false)
  if is_anim_phys_update_frame(info.dt, animchar__updatable, animchar__visible, animchar__accumDt, animchar__dtThreshold, phys_vars__skipVisibilityCheck)
    anim_phys_update(anim_phys, animchar, phys_vars)


[es(before=plane_anim_es, after=force_anim_state_es, REQUIRE_NOT=(animchar__lockAnimStateChange), REQUIRE=animchar__actOnDemand)]
def anim_phys_updater_demand_updatable_es(info : ParallelUpdateFrameDelayed;
                                          var anim_phys : AnimatedPhys;
                                          var animchar : AnimcharBaseComponent;
                                          var phys_vars : PhysVars;
                                          phys_vars__skipVisibilityCheck : Tag const?;
                                          animchar__visible : bool = false)
  if is_anim_phys_demand_update(animchar__visible, phys_vars__skipVisibilityCheck)
    anim_phys_update(anim_phys, animchar, phys_vars)
