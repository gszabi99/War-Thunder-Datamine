require ecs
require math.base
require DngHuman
require PhysVars
require DagorMath
require DagorMathUtils
require MotionMatching
require %game.events


[es(REQUIRE_NOT=(animchar__actOnDemand, menuSoldier), after=human_anim_es)]
def human_anim_full_body_aim_es(info : ParallelUpdateFrameDelayed;
                                transform : float3x4;
                                human_anim__fullBodyRootRotateVarId : int;
                                motion_matching__controller : MotionMatchingController;
                                human_net_phys : HumanActor;
                                var human_anim__fullBodyRootRotateValue : float&;
                                var phys_vars : PhysVars)
  assume phys = human_net_phys.phys

  let isMoving = phys.currentState.moveState == HUMoveState.EMS_WALK || phys.currentState.moveState == HUMoveState.EMS_RUN
  let up = transform[1]
  let dir = transform[0]
  let mmRootDir = quat(motion_matching__controller.rootRotation) * MotionMatching::FORWARD_DIRECTION.xyz
  let mmRootAngles = basis_aware_dir_to_angles(mmRootDir, up, dir)
  let mmRootTargetDegrees = !isMoving ? 0.0 : clamp(rad_to_deg(-mmRootAngles.x), -60.0, 60.0)
  let fullBodyRootRotateValue = approach(human_anim__fullBodyRootRotateValue, mmRootTargetDegrees, info.dt, 0.2)
  human_anim__fullBodyRootRotateValue = fullBodyRootRotateValue

  phys_vars |> setVar(human_anim__fullBodyRootRotateVarId, fullBodyRootRotateValue)
