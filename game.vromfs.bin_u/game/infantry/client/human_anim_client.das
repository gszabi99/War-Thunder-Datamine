require ecs
require math.base
require DngHuman
require PhysVars
require DagorMath
require DagorMathUtils
require MotionMatching
require %game.events
require %appGame.infantry.es.animchar.anim_phys_update_common


[es(REQUIRE_NOT=(animchar__actOnDemand, menuSoldier), after=human_anim_es)]
def human_anim_aim_es(info : ParallelUpdateFrameDelayed;
                      human_anim__isFpv : bool;
                      transform : float3x4;
                      human_anim__rootRotateVarId : int;
                      motion_matching__controller : MotionMatchingController;
                      human_net_phys : HumanActor;
                      animchar__updatable : bool = true;
                      animchar__visible : bool = false;
                      animchar__accumDt = -1.f;
                      animchar__dtThreshold = 0.f;
                      phys_vars__skipVisibilityCheck : Tag const?;
                      var phys_vars : PhysVars)
  if !is_anim_phys_update_frame(info.dt, animchar__updatable, animchar__visible, animchar__accumDt, animchar__dtThreshold, phys_vars__skipVisibilityCheck)
    return
  assume phys = human_net_phys.phys
  let isCrawling = phys.currentState.standState == HUStandState.ESS_CRAWL
  if isCrawling || human_anim__isFpv
    return

  let up = transform[1]
  let dir = transform[0]
  let mmRootDir = quat(motion_matching__controller.rootRotation) * MotionMatching::FORWARD_DIRECTION.xyz
  let mmRootAngles = basis_aware_dir_to_angles(mmRootDir, up, dir)
  let mmRootTargetDegrees = clamp(rad_to_deg(-mmRootAngles.x), -60.0, 60.0)
  phys_vars |> setVar(human_anim__rootRotateVarId, mmRootTargetDegrees)
