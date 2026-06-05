require ecs
require math.base
require DngHuman
require PhysVars
require DagorMath
require DagorMathUtils
require MotionMatching
require %game.events


[es(REQUIRE_NOT=(animchar__actOnDemand, menuSoldier), after=human_anim_es)]
def human_anim_aim_es(info : ParallelUpdateFrameDelayed;
                      human_anim__isFpv : bool;
                      transform : float3x4;
                      human_anim__rootRotateVarId : int;
                      human_anim__fullBodyRootRotateVarId : int;
                      motion_matching__controller : MotionMatchingController;
                      human_net_phys : HumanActor;
                      var phys_vars : PhysVars)
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
  phys_vars |> setVar(human_anim__fullBodyRootRotateVarId, mmRootTargetDegrees)
