require ecs
require AnimV20
require PhysVars
require AnimatedPhys
require %game.events

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
  if animchar__updatable && (animchar__visible || (animchar__accumDt + info.dt) > animchar__dtThreshold || phys_vars__skipVisibilityCheck != null)
    anim_phys_update(anim_phys, animchar, phys_vars)


[es(before=plane_anim_es, after=force_anim_state_es, REQUIRE_NOT=(animchar__lockAnimStateChange), REQUIRE=animchar__actOnDemand)]
def anim_phys_updater_demand_updatable_es(info : ParallelUpdateFrameDelayed;
                                          var anim_phys : AnimatedPhys;
                                          var animchar : AnimcharBaseComponent;
                                          var phys_vars : PhysVars;
                                          phys_vars__skipVisibilityCheck : Tag const?;
                                          animchar__visible : bool = false)
  if animchar__visible || phys_vars__skipVisibilityCheck != null
    anim_phys_update(anim_phys, animchar, phys_vars)
